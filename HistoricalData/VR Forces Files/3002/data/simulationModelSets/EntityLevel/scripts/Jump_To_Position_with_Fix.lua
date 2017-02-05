-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.fix Type: SimObject - The reference point
--  taskParameters.bearing Type: Real Unit: radian - The bearing from the fix of the desired postion.
--  taskParameters.range Type: Real Unit: meters - The distance from the fix of the desired position.
--  taskParameters.altitude Type: Real Unit: meters - The altitude of the desired position

if taskParameters.fix:isValid() then
   location = taskParameters.fix:getLocation3D()
   offset = Vector3D(0, 0, 0)
   offset:setBearingInclRange(taskParameters.bearing,
       0, taskParameters.range)
   setLoc = location:addVector3D(offset)
   setLoc:setAlt(taskParameters.altitude)
   vrf:executeSetData("set-location", {location = setLoc})
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:endTask(true)
end

-- Called each tick while this task is active.
function tick()

   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   vrf:endTask(true)

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
