--
-- Copyright (c) 2012 MAK Technologies, Inc.
-- All rights reserved.
--

-- This script will look for linear features with an attribute of "name" which 
-- match the streetName task parameter. If none are found the script will 
-- terminate. Otherwise, each matching linear feature will be examined point by
-- point to find the closest point to the ownship entity. The entity will be
-- tasked to move to that point and a waypoint will be created at that location
-- to help visualize the goal in the front-end. The waypoint will be deleted
-- on shutdown.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables, which are saved/restored with a scenario checkpoint.

moveToLocationSubtaskId = -1


-- Called once when the task first starts.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   linearFeatures = vrf:getFeaturesWithinRange(this:getLocation3D(), 
      taskParameters.searchRange, {islinear=true})
end

-- Called each tick while this task is active.
function tick()
   if (moveToLocationSubtaskId < 0 and linearFeatures:isLoaded()) then
      print (linearFeatures:getFeatureCount())
      local streetFound = false
      local closestLocationSoFar
      local closestRangeSoFar = math.huge
      -- NOTE: this loop is going through all the features within range and
      -- going through all the points within the features with matching names.
      -- Especially when running in debug mode on Windows, this may cause a
      -- very long tick, which may cause problems with the entity models in the
      -- back-end and may even cause the entities to timeout in the front-end.
      -- A future version of this example may break this search up over multiple
      -- ticks, only processing a small number of features each tick.
      for I = 1, linearFeatures:getFeatureCount() do
         if taskParameters.streetName:upper() == 
            linearFeatures:getFeatureAttributeValue(I, "name"):upper() then
            streetFound = true
            local locations = linearFeatures:getLocations3D(I)
            for pointIndex, point in ipairs(locations) do
               local rangeToPoint = 
                  this:getLocation3D():distanceToLocation3D(point)
               if rangeToPoint < closestRangeSoFar then
                  closestRangeSoFar = rangeToPoint
                  closestLocationSoFar = point
               end
            end
            break
         end
      end
      if streetFound == false then
         print("Could not find a street named ", taskParameters.streetName)
         vrf:endTask(false)
      end
      waypoint = vrf:createWaypoint({location=closestLocationSoFar, 
         object_name=taskParameters.streetName, force=neutral})
      moveToLocationSubtaskId = vrf:startSubtask("plan-and-move-to-location", 
         {aiming_point=closestLocationSoFar})
   elseif vrf:isSubtaskComplete(moveToLocationSubtaskId) then
      vrf:endTask(true)
   end
end

-- Called when this task is ending, for any reason.
-- It is typically not necessary to add code to this function.
function shutdown()
   vrf:deleteObject(waypoint)
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end





























