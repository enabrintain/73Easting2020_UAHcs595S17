-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.sweep_route Type: SimObject
--  taskParameters.sense_range Type: Real Unit: meters
--  taskParameters.miss_chance Type: Real - Error rate between 0 and 1 that if a mine is sensed it will not be deactivated

mySubtaskId = -1
myAlreadyChecked = {}

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   if (mySubtaskId == -1) then
      -- Ignore us when doing proximity check
	  table.insert(myAlreadyChecked, this)
      mySubtaskId = vrf:startSubtask("move-along", {route=taskParameters.sweep_route})
   elseif (vrf:isSubtaskComplete(mySubtaskId)) then
      vrf:endTask(true)
   else
      results = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), taskParameters.sense_range, {types={"2:6:-1:3:-1:-1:-1"}, ignore=myAlreadyChecked})
      for i,v in ipairs(results) do
         if (v:getLocation3D():getAlt() <= 2) then
	    table.insert(myAlreadyChecked, v)
	    if (math.random() >= taskParameters.miss_chance / 100) then
	       vrf:sendSetData(v, "set-armed", {armed=false})
	       vrf:deleteObject(v)
	    end
	 end
      end
   end
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
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
