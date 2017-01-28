-- This script replaces the old plan and move to functionality
-- last Update: 12/21/2012

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
mySubtaskId = -1

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(1.0)
end

-- Called each tick while this task is active.
function tick()
   local waypoint = taskParameters.destination
   if (waypoint:isValid()) then
      if (mySubtaskId < 0) then
         -- no task yet, so lets store the waypoint location from the start
         myStoredLocation = waypoint:getLocation3D()
         mySubtaskId = vrf:startSubtask(
            "move-to-location-path-plan", { destination=myStoredLocation })
      elseif (not vrf:isSubtaskRunning(mySubtaskId)) then
         if (vrf:isSubtaskComplete(mySubtaskId)) then
            if (vrf:subtaskResult(mySubtaskId)) then
               vrf:endTask(true)
            else
               errorExit("Subtask completed with a fail state.")
            end
	 else
	    errorExit("Subtask is not running and was not completed.")
         end
      else
         -- subtask is running, let's check to see if the waypoint has moved
         if (not(myStoredLocation == waypoint:getLocation3D())) then
            --cancel the subtask, and reset mySubtaskId so the task will get reinitialized next tick
            vrf:stopSubtask(mySubtaskId)
            mySubtaskId = -1
         end
      end
   else
      errorExit("Waypoint is not valid.")
   end
end

-- when called, this task will exit and clean up accordingly. This is to be called when an error state exists
function errorExit(message)
   print("Move to Waypoint (Plan Path): " .. message .. "\n")
   mySubtaskId = -1
   myState = "start"
   mySearchRadius = 30
   vrf:endTask(false)
end

