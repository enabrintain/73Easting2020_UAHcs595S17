-- This is a task that uses the built in "Animated Movement" task in VRF, 
-- but allows specification of a reference point, orientation, and theta inclination
-- in addition to the animation movement model.
--
-- This is applicable when you have a CSV or other animation movement definition
-- that has the 0,0,0 point at some location other than the start position of the 
-- entity that is performing the action.  For example, if you have the complete
-- track of an aircraft as seen from a radar station, this task will move that aircraft
-- relative to the object that you select when issuing the task.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.animationName Type: String
--  taskParameters.referenceObject Type: SimObject
--  taskParameters.referenceHeading Type: Real Unit: radian
--  taskParameters.referenceTheta Type: Real Unit: radian


mySubtaskId = -1

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
	if (not taskParameters.referenceObject:isValid()) then
		vrf:endTask(false)
		return
	end
	
	local animationRefPoint = taskParameters.referenceObject:getLocation3D()
	mySubtaskId = vrf:startSubtask("animated-movement-task", { animation_model = taskParameters.animationName, 
		reference_heading = taskParameters.referenceHeading,
		reference_point = animationRefPoint, 
		reference_theta = taskParameters.referenceTheta,
		time_scale = 1.0 })
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   if (mySubtaskId > -1) then
      if (not vrf:isSubtaskRunning(mySubtaskId)) then
         if (vrf:isSubtaskComplete(mySubtaskId)) then
            vrf:endTask(true)
	    return
	else
	   vrf:endTask(false)
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
