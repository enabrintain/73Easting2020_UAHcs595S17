-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Current fuel state , denoting ranges rather than fenceposts:
--    'tiger' - all good/more than the joker parameter
--    'joker' - less than joker parameter but more than bingo
--    'bingo' - less than the bingo parameter
state = "tiger"
last_estimate = "tiger"
-- Number of ticks that the state estimate has returned the same state
ticks_stable = 0

-- Task Id for RTB operations
rtb_tid = -1

-- Number of ticks estimations must remain stable for a state change
local required_stable_ticks = 5


-- Task Parameters Available in Script
--  taskParameters.parent Type: Simulation Object - This Embedded Entity's parent object name.  (The unit that can recover it.)
--  taskParameters.eeName Type: String - This Embedded Entity's embedded entity name - basically how the parent addresses it within the context of the Embedded Entity system.
--  taskParameters.fuelEcon Type: Real - Km traveled per unit fuel.  Usually 1.
--  taskParameters.bingo Type: Real - The fuel safety margin to add to usage estimates before RTB.
--  taskParameters.joker Type: Real - As with bingo fuel but for status messaging.  Will be ignored if not greater than bingo fuel.
--  taskParameters.reactivetask_priority Type: Integer
--  taskParameters.reactivetask_enabled Type: Bool (on/off) 

function paramsValid()
   -- Ideally we'd also check eeName from here, but there's no way to do so.
   return taskParameters.parent:isValid()
end

function distToParentInKm()
   local myLoc = this:getLocation3D()
   local parLoc = taskParameters.parent:getLocation3D()
   
   return  myLoc:distanceToLocation3D(parLoc) / 1000
end

function estimateRtbFuel()
   return distToParentInKm() / taskParameters.fuelEcon
end

function remainingFuel()
   current, full = this:getResourceAmounts("movement|fuel")
   return current
end

function estimateFuelState()
   local remain = remainingFuel()
   local needed = estimateRtbFuel()
   
   if needed + taskParameters.bingo > remain then
      return "bingo"
   end
   if needed + taskParameters.joker > remain then
      return "joker"
   end
   return "tiger"
end

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()

   if not paramsValid() then
      printWarn("Unable to continue monitoring fuel use...")
      vrf:executeSetData("set-reactive-task-disabled", {script_id = "Bingo_Fuel_Monitor", cancel_now = true})
      return false
   end
   
   local estimate = estimateFuelState()
   
   if estimate ~= last_estimate then
      last_estimate = estimate
      ticks_stable = 0
      return false
   end
   
   ticks_stable = ticks_stable + 1
   
   if estimate == state then
      return false
   end
   
   if ticks_stable < required_stable_ticks then
      return false
   end
      
   -- Finally we're down to the actual state transitions.
   state = estimate
   if state == "tiger" then
      printInfo("Detected fuel resource reset.")
      return false
   end
   if state == "joker" then
      printWarn("Reached Joker fuel condition.")
      return false
   end
   if state == "bingo" then
      printWarn("Reached Bingo fuel condition, returning to base")
      return true
   end
   
   -- Returning true will cause the reactive task to become active and will call init()
   -- and tick() until the task completes.
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   if not (state == "bingo") then
      printWarn("This reactive task should not be called directly.")
      vrf:endTask(false)
      return
   end

   if rtb_tid < 0 then
      local parent = taskParameters.parent
      printInfo("Recovering '"..taskParameters.eeName.."'.")
      rtb_tid = vrf:sendTask(parent, "recover-embedded-entity", {embeddedEntityName = taskParameters.eeName}, true)
   end
   
   if not vrf:isTaskRunning(rtb_tid) then
      vrf:endTask(vrf:taskResult(rtb_tid))
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
