-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Task Parameters Available in Script
--  taskParameters.targetLocation Type: Location3D - Click on map for target location
--  taskParameters.durationRapid Type: Integer Unit: seconds - Time that weapon is fired at rapid rate
--  taskParameters.durationTotal Type: Integer Unit: seconds - Total time that suppressive fire will be provided.
--  taskParameters.ammoLimit Type: Integer - Max number of rounds entity should shoot.
--  taskParameters.useGun Type: String (weapon name) - Select which gun on the entity to use for suppressive fire.

taskId = -1

function init()
   taskId = vrf:startSubtask("Provide_Suppressive_Fire", 
      {targetLocation = taskParameters.targetLocation,
      durationRapid = taskParameters.durationRapid,
      durationTotal = taskParameters.durationTotal,
      ammoLimit = taskParameters.ammoLimit,
      useGun = taskParameters.useGun})
   if taskId == -1 then 
      vrf:endTask(false)
   end
end

-- Called each tick while this task is active.
function tick()
   if taskId == -1 then
      vrf:endTask(false)
   elseif not vrf:isTaskRunning(taskId) then
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
