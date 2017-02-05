-- Avoid_Other_Ships script.
--
-- Reactive task to avoid other ships, using naval right of way rules.
--
-- Copyright 2013, VT MAK

-- TODO: Implement better algorithm for ships moving in same direction.

require "vrfutil"
local PI_DIV_2 = math.pi * 0.5

local SAILBOAT_TYPES = { "1:3:0:61:6:-1:-1", 
                  "1:3:0:61:7:-1:-1"}
-- Fishing boats have right of way when they have nets /lines out
local FISHING_BOAT_TYPES = {"1:3:0:61:4:-1:-1", -- the VRF fishing boat uses this
                      "1:3:222:61:2:-1:-1", 
                      "1:3:222:61:3:-1:-1",
                      "1:3:222:61:4:-1:-1",
                      "1:3:225:61:3:-1:-1",
                      "1:3:225:61:4:-1:-1",
                      "1:3:225:61:5:-1:-1",
                      "1:3:225:61:6:-1:-1",
                      "1:3:225:61:7:-1:-1"}

-- Aircraft carriers have right of way when conducting air operations
local CV_TYPES = {} -- TBD

local navPriority = {other = 1, 
               sailboat = 2, 
               fishing = 3,
               cv = 4
               }
                      
-- From the definition of parameters for turn-move-sail-heading:
local LEFT = 1
local RIGHT = 2 
function oppositeSide(side)
   return 3 - side
end
-- Add another enumeration to the above for a third avoidance option
local SLOW = 3

local TICK_PERIOD = 0.7

local NEW_SHIP_CHECK_PERIOD = 1.4

local INTEREST_RADIUS_FACTOR = 8 -- Distance to look for potential colliders,
                    -- in units of ship turn radii
local MAX_SUB_DEPTH = 5.0 -- Maximum depth at which subs can be for ships to
                  -- consider them for avoidance.
local BUFFER_FACTOR = 4.0  -- Desired spacing between ships, in multiples of
                  -- 0.5 * (sum of ship widths)
local ENTITY_STOPPED_SPEED = 0.5 -- The speed, in m/s, below which a ship is
            -- considered to be stopped (and thus must be avoided)
local REAR_ZONE_BEARING = math.pi * 0.5 -- The angle, in radians, from dead
            -- ahead that another ship has to be in order to be in the
            -- ship's "rear zone" and considered to be overtaking.
local COS_REAR_ZONE_BEARING = math.cos(REAR_ZONE_BEARING)
local COLLISION_TIME_HORIZON = 300 -- The time in the future within which a
            -- conflict with another ship must occur for this ship
            -- to take avoidance action. In seconds.

local AVOIDANCE_WEIGHT_FACTOR = 8 -- The weight of an obstacle ship's 
            -- avoid-to-right vector when the ship is at range = 1
            -- (i.e., one turn radius).
local REPULSION_EXPONENT = 2 --Exponent for 1/range that is used to generate
            -- a repulsive vector from a ship. Range is in terms
            -- of turn radii.
local REPULSION_WEIGHT_FACTOR = 0 -- The weight of the repulsive vector when
            -- range = 1.0 (i.e., one turn radius).
            
local TURN_CONTROL_THRESHOLD = 0.01 -- The angle error, in radians,
            -- from the computed desired heading, and below which
            -- the script will not attempt to correct the ship's heading
local TURN_EASING_FACTOR = 2.0 -- A factor to increase the ship's turn radius
            -- by, to make it make gentler avoidance maneuvers
local MIN_SPEED_FACTOR = 0.3 -- Minimum speed the ship can be ordered while
            -- avoiding ships, as a multiple of ordered speed.
            -- This is also the cosine of the angle of the avoidance
            -- maneuver from the original task heading.
local SPEED_CONTROL_THRESHOLD = 0.1 -- The speed factor error (i.e., multiples
            -- of the ordered speed) between the desired avoidance speed 
            -- and the last set speed that must be exceeded before issuing
            -- a new set-speed message.

local nearbyShips = {}
local nextShipCheckTime = 0
            
-- Returns a string indicating navigation class. One of
-- "other", "sailboat", "fishing", or "cv"
function getNavClass(entity)
   local entityType = entity:getEntityType()
   for i, v in ipairs(CV_TYPES) do
      if (vrf:entityTypeMatches(entityType, v)) then
         return "cv"
      end
   end
   for i, v in ipairs(FISHING_BOAT_TYPES) do
      if (vrf:entityTypeMatches(entityType, v)) then
         return "fishing"
      end
   end
   for i, v in ipairs(SAILBOAT_TYPES) do
      if (vrf:entityTypeMatches(entityType, v)) then
         return "sailboat"
      end
   end
   return "other"
end

-- Ship parameters:
mySize, myBVOffset = this:getBoundingVolume()
myWidth = mySize:getRight()
myMoveSystem = this:getSystem("movement")
myNavClass = getNavClass(this)

-- Computed each tick, used globally:
myTurnRadius = 1.0 --Just a default init
myOrderedSpeed = 1.0
shipsToAvoid = {} -- A list of {entity, turnDirection} pairs, 
      --  where entity is a ship that must be avoided this tick

-- Computed in check(), used in tick:
-- The heading my ship was on before reacting
originalHeading = 0
-- Speed
originalOrderedSpeed = 0

-- Persists from tick to tick:
currentlyTurningRight = true
currentTurnRate = 0
currentSpeedFactor = 1 -- Multiplier for ordered speed; indicates
      -- the last speed ordered by this avoidance task.
turnTaskID = -1


----------------- Utility functions -------------------------------------
function cross2D (vec3D1, vec3D2)
   return vec3D1:getNorth() * vec3D2:getEast() -
      vec3D1:getEast() * vec3D2:getNorth()
end

-- We are using the movement system parameter for this value:

--~ function currentTurnRadius()
--~    local latAccel = this:getParameter("max-lateral-acceleration")
--~    --TMP -- turning radius for fishing boat too small
--~    local minR = mySize:getForward()
--~ --   local minR = this:getParameter("turning-radius")
--~    local speed = this:getSpeed()
--~    local speedR = speed * speed / latAccel
--~    return math.max(speedR, minR)
--~ end

-- Given relative positions of ownship and another entity, and the velocity
-- of both, and the distance along their courses that their bounding boxes
-- continue to obstruct the other course, determine if the two ships will
-- be at the intersection point at the same time and therefore collide.
-- Assume that the two direction vectors are not parallel (remove this
-- case before calling this function).
function onCollisionCourse(vectorToEntity, --Vector from ownwhip to entity
   myDirection, -- Unit vector of movement (and heading)
   mySpeed, 
   myConflictLength, -- Distance along course from intersection point that
    -- ownship will continue to block the other course. If the courses have
    -- a small angle between them, then this distance must be great enough
    -- to allow enough separation for the halfwidth of the ownship. I.e.
    -- halfwidth/sin(angle between courses)
   entityDir, 
   entitySpeed, 
   entityConflictLength,
   entityLength)   
   
   local mySpeedPerpToEntityCourse = cross2D(myDirection, entityDir) *
      mySpeed

   local myIntersectTime = cross2D(vectorToEntity, entityDir) / --Perp distance of 
                                                    -- ownship to entity course
      mySpeedPerpToEntityCourse
   local myDistToIntersect = mySpeed * myIntersectTime
   local myFirstIntersectTime = (myDistToIntersect - myConflictLength)/ 
      math.max(mySpeed, myOrderedSpeed) -- Just in case we are accelerating
   local myLastIntersectTime = (myDistToIntersect + myConflictLength) / mySpeed
   
   local entitySpeedPerpToMyCourse = -mySpeedPerpToEntityCourse *
      entitySpeed / mySpeed
   local qp = vectorToEntity:getNegated()
   local entityIntersectTime = cross2D(qp, myDirection) /
      entitySpeedPerpToMyCourse
   local entityDistToIntersect = entitySpeed * entityIntersectTime
   local entityFirstIntersectTime = (entityDistToIntersect -
      entityConflictLength) / entitySpeed
   local entityLastIntersectTime = (entityDistToIntersect +
      entityConflictLength) / entitySpeed

   -- Avoid vessels (to right) on crossing paths <<<<<<<<<<<<<<<<<<<<<<<<<<<
   printDebug(string.format("    Ownship crossing from time %.1f to %.1f", 
      myFirstIntersectTime, myLastIntersectTime))
   printDebug(string.format("    Entity crossing from time %.1f to %.1f", 
      entityFirstIntersectTime, entityLastIntersectTime))
   if myLastIntersectTime < 0 or entityLastIntersectTime < 0 then
      printDebug("    Conflict occurs in the past; ignore")
      return false
   end
   if myFirstIntersectTime > COLLISION_TIME_HORIZON then
      printDebug("    Conflict occurs too far in future; ignore")
      return false
   end
   
   local cosAngle = myDirection:dotVector3D(entityDir)
   if  cosAngle < 0.707 then
      return myFirstIntersectTime < entityLastIntersectTime and
         myLastIntersectTime > entityFirstIntersectTime
   else
      -- If my ship and entity are going in roughly the same direction, 
      -- (angle between them is less than arccos(0.707) )
      -- consider the possibility that one ship may be in front of the 
      -- other the whole way through the conflict area.
      -- This situation will arise if the entity has just passed my ship.
      if myFirstIntersectTime < entityFirstIntersectTime then
      
         -- My ship reaches the conflict area first; it can pass through
         -- ahead if it is going faster and if the stern gets to the 
         -- first conflict point before the other ship.
         -- Note that the speed of the front edge of the other ship along
         -- my ship's course is faster if it is at an angle.
         -- The 1.5 factor is a buffer (the bufferSize value isn't
         -- available here).
         if mySpeed > entitySpeed / cosAngle and
            myFirstIntersectTime + mySize:getForward() * 1.5/mySpeed <
            entityFirstIntersectTime then
         
            printDebug("    Ownship passes in front of other ship; ignore")
            return false
         else
            return true
         end
      else
         -- Similarly for the entity vs. my ship
         if entitySpeed > mySpeed / cosAngle and
            entityFirstIntersectTime + entityLength * 1.5/entitySpeed <
            myFirstIntersectTime then
         
            printDebug("    Entity passes in front of ownship; ignore")
            return false
         else
            return true
         end
      end
   end
end


-- Given the ownship velocity and size, the entity velocity and size, and
-- a vector between them, determine if they are on a collision course.
-- Assumes that ownship's nav priority is <= entity nav priority.
-- Returns 1) a boolean indicating that this entity must be avoided, and 
-- 2) if true, the side around which my ship should go
function avoidEntityGivenOwnDirection(vectorToEntity,
   myDirection, -- A unit vector in the ownship's velocity (and heading) direction
   mySpeed,
   entityNavClass, -- A string indicating the navigation priority class
   entityDir,
   entitySpeed,
   entitySize) -- An offset vector representing the size of the entity
 
   local sinAngleBetweenCourses = math.abs(cross2D(entityDir, myDirection))
   -- Cross product of myDirection with this-to-entity gives distance of
   -- entity to my straight line course.
   local entityDistToCourse = math.abs(cross2D(myDirection, vectorToEntity))
   
   local cosAngleBetweenCourses = math.abs(myDirection:dotVector3D(entityDir))
   
   local dirToEntity = Vector3D(vectorToEntity:getNorth(),
      vectorToEntity:getEast(), 0)
   dirToEntity = dirToEntity:getUnit()
   
   local entityHigherPriority = navPriority[entityNavClass] > 
      navPriority[myNavClass]
   
   -- Test to see if entity is behind ownship.
   -- Note ownship must still avoid a higher priority ship overtaking.
   -- (TODO? If entity is higher priority, and bigger, and going a 
   -- little slower, but close by, it could still possibly hit the ownship.)
   local entityIsBehindMe = myDirection:dotVector3D(dirToEntity) < 
      COS_REAR_ZONE_BEARING
   if  entityIsBehindMe and
      ((not entityHigherPriority) or mySpeed > entitySpeed) then
      
      -- Ignore ships behind, unless they are higher priority <<<<<<<<<<<
      printDebug("  Entity is behind")
      return false
   end
   
   local dirToMe = dirToEntity:getNegated()
   
   -- Determine if my ship is behind the entity (if cosine of angle-off
   -- from entity < cosine of the rear zone threshold angle)
   local isBehindEntity = 
      entityDir:dotVector3D(dirToMe) < COS_REAR_ZONE_BEARING
   
   local sideToMe -- Which side of the entity my ship is on
   if cross2D(entityDir, dirToMe) > 0 then
      sideToMe = RIGHT
   else
      sideToMe = LEFT
   end
   
   local sideToEntity -- Which of my sides the entity is on
   if cross2D(myDirection, dirToEntity) > 0 then
      sideToEntity = RIGHT
   else
      sideToEntity = LEFT
   end
   
   -- Have right of way over ships to left <<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   -- Note that if myShip is on the entity's left too, then we
   -- may be passing close on our left sides and might have
   -- to both avoid each other. Thus only ignore the other entity if
   -- my ship is on its right.
   if not isBehindEntity and
      sideToMe == RIGHT and sideToEntity == LEFT and
      (not entityHigherPriority) then
      
      -- My ship is on the right, has right of way; ignore entity
      printDebug("  Entity is to the left; ignore.")
      return false
   end
   
   
   local entityPartBetweenCourses = 
      entitySize:getForward()/2 * sinAngleBetweenCourses +
      entitySize:getRight()/2 * cosAngleBetweenCourses
   
   local bufferSize = (entitySize:getRight() + mySize:getRight()) * 0.5 *
      BUFFER_FACTOR
      
   local spaceNeededEntityToMyCourse = entityPartBetweenCourses +
      mySize:getRight()/2 + bufferSize
   
   -- Avoid vessels stopped on course <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   if entitySpeed < ENTITY_STOPPED_SPEED  and
      entityDistToCourse < spaceNeededEntityToMyCourse then
      
      printDebug("  Entity is stopped on course.")
      return true, RIGHT
   end
   
   --Parallel courses; interfere if the ships are close each other.
   --If sin(angle between) is zero, then the collision computation below
   --will have a divide-by-zero, so handle the case here.
   if sinAngleBetweenCourses < 1.0e-2 then
      if entityDistToCourse < spaceNeededEntityToMyCourse then
      
         if myDirection:dotVector3D(entityDir) > 0 then --Going in same direction
            if mySpeed > entitySpeed and  -- Going faster
               vectorToEntity:getRange() < math.max( -- Getting close
                  mySize:getForward() * 2.0 + bufferSize,
                  myTurnRadius) then
                  
               printDebug("  Overtaking entity on same course.")
               return true, sideToMe
            else
               printDebug("  Trailing entity, not overtaking")
               return false
            end
         else --Going opposite directions
            printDebug("  Entity on head-on collision course.")
            return true, oppositeSide(sideToMe)
         end
      else
         printDebug("  Entity on parallel course") --not interfering
         return false
      end
   else
      -- The courses of myship and the entity intersect. 
      -- Determine if the times that the ships are near the intersection
      -- point overlap.
      
         -- This is the distance from the intersection point along
         -- the entity's course that the entity will be close enough to 
         -- myship's course to interfere with it.
      local entityConflictLength = spaceNeededEntityToMyCourse / 
         sinAngleBetweenCourses
         
         -- Similarly, distance from the intersection point along
         -- my course that my ship will be close enough to the
         -- entity's course to interfere with the entity.
      local myConflictLength = mySize:getForward()/2 + 
         (mySize:getRight()/2 * cosAngleBetweenCourses + 
         entitySize:getRight()/2 + bufferSize)/
           sinAngleBetweenCourses
      
      if onCollisionCourse(vectorToEntity, myDirection, mySpeed, myConflictLength,
         entityDir, entitySpeed, entityConflictLength, entitySize:getForward())
      then
         if isBehindEntity then  -- Avoid entity my ship is overtaking <<<<<<<<<<<<<
            -- If our course passes behind entity, try just slowing down
               -- Entity is already beyond our course and aimed away:
            if sideToMe == sideToEntity then
               printDebug("  On collision course, overtaking, slowing to pass behind")
               return true, SLOW
            else
               -- Otherwise turn to parallel course while passing
               printDebug("  On collision course, overtaking")
               return true, sideToMe
            end
         else
            -- The cases that fall here include:
            -- Avoid ships approaching from the right <<<<<<<<<<<<<<<<<<<<<<<<<
            -- Avoid ships approaching from the left with higher nav priority
            -- Avoid ships approaching from dead ahead on similar courses <<<<<
            -- Avoid ships my ship is overtaking <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            -- Avoid ships with higher priority overtaking my ship <<<<<<<<<<<<
            printDebug("  On collision course")
            return true, oppositeSide(sideToMe)
         end
      else
         printDebug("  Entity not on collision path.")
         return false
      end     
   end
   printDebug("  Error--entity geometry not determined")
   return false -- should never get to this statement
end

-- Returns two values: 1) a boolean indicating that this entity must
-- be avoided, and 2) if true, the direction around which my ship should go
function isActionRequiredForEntity(entity, goalHeading)
   -- AC Carrier > fishing trawler > large ship > sailboat > small ship
   
   local entityNavClass = getNavClass(entity)
   printDebug("   Entity nav class ", entityNavClass, ", priority ",
      navPriority[entityNavClass])
      
   -- Always ignore ship of lower priority, <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   -- unless it is stopped.
   -- (TODO-- should probably have emergency avoidance even for
   -- ships without the right of way.)
   local entitySpeed = entity:getSpeed()
   if navPriority[myNavClass] > navPriority[entityNavClass] and
      entitySpeed >= ENTITY_STOPPED_SPEED then
      return false
      -- If entity is stopped, then it will be checked below, and
      -- avoided if my ship is on a collision course.
   end

   local goalDirection = Vector3D(math.cos(goalHeading),
      math.sin(goalHeading), 0)
   local mySpeed = this:getSpeed()
   local myDirection = this:getDirection3D()
   myDirection:setNorthEastDown(myDirection:getNorth(),
      myDirection:getEast(), 0)
   myDirection = myDirection:getUnit()

   local pq = this:getLocation3D():vectorToLoc3D(
         entity:getLocation3D())

   local entitySize
   local offset
   entitySize, offset = entity:getBoundingVolume()
   
   local entityDir = entity:getDirection3D()
   entityDir:setNorthEastDown(entityDir:getNorth(),
      entityDir:getEast(), 0)
   entityDir = entityDir:getUnit()
   
   -- #### Consider entities relative to the goal heading ####
   
   -- We consider the goal heading so that the ownship will track the
   -- entities it needs to avoid if it turned back to its goal. 
   -- This way, the ship won't turn away, stop reacting, turn back
   -- to its goal, then immediately react again; instead it will
   -- continue to react until it is clear of the entity.
   
   local doAvoid
   local avoidDirection
   
   printDebug("  Checking goal direction:")
   doAvoid, avoidDirection = avoidEntityGivenOwnDirection(
      pq, goalDirection, 
      mySpeed * myDirection:dotVector3D(goalDirection),
      entityNavClass, entityDir, entitySpeed, entitySize) 
   
   if doAvoid then
      return true, avoidDirection
      
   elseif myDirection:dotVector3D(goalDirection) < 0.99 then
      
   -- #### Consider entities relative to the actual ownship heading ####
   
   -- If the ownship has turned away from an entity, it might be heading
   -- into another collision, so watch its actual path too.
   
      printDebug("  Checking current movement direction")
      doAvoid, avoidDirection = avoidEntityGivenOwnDirection(
         pq, myDirection, mySpeed, 
         entityNavClass, entityDir, entitySpeed, entitySize) 
      
      if doAvoid then
         return true, avoidDirection
      end
   end
   return false
end


function isActionRequired(goalHeading)
   local evade = false
   
      -- Assume we can't maneuver if stopped
   if this:getSpeed() > 0.1 then
      shipsToAvoid = {}
      if (myMoveSystem) then
         local err
         local r
         r, err = myMoveSystem:getAttribute("current-min-turn-radius")
         if not err then 
            myTurnRadius = r 
         end
      end   
      printDebug(string.format("New turn radius %.1f; goal heading %.3f",
         myTurnRadius, goalHeading))
      
      local currentSimTime = vrf:getSimulationTime()
      if nextShipCheckTime <= currentSimTime then
         nearbyShips = vrf:getSimObjectsNearWithFilter(this:getLocation3D(),
            myTurnRadius * INTEREST_RADIUS_FACTOR,
            {types={"1:3:-1:-1:-1:-1:-1"}, ignore={this}})
            
         nextShipCheckTime = currentSimTime + NEW_SHIP_CHECK_PERIOD
      end
         
      local i
      local v
      local doAvoid
      local avoidDirection
      local numShips = 0
      for i, v in ipairs(nearbyShips) do
         -- Easier to test for relevant types, then list all the types to filter
         -- in the getSimObjects call.
		if v ~= this then
         if vrf:entityTypeMatches(v:getEntityType(),
            EntityType.PlatformSurface()) or
            (vrf:entityTypeMatches(v:getEntityType(),
             EntityType.PlatformSubsurface()) and
             -v:getHeightAboveTerrain() < MAX_SUB_DEPTH) then
             
            printDebug(v, ": range ",
               this:getLocation3D():distanceToLocation3D(
               v:getLocation3D()))
            doAvoid, avoidDirection = isActionRequiredForEntity(v, goalHeading)
            if doAvoid then
               -- Make a list of ships to avoid
               table.insert(shipsToAvoid, {v, avoidDirection})
               evade = true
            end
         end
		end
       numShips = numShips +1
      end
      printDebug(string.format("Avoid Ships: Processed %d ships", numShips))
   end
   
   return evade
end


function avoidanceWeight(distance)
   local normDistance = distance /myTurnRadius
   return AVOIDANCE_WEIGHT_FACTOR / normDistance
end   

function repulsionWeight(distance)
--~    local normDistance = distance/ myTurnRadius
--~    local rFactor = normDistance^REPULSION_EXPONENT
--~    return REPULSION_WEIGHT_FACTOR/ rFactor
   return 0
end
      
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------


function checkInit()
   vrf:setTickPeriod(TICK_PERIOD)
end

function check()
   printDebug("Check...")
   if not myMoveSystem then 
      printWarn(vrf:trUtf8("   Error: no movement system found"))
      return false
   end
   originalHeading = this:getHeading() -- Guess where main task wants to go
   
   local err
   myOrderedSpeed, err = myMoveSystem:getAttribute("ordered-speed")
   if err then
      printWarn(vrf:trUtf8("   Error: could not get ordered speed"))
      return false
   end
   
   return isActionRequired(originalHeading)
end

function init()
   vrf:setTickPeriod(TICK_PERIOD)
   subtaskId = -1
end


function tick()
   printDebug("Tick: ", vrf:getExerciseTime())
   
   -- Check to see if the way is clear.
   -- Note that originalHeading is updated every time check() is run,
   -- while the foreground move task is running. When the reaction
   -- triggers, originalHeading stays fixed at the last value from the
   -- move task. This is assumed to be the goal direction for the ship.
   --
   -- This also refreshes shipsToAvoid and myTurnRadius
   if isActionRequired(originalHeading) then
      
      -- Start with a pull toward the goal.
      local netDesiredDirection = Vector3D(math.cos(originalHeading),
         math.sin(originalHeading), 0)
      
      -- Go through each ship, and add an influence direction.
      local i
      local record
      local v
      local avoidDirection
      for i, record in ipairs(shipsToAvoid) do
         v = record[1]
         avoidDirection = record[2]
         local vectorFromEntity = v:getLocation3D():vectorToLoc3D(
            this:getLocation3D())
         vectorFromEntity:setNorthEastDown(
            vectorFromEntity:getNorth(),
            vectorFromEntity:getEast(),
            0.0)
         local unitFromEntity = vectorFromEntity:getUnit()

         local tangent = Vector3D(unitFromEntity:getEast(),
               -unitFromEntity:getNorth(), 0)
         if avoidDirection == LEFT then
            tangent = tangent:getNegated()
         elseif avoidDirection == SLOW then
            tangent = this:getDirection3D():getNegated()
         end
         
         local range = this:getLocation3D():distanceToLocation3D(
            v:getLocation3D())
--~          local closingSpeed = v:getVelocity3D():dotVector3D(
--~             unitFromEntity) -
--~             this:getVelocity3D():dotVector3D(unitFromEntity)
         local turnWeight = avoidanceWeight(range) --, closingSpeed)
         local avoidanceVector = tangent:getScaled(turnWeight)
         netDesiredDirection = netDesiredDirection:addVector3D(
            avoidanceVector)
         local repelWeight = repulsionWeight(range)
         local repulsionVector = unitFromEntity:getScaled(repelWeight)
         netDesiredDirection = netDesiredDirection:addVector3D(
            repulsionVector)
         printDebug(string.format(
            "Entity %s: avoid vector (%.2f, %.2f), weight %.2f; repel weight %.2f", 
            v:getName(), avoidanceVector:getEast(), avoidanceVector:getNorth(),
            turnWeight, repelWeight))
      end
      
      -- *** Control heading ***
      local desiredHeading = netDesiredDirection:getBearing()
      printDebug(string.format("Net desired heading = %.3f", 
         desiredHeading))
      
      local deltaHeading = desiredHeading - this:getHeading()
      if deltaHeading > math.pi then
         deltaHeading = deltaHeading - math.pi * 2
      elseif deltaHeading < -math.pi then
         deltaHeading = deltaHeading + math.pi * 2
      end
      if math.abs(deltaHeading) > TURN_CONTROL_THRESHOLD then
         local turnDir
         if deltaHeading > 0 then
            turnDir = RIGHT
         else
            turnDir = LEFT
         end
            
         local desiredTurnRate = this:getSpeed()/
            (myTurnRadius * TURN_EASING_FACTOR)
         printDebug(string.format(
            "Delta heading %.3f; turn rate %.4f, max rate needed %.4f", 
            deltaHeading, desiredTurnRate, 
            math.abs(deltaHeading)/TICK_PERIOD))
         -- Attempt to control the turn a little more smoothly than bang-bang
         if desiredTurnRate > math.abs(deltaHeading)/TICK_PERIOD then
            desiredTurnRate = math.abs(deltaHeading)/TICK_PERIOD
         end
         
         -- If there is no turn subtask running, or if the turn direction
         -- or turn rate has changed, start a new turn task.
         if turnTaskID == -1 or
            (currentlyTurningRight and turnDir == LEFT) or
            (not currentlyTurningRight and turnDir == RIGHT) or
            desiredTurnRate > currentTurnRate * 1.1 or
            desiredTurnRate < currentTurnRate * 0.9 then
            
            currentlyTurningRight = (turnDir == RIGHT)
            currentTurnRate = desiredTurnRate
            turnTaskID = vrf:startSubtask("turn-move", 
               {turnType = 2, -- Continuous turn
                turnRateSelector = 1, --Specify turn rate in rad/sec
                turnRate = desiredTurnRate, -- Always positive
                turnDirection = turnDir}) -- 1=left, 2=right
         end -- Otherwise, do nothing   
      else
         -- We are at the desired heading; kill the turn subtask
         vrf:stopSubtask(turnTaskID)
         turnTaskID = -1
      end
      
      -- *** Control speed ***
      
      -- If obstacle avoidance if pushing the ship far away from the
      -- original heading of the task, slow it down.
      local cosOffset = math.cos(originalHeading - desiredHeading)
      local desiredSpeedFactor = cosOffset + 1.0
      if desiredSpeedFactor < MIN_SPEED_FACTOR then
         desiredSpeedFactor = MIN_SPEED_FACTOR
      elseif desiredSpeedFactor > 1.0 then
         desiredSpeedFactor = 1.0
      end
      printDebug(string.format(
         "Cos (goal - avoid heading) = %.4f; speed factor %.2f",
         cosOffset, desiredSpeedFactor))
      if math.abs(desiredSpeedFactor - currentSpeedFactor) >
         SPEED_CONTROL_THRESHOLD then
         
         local desiredSpeed = desiredSpeedFactor * myOrderedSpeed
         vrf:executeSetData("set-speed", 
            {speed = desiredSpeed})
         currentSpeedFactor = desiredSpeedFactor
      end
   else
      vrf:executeSetData("set-speed", 
            {speed = myOrderedSpeed})
      currentSpeedFactor = 1.0
      vrf:endTask(true)
      turnTaskID = -1
   end
end
            

function suspend()
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
end

function resume()
end

function receiveTextMessage(message, sender)
end
