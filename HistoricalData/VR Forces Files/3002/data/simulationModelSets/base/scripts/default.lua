-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- TASK PARAMETERS (VRF TEAM DO NOT ERASE)
-- REACTIVE TASK FUNCTIONS START (VRF TEAM DO NOT MODIFY OR ERASE)
-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   -- Returning true will cause the reactive task to become active and will call init()
   -- and tick() until the task completes.
   return false
end
-- REACTIVE TASK FUNCTIONS END (VRF TEAM DO NOT MODIFY OR ERASE)
-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
-- REMOVE IF BACKGROUND PROCESS BEGIN (VRF TEAM DO NOT ERASE)
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   vrf:endTask(true)
-- REMOVE IF BACKGROUND PROCESS END (VRF TEAM DO NOT ERASE)
end

-- REMOVE IF BACKGROUND PROCESS BEGIN (VRF TEAM DO NOT ERASE)
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
-- REMOVE IF BACKGROUND PROCESS END (VRF TEAM DO NOT ERASE)
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

-- REMOVE IF BACKGROUND PROCESS BEGIN (VRF TEAM DO NOT ERASE)
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
-- REMOVE IF BACKGROUND PROCESS END (VRF TEAM DO NOT ERASE)

-- REACTIVE TASK FUNCTIONS START (VRF TEAM DO NOT MODIFY OR ERASE)
-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
-- REACTIVE TASK FUNCTIONS END (VRF TEAM DO NOT MODIFY OR ERASE)
