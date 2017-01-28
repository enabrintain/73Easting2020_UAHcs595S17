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

taskId = -1
setLoc = nil

if taskParameters.fix:isValid() then
   location = taskParameters.fix:getLocation3D()
   offset = Vector3D(0, 0, 0)
   offset:setBearingInclRange(taskParameters.bearing,
       0, taskParameters.range)
   setLoc = location:addVector3D(offset)
   setLoc:setAlt(taskParameters.altitude)
else
   vrf:endTask(false)
end

-- Called when the task first starts. Never called again.
function init()
   if setLoc ~= nil then
      taskId = vrf:startSubtask("move-to-location", {aiming_point = setLoc})
   end
end

-- Called each tick while this task is active.
function tick()
   if not vrf:isSubtaskRunning(taskId) then
      vrf:endTask(true)
      return
   else
      local currentFixLoc = taskParameters.fix:getLocation3D()
      if currentFixLoc:distanceToLocation3D(location) > 1.0 then
         setLoc = currentFixLoc:addVector3D(offset)
         setLoc:setAlt(taskParameters.altitude)
         vrf:stopSubtask(taskId)
         taskId = vrf:startSubtask("move-to-location", {aiming_point = setLoc})
         location = currentFixLoc
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
