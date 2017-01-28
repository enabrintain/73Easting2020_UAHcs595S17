-- This script implements an individual suppressive fire task.


-- Some basic VRF Utilities defined in a common module.
require "vrfutil"


DEBUG_DETAIL = false

-- Constants (global variables):

-- The closest that an obstacle can be for suppressive fire to
-- be aimed in that direction (meters):
MIN_FIRE_OBSTACLE_DISTANCE_FROM_SHOOTER  = 8.0
-- The maximum distance and obstacle can be in front of the
-- target point before that point is considered obstructed (meters):
MAX_FIRE_OBSTACLE_DISTANCE_FROM_TARGET = 5.0
-- Number of times to try to find an aim point that isn't
-- obstructed before giving up the task:
TARGET_RETRIES = 10
-- How far to either side of a point target the suppressive
-- fire will be spread (meters):
POINT_TARGET_SPREAD = 3.0
-- How many times to generate points around the target area
-- looking for one inside the area, before giving up
POINT_IN_AREA_TRIES = 50
-- Height above the terrain to fire (grazing fire):
GRAZING_HEIGHT = 1.0
-- Variation in the pause before the next fire time (as determined
-- by the rapid- or sustained-fire-rate). A value from 0-1, 
-- where 0 means that the gun fires again as soon as it can, and 
-- 1.0 means it takes twice as long as it otherwise would.
FIRE_TIME_VARIATION = 0.3

-- Global variables:

-- Weapon system to use:
mySystem = nil
-- The weapon name for the system (should be from taskParameters.useGun,
-- but if that weapon can't be found another may be used):
myGunName = ""
-- Offset to weapon muzzle, approximately:
myWeaponOffset = nil
-- Handle for subtasks:
taskId = -1
-- Define target information for calculations every tick.
target = {
   -- Which parameter is in use: "point", "line", "area":
   targetType = "",
   -- These members depend on the target type, and are created
   -- at init time:
--~       -- A Location3D of the target when it is a point:
--~       targetLocation = ,
--~       -- An array of 2 Location3Ds when the target is a line:
--~       targetLine = nil,
--~       lineLength = nil, -- Remember the length for repeated computation
--~       lineUnit = nil, -- Remember the normalized direction
--~       -- A number from 0 to 1 indicating where along the target line the
--~       -- last target point was.
--~       linePositionParam = 0.5,
--~       -- Indicator for which direction along the line the weapon is traversing.
--~       -- Value is +- 1.
--~       traverseDirection = 1,
--~       -- A SimObject area, when the target is an area:
--~       targetArea = nil,
--~       -- Target area bounding box
--~       latMin = 0,
--~       latSize = 0,
--~       lonMin = 0,
--~       lonSize = 0
}
-- A temporary control point used to direct fire:
tempPoint = nil
-- For keeping track of ammo expenditure in task:
roundsFired = 0
-- Copy of gun system parameter:
roundsPerTriggerPull = 1
-- End rapid fire time:
timeEndRapidFire = 0
-- Rapid fire period-- seconds between trigger pulls. 
-- This will be rounds per trigger pull / rpm for rapid fire * 60:
secondsPerTriggerPullRapid = 5
secondsPerTriggerPullSustained = 10
timeLastTriggerPull = 0
timeNextTriggerPull = 0
-- End task time:
timeEndTask = 0

-- 

-- Task Parameters Available in Script
--  taskParameters.targetLocation Type: Location3D - An alternative method of specifying the target point.
--  taskParameters.targetObject Type: SimObject - Choose a point (or entity), line, or area.
--  taskParameters.durationRapid Type: Integer Unit: seconds - Time that weapon is fired at rapid rate
--  taskParameters.durationTotal Type: Real Unit: minutes - Total time that suppressive fire will be provided.
--  taskParameters.ammoLimit Type: Integer - Max number of rounds entity should shoot.
--  taskParameters.useGun Type: String (weapon name) - Select which gun on the entity to use for suppressive fire.

------- INITIALIZATION ==========================================================
-- Use the global variable taskParameters to set the global
-- variables targetType and targetLocation.

function determineTargetType()   
   if taskParameters.targetObject:isValid() then
      local objType = taskParameters.targetObject:getEntityType()
      
      if vrf:entityTypeMatches(objType, EntityType.PointObject()) or
         vrf:entityTypeMatches(objType, EntityType.Lifeform()) or
         vrf:entityTypeMatches(objType, EntityType.PlatformLand())
         then
         
         target.targetType = "point"
         target.targetLocation = taskParameters.targetObject:getLocation3D()
	 
	 vrf:updateTaskVisualization ("SuppressionPoint", "point", 
	    {color={255,0,0,128}, size=1, location=target.targetLocation})
      
      elseif vrf:entityTypeMatches(objType, EntityType.LinearObject()) then
         target.targetType = "line"
         target.targetLine = taskParameters.targetObject:getLocations3D()
         local size = #target.targetLine
         local lineVector = target.targetLine[1]:
            vectorToLoc3D(target.targetLine[size])
         target.lineLength = lineVector:getRange()
         target.lineUnit = lineVector:getUnit()
         target.linePositionParam = 0.5
         target.traverseDirection = 1
         if math.random() > 0.5 then target.traverseDirection = -1 end
	 
	 vrf:updateTaskVisualization ("SuppressionLine", "line", 
	    {color={255,0,0,128}, size=1, locations=target.targetLine})
         
      elseif vrf:entityTypeMatches(objType, EntityType.ArealObject()) then
         target.targetType = "area"
         target.targetArea = taskParameters.targetObject
         findBoundingBox(target)
	 
	 vrf:updateTaskVisualization ("SuppressionArea", "area", 
	    {color={255,0,0,128}, size=1, taskParameters.targetObject:getLocations3D()})
      
      else
         printWarn("Target object not appropriate as a target type.")
         vrf:endTask(false)
         return
      end
   elseif taskParameters.targetLocation ~= nil then
      target.targetType = "point"
      target.targetLocation = taskParameters.targetLocation
      
   else
      printWarn("No valid target specified for suppressive fire.")
      vrf:endTask(false)
      return
   end
   if DEBUG_DETAIL then
      printDebug("Suppressive fire target type ", target.targetType)
   end
end

function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   determineTargetType()
   -------------------------------
   -- Gun characteristics
   mySystem = Util.findSystem(taskParameters.useGun)
   if mySystem == nil then
      printWarn("Specified gun system ",
         taskParameters.useGun,
         " not found.")
      
      if DEBUG_DETAIL then
         printWarn("Systems available:")
         names = this:getSystemNames()
         for i, n in ipairs(names) do
            printWarn("  ", n)
         end
      end
      myGunName = vrf:getSystemName()
      mySystem = this:getSystem(myGunName)
      if mySystem == nil then
         printWarn("Could not find system for this task.")
         vrf:endTask(false)
         return
      else
         printWarn("Using weapon ", myGunName)
      end   
   else
      myGunName = taskParameters.useGun
      if DEBUG_DETAIL then
         printDebug("Found gun ", myGunName)
      end
   end
   
   -- TMP
   -- Should get this value from current entity configuration...
   -- but it isn't available in the API yet.
   myWeaponOffset = VectorOffset3D(0, 0, 1.5)
   
   local error = false
   roundsPerTriggerPull = mySystem:getAttribute("rounds-per-trigger-pull")
   if error then
      roundsPerTriggerPull = 1
   end
   local fireRate = vrf:getScriptAttribute("rapid-fire-rate")
   if fireRate ~= nil and fireRate ~= 0 then
      secondsPerTriggerPullRapid = roundsPerTriggerPull * 60 / fireRate
   elseif DEBUG_DETAIL then
      printWarn("Unable to get rapid fire rate from system data.")
   end
   fireRate = vrf:getScriptAttribute("sustained-fire-rate")
   if fireRate ~= nil and fireRate ~= 0 then
      secondsPerTriggerPullSustained = roundsPerTriggerPull * 60 / fireRate
   elseif DEBUG_DETAIL then
      printWarn("Unable to get sustained fire rate from system data.")
   end
   if DEBUG_DETAIL then
      printDebug("Rounds/volley: ", roundsPerTriggerPull)
      printDebug("Rapid fire trigger period: ", secondsPerTriggerPullRapid,
         ", sustained fire trigger period: ", secondsPerTriggerPullSustained)
   end
   --------------------------------
   local timeNow = vrf:getSimulationTime()
   timeEndRapidFire = timeNow + taskParameters.durationRapid
   timeEndTask = timeNow + taskParameters.durationTotal * 60
   if timeEndTask <= timeNow then
      printWarn("Suppressive fire duration 0, ending task.")
      vrf:endTask(false)
      return
   end
   if DEBUG_DETAIL then
      printDebug(string.format("Rapid fire until %f, sustained until %f",
         timeEndRapidFire, timeEndTask))
   end
   --------------------------------

   -- Call this to trigger load of features
--~    local pt
--~    if target.targetType == "point" then
--~       pt = target.targetLocation
--~    else
--~       pt = target.targetLocation[1]
--~    end
--~    vrf:doesChordHitTerrain(this:getLocation3D(), pt)
end

------ TICK ==========================================================

function tick()
   local timeNow = vrf:getSimulationTime()
   if taskId == -1 and roundsFired == 0 then -- First time in tick
      local aimLoc = generateFirstPoint(target)
      if aimLoc == nil then
         printWarn("Error creating aim point.")
         vrf:endTask(false)
         return
      end
      tempPoint = vrf:createTacticalGraphic({entity_type = "16:0:0:2:0:0:0", 
         location = aimLoc, publish = DEBUG_DETAIL})
      taskId = vrf:startSubtask("fire-at-target", {
         target = tempPoint,  -- Note this target is the string "target"
         weapon_to_fire = myGunName})
      if taskId == -1 then
         printWarn("Error starting fire-at-target task. Ending suppressive fire.")
         vrf:endTask(false)
         return
      end
      timeLastTriggerPull = timeNow
      -- Also set the aiming point for the gun while not firing to this same point,
      -- so that the gun will not return to its neutral orientation between shots.
         -- (Except human entities??)
      vrf:executeSetData("set-aiming-point", {aiming_type = 0, aiming_point = aimLoc})
      if timeNow < timeEndRapidFire then
         timeNextTriggerPull = timeNow + secondsPerTriggerPullRapid
      else
         timeNextTriggerPull = timeNow + secondsPerTriggerPullSustained
      end
      if DEBUG_DETAIL then
         printVerbose("Started fire at target task")
      end
      
   elseif taskId == -1 then --Waiting to shoot again
      if timeNow >= timeEndTask then
         vrf:endTask(true)
         return
      elseif timeNow >= timeNextTriggerPull then      
         local  testPoints
         local aimLoc = generateNextPoint(target)
         local tries = 1
         local validPt = validAimPoint(aimLoc)
         while tries < TARGET_RETRIES and
            not validPt do
            
            if DEBUG_DETAIL then
               printDebug("Aim point not valid, trying again.")
            end
            tries = tries + 1
            aimLoc = generateNextPoint(target)
            validPt = validAimPoint(aimLoc)
         end
         if not validPt then
            printWarn ("Couldn't find unblocked aim point at least ",
               MIN_FIRE_OBSTACLE_DISTANCE_FROM_SHOOTER,
               "m away. Ending fire task.")
            vrf:endTask(true)
            return
         end
         tempPoint = vrf:createTacticalGraphic({entity_type = "16:0:0:2:0:0:0", 
            location = aimLoc, publish = DEBUG_DETAIL})
         taskId = vrf:startSubtask("fire-at-target", {
            target = tempPoint,   -- Note this target is the string "target"
            weapon_to_fire = myGunName})
         if taskId == -1 then
            printWarn("Error starting fire-at-target task. Ending suppressive fire.")
            vrf:endTask(false)
            return
         end
         timeLastTriggerPull = timeNow
         -- Also set the aiming point for the gun while not firing to this same point,
         -- so that the gun will not return to its neutral orientation between shots.
         -- (Except human entities??)
         vrf:executeSetData("set-aiming-point", {aiming_type = 0, aiming_point = aimLoc})
         if DEBUG_DETAIL then
            printVerbose(string.format("%.3f Suppression: Started fire at target task",
               timeNow))
         end

      elseif DEBUG_DETAIL then
         printDebug("Suppression: Waiting ", timeNextTriggerPull - timeNow, 
            " more seconds to pull trigger again")
      end
      
   elseif taskDone(taskId) then -- Firing task done
      vrf:deleteObject(tempPoint) 
      roundsFired = roundsFired + roundsPerTriggerPull
      if  timeNow >= timeEndTask or
         roundsFired >= taskParameters.ammoLimit then
         vrf:endTask(true)
         return
      else
         local randFactor = 2 * (math.random() - 0.5) * FIRE_TIME_VARIATION
         -- Find out whether we are still in the rapid fire time or 
         -- have transitioned to the sustained fire time.
         if timeNow < timeEndRapidFire then
            timeNextTriggerPull = timeLastTriggerPull + 
               secondsPerTriggerPullRapid * (1 + randFactor)
            if DEBUG_DETAIL then
               printVerbose(string.format("%.3f Suppression: Fired %d rounds. Rapid fire, next shot at %.3f", 
                  timeNow, roundsFired, timeNextTriggerPull))
            end
         else
            timeNextTriggerPull = timeLastTriggerPull + 
               secondsPerTriggerPullSustained * (1 + randFactor)
            if DEBUG_DETAIL then
               printVerbose(string.format("%.3f Suppression: Fired %d rounds. Sustained fire, next shot at %.3f", 
                  timeNow, roundsFired, timeNextTriggerPull))
            end
         end
         taskId = -1
      end
   end
end

-- =======================================================================

-- Compute and return the location of the first aim point.
-- For a point target, return the point, 1m above the ground (below 
-- the input point).
-- For a line, return the point midway between the two end points,
-- 1m above the ground (below the true midpoint, unless that point is
-- below ground; then 1m above the top surface).
-- For an area, return a point in the area, 1m above the ground.
-- Returns nil if there is an error generating the point.
function generateFirstPoint(targetInfo)
   local aimPoint = nil
   if targetInfo.targetType == "point" then
      aimPoint = targetInfo.targetLocation:makeCopy()
   elseif targetInfo.targetType == "line" then
      local t = targetInfo.linePositionParam
      aimPoint = targetInfo.targetLine[1]:addVector3D(
         targetInfo.lineUnit:getScaled(targetInfo.lineLength * t))
      
   elseif targetInfo.targetType == "area" then
      aimPoint = makePointInArea(targetInfo)
   end
   if aimPoint then
      aimPoint = setAimAltitude(aimPoint)
   end
   return aimPoint
end

function generateNextPoint(targetInfo)
   local aimPoint = nil
   if targetInfo.targetType == "point" then
      -- Randomly pick a distance <= POINT_TARGET_SPREAD,
      -- compute the angle to a point this far to the side
      -- of the target, and compute the point there.
      local vecToTarget = this:getLocation3D():vectorToLoc3D(
         targetInfo.targetLocation)
      local azOffset = vrf:gaussian()
      azOffset = math.max(azOffset, -1.0)
      azOffset = math.min(azOffset, 1.0)
      azOffset = azOffset * POINT_TARGET_SPREAD
      local range = vecToTarget:getRange()
      local angleOffset = math.atan(azOffset/range)
      if DEBUG_DETAIL then
         printDebug("New point target bearing offset: ", angleOffset)
      end
      
      vecToTarget:setBearingInclRange(
         vecToTarget:getBearing() + angleOffset,
         vecToTarget:getInclination(),
         range)
         
      aimPoint = this:getLocation3D():addVector3D(vecToTarget)
            
   elseif targetInfo.targetType == "line" then
      -- Pick a random point a long the line, not too far from
      -- the last aim point.
      local t = math.random()/4 * targetInfo.traverseDirection + 
         targetInfo.linePositionParam 
      if t < 0.0 then
         t = 0
         targetInfo.traverseDirection = 1
      elseif t > 1.0 then
         t = 1.0
         targetInfo.traverseDirection = -1
      end
      if DEBUG_DETAIL then
         printDebug("New line t parameter ", t)
      end
      aimPoint = targetInfo.targetLine[1]:addVector3D(
         targetInfo.lineUnit:getScaled(targetInfo.lineLength * t))
      targetInfo.linePositionParam = t
      
   elseif targetInfo.targetType == "area" then 
      aimPoint = makePointInArea(targetInfo)
   end
   if aimPoint then
      aimPoint = setAimAltitude(aimPoint)
   end
   return aimPoint
end

----------------------------------------------------------------------
-- Utility Functions

-- Check the proposed aim point to see if the line of fire is clear to
-- within MAX_FIRE_OBSTACLE_DISTANCE_FROM_TARGET of the point.
-- Also, if the point is really close, the line of fire still has to be
-- clear out to a range of at least MIN_FIRE_OBSTACLE_DISTANCE_FROM_SHOOTER.
function validAimPoint(aimLocation)
   if aimLocation == nil then
      return false
   end
   local myDir = this:getDirection3D()
   local worldOffset = myWeaponOffset:makeVectorRefToDirection(myDir)
   local shootLoc = this:getLocation3D():addVector3D(worldOffset)
   local shootVec = shootLoc:vectorToLoc3D(aimLocation)
   local range = shootVec:getRange()
   local obstacleRange = range - MAX_FIRE_OBSTACLE_DISTANCE_FROM_TARGET
   local testRange = math.max(obstacleRange, MIN_FIRE_OBSTACLE_DISTANCE_FROM_SHOOTER)
   shootVec:setBearingInclRange(shootVec:getBearing(),
      shootVec:getInclination(), testRange)
   local testLoc = shootLoc:addVector3D(shootVec)
   local blocked = vrf:doesChordHitTerrain(shootLoc, testLoc)
--~    if DEBUG_DETAIL then
--~       local myLoc = this:getLocation3D()
--~       printDebug(string.format("   Ent loc: %f, %f, %.1f",
--~          math.deg(myLoc:getLat(), math.deg(myLoc:getLon()), myLoc:getAlt()))
--~       printDebug(string.format("   Muzzle loc: %f, %f, %.1f",
--~          math.deg(shootLoc:getLat()), math.deg(shootLoc:getLon()), shootLoc:getAlt()))
--~       printDebug(string.format("   Aim loc: %f, %f, %.1f",
--~          math.deg(aimLocation:getLat()), math.deg(aimLocation:getLon()), aimLocation:getAlt()))
--~       printDebug("   Test range ", testRange, 
--~          ", blocked = ", blocked)
--~    end 
   return not blocked 
end

-- Set the altitude above ground to be GRAZING_HEIGHT at
-- the given point. Look below the point, rather than for the top-most surface,
-- in case the given point is in a building. 
-- The query for a surface starts GRAZING_HEIGHT + 0.1 above the height of the
-- given point; if there is no surface below, then the input altitude is used.
-- Returns a point with the altitude set appropriately.
function setAimAltitude(aimLoc)
   -- Bump up the altitude a little in case this is a point or entity on the ground
   local inLoc = aimLoc:makeCopy()
   local inHeight = aimLoc:getAlt()
   inLoc:setAlt(inHeight + GRAZING_HEIGHT + 0.1)
   local groundHeight, valid, surface = vrf:getTerrainAltitudeBelow(inLoc)
   local groundFound = true
   -- If terrain isn't loaded, or no surface was found below, or if the only
   -- surface is global ocean, then use the input height.
   -- To catch global ocean, we prevent grazing fire over actual ocean, but
   -- that's probably OK.
   if not valid or surface == "NoSurface" or surface == "Ocean" then
      groundHeight = inHeight
      groundFound = false
      if DEBUG_DETAIL then
         printDebug(string.format("   No ground found at point (%f, %f, %.2f)",
            math.deg(inLoc:getLat()), math.deg(inLoc:getLon()), inLoc:getAlt()))
      end
   end
   inLoc:setAlt(groundHeight + GRAZING_HEIGHT)
   if DEBUG_DETAIL then
      printDebug("   Ground found: ", groundFound, ", surface ", surface)
      printDebug(string.format("   Aim nominal altitude %.1f; set altitude %.1f",
         inHeight, groundHeight + GRAZING_HEIGHT))
   end
   return inLoc
end

-- Finds the bounding box of the area contained in the targetInfo structure.
-- The bbox is represented in terms of a lower-left corner and size in latitude
-- and longitude angles. The results are returned in the targetInfo structure.
-- Note that this algorithm will not work correctly for areas that extend
-- over more than 180 degrees of longitude, or that surround a pole.
function findBoundingBox(targetInfo)
   if targetInfo.targetType ~= "area" then
      vrf:endTask(false)
      return
   end
   local points = targetInfo.targetArea:getLocations3D()
   local minLat = math.huge
   local maxLat = -minLat
   local minLon = minLat
   local maxLon = maxLat
   for i, point in ipairs(points) do
      local lat = point:getLat()
      local lon = point:getLon()
      if lat < minLat then minLat = lat end
      if lat > maxLat then maxLat = lat end
      if lon < minLon then minLon = lon end
      if lon > maxLon then maxLon = lon end 
   end
   -- If the area crosses the line where lon flips from 180 to -180,
   -- reset the negative values to values > 180 degrees.
   -- This doesn't work if the area spans longitude > 180 degrees.
   if maxLon - minLon > math.pi then
      minLon = math.huge
      maxLon = -minLon
      for i, point in ipairs(points) do
         local lon = point:getLon()
         if lon < 0.0 then lon = lon + 2*math.pi end
         if lon < minLon then minLon = lon end
         if lon > maxLon then maxLon = lon end 
      end   
   end
   targetInfo.latMin = minLat
   targetInfo.lonMin = minLon
   targetInfo.latSize = maxLat - minLat
   targetInfo.lonSize = maxLon - minLon
end

-- Attempt to generate a point inside the given area object.
-- Returns nil if none can be generated.
function makePointInArea(targetInfo)
   local aimPoint = Location3D(0, 0, 0)
   local tries = 0
   local valid = false
   while not valid and tries < POINT_IN_AREA_TRIES do
      -- Generate random parametric coordinates; average two
      -- calls to random to weight result toward center.
      local latT = (math.random() + math.random()) * 0.5
      local lonT = (math.random() + math.random()) * 0.5
      aimPoint:setLat(targetInfo.latMin + targetInfo.latSize * latT)
      aimPoint:setLon(targetInfo.lonMin + targetInfo.lonSize * lonT)
      aimPoint:setAlt(0.0)
      valid = targetInfo.targetArea:isPointInside(aimPoint)
      tries = tries + 1
   end
   if valid then
      -- Since areas don't have an elevation, get the top terrain surface
      local height, valid = vrf:getTerrainAltitude(
         aimPoint:getLat(), aimPoint:getLon())
      if valid then
         aimPoint:setAlt(height)
      end
      return aimPoint
   else
      return nil
   end
end
-- ==========================================================
-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
   -- By default, halt all subtasks and other entity tasks started by this task when suspending.
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
end

-- Called when this task is being resumed after being suspended.
function resume()
   -- By default, simply call init() to start the task over.
   init()
end

-- Called immediately before a scenario checkpoint is saved when
-- this task is active.
-- It is typically not necessary to add code to this function.
function saveState()
end

-- Called immediately after a scenario checkpoint is loaded in which
-- this task is active.
-- It is typically not necessary to add code to this function.
function loadState()
end


-- Called when this task is ending, for any reason.
-- It is typically not necessary to add code to this function.
function shutdown()
   vrf:executeSetData("set-aiming-point", {aiming_type = 3}) -- Cease aiming
   if tempPoint and tempPoint:isValid() then
      vrf:deleteObject(tempPoint)
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
