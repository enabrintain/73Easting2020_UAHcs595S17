-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
detonationOccured = false
detonationLocation = Location3D(0,0,0)
munitionType = ""
runSubtaskId = -1

-- Task Parameters Available in Script
--  taskParameters.DetonationRange Type: Real Unit: meters - Detonations within this range cause the entity to flee
--  taskParameters.MunitionType Type: String Entity Type - The type of munition detonation the entity will run from


-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
   
   detonationOccured = false
   
   -- Register our interest in knowing about detonations within our range
   this:registerDetonationInterest(taskParameters.DetonationRange, taskParameters.MunitionType)
   
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   
   -- Check if a detonation occurred and store its munition type and location
   detonationOccured, munitionType, detonationLocation =
      this:getLastDetonation()
   
   return detonationOccured
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   detonationOccured = false
end

-- Called each tick while this task is active.
function tick()

   if(runSubtaskId == -1) then
   
      -- Flee least 100 meters farther than our detonation detection range
      local fleeRange = taskParameters.DetonationRange + 50
      
      detonationObj = nil
      
      -- If we are not the first to react to the explosion, an object for it may exist.
      local nearbyObjects = vrf:getSimObjectsNear(detonationLocation, 1)
      
      if( nearbyObjects ) then
         for entityNum,entity in pairs(nearbyObjects) do
            if(entity:getEntityType() == "16:1:0:0:0:0:0") then
	       -- Found the detonation object
	       detonationObj = entity
	    end
         end
      end
      
      if(not detonationObj) then
	 -- We are the first to react. Create an object to run from.
         detonationObj = vrf:createWaypoint(
            {entity_type="16:1:0:0:0:0:0", location=detonationLocation})
      end
      
      -- Run!
      local fleeFromTable = { detonationObj }
      runSubtaskId  = vrf:startSubtask("flee", 
         {fleeFrom=fleeFromTable, radius=fleeRange, stopWhenHidden=false})
   end
   
   if(vrf:isSubtaskComplete(runSubtaskId)) then      
      -- Ok, I think we're safe, stop running.
      runSubtaskId = -1
      
      -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
      -- Wrap it in an appropriate test for completion of the task.
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
