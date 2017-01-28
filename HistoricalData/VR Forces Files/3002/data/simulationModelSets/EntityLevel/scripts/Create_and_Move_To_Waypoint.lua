--
-- Copyright (c) 2012 MAK Technologies, Inc.
-- All rights reserved.
--

-- This is a basic demonstration script which is intended to be a starting point
-- for users who are new to scripting with Lua. It demonstrates waypoint
-- creation, a set and a task.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables, which are saved/restored with a scenario checkpoint.

-- This will be set in tick() when the subtask to move to the waypoint is 
-- created. Tick will check this subtaskId and when it is complete, endTask()
-- will be called.
moveToWaypointSubtaskId = -1

-- Called once when the task first starts.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   -- Create the waypoint that the user specified
   -- waypoint is declared as a global variable so that it can be deleted by
   -- the shutdown() function below. The location is taken from the task 
   -- parameters and the force is set using the this pointer so that it gets the
   -- same force type as the entity which is executing the script.
   waypoint = vrf:createWaypoint({location=taskParameters.waypointLocation, 
      force=this:getForceType()})
      
   -- Set the speed that the user specified to be the ordered speed for the
   -- entity. The "this" parameter specifies that the set should be sent to
   -- the entity which is executing this script, also known as the ownship.
   vrf:sendSetData(this, "set-speed", {speed=taskParameters.orderedSpeed})
end

-- Called each tick while this task is active.
function tick()
   -- if the subtaskId is still at its default value of -1, the subtask has not
   -- yet been assigned.
   if moveToWaypointSubtaskId == -1 then
      -- Use startSubtask to assign the move-to task, passing in the name of the
      -- waypoint created in init(). The return value is the subtask ID and that
      -- will be stored in moveToWaypointSubtaskId in order to check it for
      -- completion in future calls to tick().
      moveToWaypointSubtaskId = vrf:startSubtask("move-to", 
         {control_point=waypoint})
   end
   
   -- If the move to waypoint subtask is completed, then call endTask to end
   -- the script
   if vrf:isSubtaskComplete(moveToWaypointSubtaskId) then
      -- Once endTask() is called, the task is inactive and tick() will not be 
      -- called again.
      vrf:endTask(true)
   end
end

-- Called when this task is ending, for any reason.
function shutdown()
   -- delete the waypoint created in init()
   vrf:deleteObject(waypoint)
end
