-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
state = "unticked"
selected_ee = ""
sar_task_id = -1
recover_task_id = -1

-- Task Parameters Available in Script
--  taskParameters.divertEnabled Type: Bool (on/off) - Enables this task to divert a deployed embedded entity from it's current task if necessary.
--  taskParameters.recoverOnComplete Type: Bool (on/off) - Enabling makes this task wait for completion of the SAR task then issue a RTB order.
--  taskParameters.csp Type: Location3D - Centerpoint of the SAR pattern.
--  taskParameters.leg Type: Real Unit: meters - length of trackline
--  taskParameters.altitude Type: Real Unit: meters - Search altitude
--  taskParameters.airSpeed Type: Real Unit: meters/second - Speed of search


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

function selectEmbeddedEntity()
   local capable_ees = this:getEmbeddedEntitiesCapableOf("SAR_Sector_Search")
   
   if next(capable_ees) == nil then
      printInfo("No entities capable of task.")
      return ""
   end
   
   for i,name in ipairs(capable_ees) do
      if this:getEmbeddedEntityStatus(name) == "recovered" then
         return name
      end
   end
   
   if not taskParameters.divertEnabled then
      printInfo("No capable entities are available for task.")
      return ""
   end
   
   for i,name in ipairs(capable_ees) do
      if this:getEmbeddedEntityStatus(name) == "deployed" then
         printInfo("Entity '"..name.."' will be diverted.")
         return name
      end
   end
   
   printInfo("No capable entities alive to divert.")
   return ""
   
end

-- Called each tick while this task is active.
function tick()
   if state == "unticked" then
      selected_ee = selectEmbeddedEntity()
      if selected_ee == "" then
         printWarn("Unable to select an appropriate embedded entity.")
         vrf:endTask(false)
      return
      end
      sar_task_id = vrf:sendEmbeddedEntityTask(selected_ee,
         "SAR_Sector_Search", {csp = taskParameters.csp,
                               leg = taskParameters.leg,
                               altitude = taskParameters.altitude,
                               airSpeed = taskParameters.airSpeed},
         taskParameters.recoverOnComplete)
      state = "deploying"
      return
   end
   
   if state == "deploying" then
      if not (this:getEmbeddedEntityStatus(selected_ee) == "deployed") then
         return
      end
      state = "waiting"
      -- While  vrf:sendEmbeddedEntitySet() is provided, it should not be used unless absolutely necessary, as the
      -- Embedded Entity Controller is only capable of maintaining one tracked task per Embedded Entity.  Because
      -- vrf:sendEmbeddedEntitySet() encapsulates a task that ensure the Embedded Entity is deployed it would
      -- cancel the SAR_Sector_Search we sent above.  See the Lua documentation for details.
      vrf:sendSetData(this:getSimObjectByEmbeddedEntityName(selected_ee), "set-reactive-task-enabled",
         {script_id = "Bingo_Fuel_Monitor", parameters = {
         parent = this,
         eeName = selected_ee,
         fuelEcon = 1,
         bingo = 50,
         joker = 52}})
	 
      -- Enable spot reporting on the SAR entity, so that it sends spot reports on anything it finds
      -- back to this (the launching) entity.
      vrf:sendSetData(this:getSimObjectByEmbeddedEntityName(selected_ee), "set-spot-reporting-request",
         { spot_reporting_turned_on = 2, use_global_receivers = false, spot_reporting_receivers = { this }})
      return
   end

   if state == "waiting" then
      if vrf:isTaskRunning(sar_task_id) then
         return
      end
      if taskParameters.recoverOnComplete then
         recover_task_id = vrf:startSubtask("recover-embedded-entity", { embeddedEntityName = selected_ee})
         state = "recovering"
         return
      end
      vrf:endTask(vrf:taskResult(sar_task_id))
      return
   end
   
   if state == "recovering" and not vrf:isTaskRunning(recover_task_id) then
      vrf:endTask(vrf:taskResult(recover_task_id))
      return
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
