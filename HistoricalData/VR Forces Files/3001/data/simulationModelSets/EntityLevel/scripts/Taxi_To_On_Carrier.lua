-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

local DEBUG = false

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

local TAXI_SPEED = 1.5 -- In m/s
local LOOKAHEAD_TIME = 4 -- seconds to look ahead for obstructing vehicles
-- In order to avoid the computation cost of getting a filtered entity list,
-- only check whether the route is blocked at a low tick rate.
local CHECK_PERIOD_BLOCKED = 2 -- seconds between checks when
   -- the path is already blocked.
local CHECK_PERIOD_CLEAR = 0.9 -- seconds between checks when
   -- the path is currently clear.
local WING_FOLD_FRACTION = 0.7 -- Fraction multiplied by bounding volume width
   -- to produce the width with wings folded. All aircraft are assumed to have
   -- their wings folded while taxiing on the carrier.
   
-- What types of entities can block movement
local blockingTypes = {EntityType.PlatformAir(), 
               EntityType.PlatformLand(),
               EntityType.CulturalFeature()}



-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
subtaskId = -1
taskState = ""
movementSystem = nil -- Name of the entity's movement system
flyingSpeed = 0 -- Save the ordered speed for flying and restore after taxiing
routePoints = nil -- Table of points on route
nextBlockCheckTime = 0
blockingVehicle = nil -- Who is blocking the plane currently

function foldedFraction(entity)
   if vrf:entityTypeMatches(EntityType:PlatformAir(),
      entity:getEntityType()) then
      return WING_FOLD_FRACTION
   else
      return 1.0
   end
end
local myHalfWidth = this:getBoundingVolume():getRight()/2 * foldedFraction(this)
local myHalfLength = this:getBoundingVolume():getForward()/2


-- Task Parameters Available in Script
--  taskParameters.destinationPoint Type: Location3D - Click on map to set destination point on carrier.
--  taskParameters.route Type: SimObject - Create a route to a point close to the destination.
--  taskParameters.finalHeading Type: Real Unit: radian - The heading the aircraft will assume when it gets to its destination.
--  taskParameters.assumHeading Type: Boolean Whether the aircraft should be set at the final heading 

-- Called when the task first starts. Never called again.
function init()
   taskState = "start"
   flyingSpeed = this:getParameter("ordered-speed")
   if taskParameters.route:isValid() then
      routePoints = taskParameters.route:getLocations3D()
   end
   movementSystem = this:getSystem("movement")
   if not movementSystem then
      printWarn("Movement system not found-- exiting task")
      vrf:endTask(false)
   else
      if DEBUG then 
         printWarn("Found movement system ", 
            movementSystem:getName())
      end
   end
   
end

-- Called each tick while this task is active.
function tick()
   if taskState == "start" then
      
      vrf:executeSetData("set-speed", {speed = TAXI_SPEED})
      if routePoints ~= nil then
         local startLoc = routePoints[1]
         
         subtaskId = vrf:startSubtask("move-to-location", {aiming_point = startLoc})
         taskState = "move to route"
         if subtaskId == -1 then
            printWarn("Unable to start move to route.")
            vrf:endTask(false)
            return
         end
      else
         subtaskId = vrf:startSubtask("move-to-location",
            {aiming_point = taskParameters.destinationPoint})
         taskState = "move to destination"
         if subtaskId == -1 then
            printWarn("Unable to start move to destination.")
            vrf:endTask(false)
            return
         end
      end
   else
      if taskDone(subtaskId, true) then
         if taskState == "move to route" then
            subtaskId = vrf:startSubtask("move-along", 
               {route = taskParameters.route})
            taskState = "move on route"
            if subtaskId == -1 then
               printWarn("Unable to start move along route.")
               vrf:executeSetData("set-speed", {speed = flyingSpeed})
               vrf:endTask(false)
               return
            end
         elseif taskState == "move on route" then
            subtaskId = vrf:startSubtask("move-to-location",
               {aiming_point = taskParameters.destinationPoint})
            taskState = "move to destination"
            if subtaskId == -1 then
               printWarn("Unable to start final move to destination.")
               vrf:executeSetData("set-speed", {speed = flyingSpeed})
               vrf:endTask(false)
               return
            end
         elseif taskState == "move to destination" then
            if this:getSpeed() == 0 then
               taskState = "at destination"
            end
         elseif taskState == "at destination" then
            -- Make sure plane is exactly at destination.
            this:setLocation3D(taskParameters.destinationPoint)
            if taskParameters.assumeHeading then
               this:setHeading(taskParameters.finalHeading)
            end
            vrf:executeSetData("set-speed", {speed = flyingSpeed})
            vrf:endTask(true)
            return
         end
      end
   end
   
   -- Now check for blocking vehicles
   if vrf:getSimulationTime() > nextBlockCheckTime then
      
      if blockingVehicle == nil then
         local entities = getPotentialBlockers()
         if DEBUG then
            printWarn("Checking potential blocking vehicles:")
            for i, entity in ipairs(entities) do   
               printWarn(string.format("   %s", entity:getName()))
            end
         end
         blockingVehicle = findBlockingVehicle(entities)
         if blockingVehicle ~= nil then
            vrf:executeSetData("set-speed", 
               {speed = 0.0})
            nextBlockCheckTime = vrf:getSimulationTime() +
               CHECK_PERIOD_BLOCKED
         else
            nextBlockCheckTime = vrf:getSimulationTime() +
               CHECK_PERIOD_CLEAR
         end
      else
         -- If someone is blocking already, just check that
         if blockingVehicle:isValid() then
            local entities = {blockingVehicle}
            if DEBUG then printWarn("Checking for continued blockage by ", blockingVehicle:getName()) end
            blockingVehicle = findBlockingVehicle(entities)
            if blockingVehicle == nil then
               vrf:executeSetData("set-speed",
                  {speed = TAXI_SPEED})
               -- Leave nextBlockCheckTime the same, so a check
               -- will be made for other blockers the next tick.
            else
               nextBlockCheckTime = vrf:getSimulationTime() +
                  CHECK_PERIOD_BLOCKED
            end
         else
            vrf:executeSetData("set-speed",
               {speed = TAXI_SPEED})
            -- Leave nextBlockCheckTime the same, so a check
            -- will be made for other blockers the next tick.
         end
      end
   end
end

----------------------------------------------------------------------
-- Code to check for blocking entities while moving
----------------------------------------------------------------------

-- Get nearby VRF entities of the relevant types. 
-- Returns a table of entities.
function getPotentialBlockers()
   -- Add 2 lengths to search range: if all vehicles were the same
   -- size, we'd need to look at least 2* halfLength (my front half
   -- plus half of a blocking entity). Add to this to allow for
   -- larger vehicles.
   local searchRange = LOOKAHEAD_TIME * TAXI_SPEED + myHalfLength * 4
   return vrf:getSimObjectsNearWithFilter(this:getLocation3D(),
      searchRange,
      {types = blockingTypes})
end

-- Checks all the entities in the entities table against either
-- the route being followed or the final path to the destination
-- to see if any are close enough to block the move.
-- Returns the blocking entity, or nil if none.
function findBlockingVehicle(entities)
   if taskState == "move to route" or
      taskState == "move on route" then
      return isRouteBlocked(entities)
   else -- taskState is "move to destination"
      local startPt = this:getLocation3D()
      local endPt = taskParameters.destinationPoint
      local segVec = startPt:vectorToLoc3D(endPt)
      local segDir = segVec:getUnit()
      local lookDistance = LOOKAHEAD_TIME * TAXI_SPEED
      local segLength = segVec:getRange()
      if segLength > lookDistance then
         endPt = startPt:addVector3D(segDir:getScaled(lookDistance))
      end
      if DEBUG then printWarn("Lookahead distance ", lookDistance) end
      return isSegmentBlocked(startPt, endPt, segDir, entities)
   end
end

-- Check along the route ahead to see if any of the
-- given entities block it. Uses global variable
-- routePoints.
-- Returns the blocking entity if there is one, or
-- nil otherwise.
function isRouteBlocked(entities)
   local nextRouteVertex = movementSystem:getAttribute(
      "next-route-point-index")
   -- If the follow-route task isn't started yet, the local route vertex
   -- will be 0
   
   if DEBUG then printWarn("Next route vertex (0-based index): ", nextRouteVertex) end
   local distRemaining = LOOKAHEAD_TIME * TAXI_SPEED
   local i = nextRouteVertex + 1 -- Indices in table are 1-based
   local lastPoint = this:getLocation3D()
   local nextPoint
   while i <= #routePoints and distRemaining > 0 do
      nextPoint = routePoints[i]
      local segVec = lastPoint:vectorToLoc3D(nextPoint)
      local dist = segVec:getRange()
      if dist > distRemaining then
         -- Get a new point at distRemaining along the
         -- segment from lastPoint to nextPoint
         segVec:setBearingInclRange(
            segVec:getBearing(), segVec:getInclination(),
            distRemaining)
         nextPoint = lastPoint:addVector3D(segVec)
      end
      local blocker = isSegmentBlocked(lastPoint, nextPoint, segVec:getUnit(), entities)
      if blocker ~= nil then
         return blocker
      end
      distRemaining = distRemaining - dist
      lastPoint = nextPoint
      i = i+1
   end
   return nil
end

-- This is an imperfect collision check function. It is mostly
-- concerned with detecting an obstruction in front of the
-- aircraft, not making sure the bounding volume can rotate 
-- through space without collisions.
-- The test checks for a distance past the end point given,
-- to account for the aircraft's front end (myHalfLength) extending
-- beyond the end.
-- Returns nil if false, and 
function isSegmentBlocked(startPt, endPt, segDir, entities)
   for i, entity in ipairs(entities) do
      if entity ~= this then
         local entBV = entity:getBoundingVolume()
         local hW = entBV:getRight()/2 * foldedFraction(entity)
         local hL = entBV:getForward()/2
         local maxDim = math.max (hW, hL)
        -- Find the distance of the entity center from the segment
         local entLoc = entity:getLocation3D()
         local entVec = startPt:vectorToLoc3D(entLoc)
         local distanceAlong = segDir:dotVector3D(entVec)
         local centerDist = math.abs(segDir:crossVector3D(entVec):getRange())
         
         if centerDist < maxDim + myHalfWidth and -- Prune those too far from line
            distanceAlong > 0 and -- Prune those behind plane
            -- Prune those beyond segment end point
            distanceAlong - maxDim < 
               startPt:distanceToLocation3D(endPt) + myHalfLength 
            then
            
            -- Given the rotation of the entity bounding box
            -- relative to the segment, find how far from its
            -- center it extends toward the segment.
            local entDir = entity:getDirection3D()
            local cosEntity = math.abs(segDir:dotVector3D(entDir))
            local sinEntity = math.sqrt(1 - cosEntity * cosEntity)
            local netWidthToSeg = hL * sinEntity + hW * cosEntity
            
            local netDist = centerDist - netWidthToSeg
            if netDist < myHalfWidth then
               if DEBUG then
                  printWarn("Blocked by ", entity:getName())
                  printWarn("  Dist to segment: ", centerDist, 
                     ", dist along seg: ", distanceAlong)
                  printWarn("  Entity width toward segment ", netWidthToSeg)
               end
               return entity
            end
         end
      end
   end
   return nil
end

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
   vrf:executeSetData("set-speed", {speed = flyingSpeed})
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
