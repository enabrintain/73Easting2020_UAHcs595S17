-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.fleeFrom Type: SimObjects
--  taskParameters.radius Type: Real Unit: meters
--  taskParameters.stopWhenHidden Type: Bool (on/off)

-- Globals
mySubordinateTasks = {}

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)

   if (not this:isDisaggregatedUnit()) then
      printWarn("This task is only available to disaggregated units")
      vrf:endTask(false)
   else
      local currentSubordinates = this:getSubordinates()
      for subIndex, subordinate in pairs(currentSubordinates) do
         if (subordinate:isDisaggregatedUnit()) then
            mySubordinateTasks[subordinate:getUUID()] = vrf:sendTask(subordinate, 
		       "disaggregate_flee", {fleeFrom = taskParameters.fleeFrom, radius = taskParameters.radius, stopWhenHidden = taskParameters.stopWhenHidden})
         else
            mySubordinateTasks[subordinate:getUUID()] = vrf:sendTask(subordinate, 
		       "flee", {fleeFrom = taskParameters.fleeFrom, radius = taskParameters.radius, stopWhenHidden = taskParameters.stopWhenHidden})
	end
      end
   end
end

-- Checks the status of the subordinates to see if the still exist and are still in task mode.  If not then the subordinates are removed from
-- the mySubordinatesList.  Once the list is empty the the task is complete
function allSubordinatesComplete()
   local currentSubordinates = this:getSubordinates()
   local currentTable = mySubordinateTasks
   local complete = true
   
   mySubordinateTasks = {}
   for subIndex, subordinate in pairs(currentSubordinates) do
      local taskId = currentTable[subordinate:getUUID()]
      if (taskId ~= nil) then
         if (not vrf:isTaskComplete(taskId)) then
	    mySubordinateTasks[subordinate:getUUID()] = taskId
	    complete = false
	 end
      end      
   end
   
   return complete
end

-- Called each tick while this task is active.
function tick()
   if (allSubordinatesComplete()) then
      vrf:endTask(true)
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
