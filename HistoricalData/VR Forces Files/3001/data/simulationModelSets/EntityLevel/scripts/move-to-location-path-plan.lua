-- This script replaces the old plan and move to functionality
-- for vehicles only
-- last Update: 1/17/2012

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
mySearchRadius = 30 -- in meters
myMaxSearchRadius = mySearchRadius * 10
myState = "start"
mySubtaskId = -1

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   myState = "start"
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   if (myState == "start") then
      local point, dataReady, success = vrf:findClosestPointToRoad(this:getLocation3D(),mySearchRadius)
      if (dataReady) then
         if (success) then
             -- Ground clamp the point.
            altitude = vrf:getTerrainAltitude(point:getLat(), point:getLon())
            point:setAlt(altitude)
             -- Check if the distance to the road is smaller than the distance to the final destination.  If not, then just move directly. 
            if (point:distanceToLocation3D(this:getLocation3D()) < 
               this:getLocation3D():distanceToLocation3D(taskParameters.destination)) then
               
               myState = "moveToRoad"
               printDebug(string.format("%.3f Mv-loc-path-plan: Found loc on road nearby, starting move to road.",
                  vrf:getSimulationTime()))
               mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point=point })
            else
               printDebug(string.format("%.3f Mv-loc-path-plan: Road is too far out of the way. Moving directly.",
                  vrf:getSimulationTime()))
               myState = "moveToDest"
               mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point=taskParameters.destination })
            end
         else
            mySearchRadius = mySearchRadius + mySearchRadius
            if (mySearchRadius > myMaxSearchRadius) then
               printDebug(string.format("%.3f Mv-loc-path-plan: No road found. Moving directly.",
                  vrf:getSimulationTime()))
               myState = "moveToDest"
               mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point=taskParameters.destination })
            end
         end
      end
   elseif (mySubtaskId > -1) then
      if (not vrf:isSubtaskRunning(mySubtaskId)) then
         if (vrf:isSubtaskComplete(mySubtaskId)) then
            if (vrf:subtaskResult(mySubtaskId)) then
               if (myState == "moveToRoad") then
                  myState = "moveOnRoad"
                  printDebug(string.format("%.3f Mv-loc-path-plan: Starting move on road.",
                     vrf:getSimulationTime()))
                  mySubtaskId = vrf:startSubtask("rail-path-move", { destination=taskParameters.destination })
               elseif (myState == "moveOnRoad") then
                  myState = "moveToDest"
                  printDebug(string.format("%.3f Mv-loc-path-plan: Done road move; moving to final destination.",
                     vrf:getSimulationTime()))
                  mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point=taskParameters.destination })
               elseif (myState == "moveToDest") then
                  printDebug(string.format("%.3f Mv-loc-path-plan: Reached final destination.",
                     vrf:getSimulationTime()))
                  vrf:endTask(true)
               end
            else -- subtask resulted in fail
               if (myState == "moveToRoad" or myState == "moveOnRoad") then
                  myState = "moveToDest"
                  mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point=taskParameters.destination })
               else
                  errorExit("Subtask exited with failure. Exiting task.")
               end
            end -- if subtask success
      
         elseif (myState == "moveToDest") then
            errorExit("Unable to move to destination. Exiting Task.")
            
         elseif(myState == "moveToRoad" or myState == "moveOnRoad") then
            print("Road movement stopped. Moving directly.\n")
            myState = "moveToDest"
            mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point=taskParameters.destination })
         else
            errorExit("Subtask is not running. Exiting task.")
         end -- if subtask is complete
      end -- if not subtask running
   else
      errorExit("Invalid state. Exiting task.")
   end -- if start 
end 

-- when called, this task will exit and clean up accordingly. This is to be called when an error state exists.
function errorExit(message)
   printWarn("Move to Location (Plan Path): " .. message .. "\n")
   mySubtaskId = -1
   myState = "start"
   mySearchRadius = 30
   vrf:endTask(false)
end
