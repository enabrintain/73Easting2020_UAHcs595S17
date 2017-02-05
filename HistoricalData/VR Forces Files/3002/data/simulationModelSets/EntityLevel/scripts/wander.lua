-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
taskId = -1
job = nil

startTime = 0
wanderRadius = 100.0

-- Task Parameters Available in Script
-- taskParameters.coverFrom Type: Location3D

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   startTime = vrf:getSimulationTime()
end

-- Called each tick while this task is active.
function tick()
   if (taskParameters.isIndefinite == 1) then
      local timeDiff = vrf:getSimulationTime() - startTime
      if (timeDiff > taskParameters.wanderTime) then
         vrf:endTask(true)
      end
   end

   if (job) then
      -- check job
      local points,index,message = job:getObject()
      if (index == 1) then
         if (#points > 0) then 
            taskId = vrf:startSubtask("move-to-location", {aiming_point=points[1]})
	    
	 else
	    printWarn("generate points job failed: " .. message)
	    vrf:endTask(false)
	end
         job = nil
         return
      end

      -- print out any messages from the algorithm
      if (message and message ~= "" and message ~= lastMessage) then
         printDebug("generate points job: " .. message)
      end

      lastMessage = message

      if (index == 0) then    
         return
      end
   end
   
   if (taskId == -1) then
      local found = false
      local parent = 0
      if this:isEmbarked() then
         parent = this:getEmbarkedOn()
      end
      local bounds = 0
      if (taskParameters.movementMode == 1 and taskParameters.area:isValid()) then
         bounds = taskParameters.area
      end

      job = vrf:generateRandomPoints({
         access_point=this:getLocation3D(), 
         boundary=bounds, 
         max_distance_from_start=wanderRadius,
         parent_object=parent})         
      if (not job) then
         printWarn(vrf:trUtf8("Could not start async job"))
         vrf:endTask(false)
         return
      end
   elseif (vrf:isSubtaskComplete(taskId)) then
      taskId = -1
   end
end


-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
-- By default, halt all subtasks and other entity tasks started by this task when suspending.
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
   
   job = nil
   taskId = -1
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
