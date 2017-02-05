-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- distance destination object has to move before subtask is reissued
checkDistance = 0.5

-- location destination was at when move task was started
lastLocation = nil

-- movement subtask
subTask = nil

-- old name, if it's there this is an old scenario
obstacleQuery = taskParameters.obstacleQuery
if (taskParameters.query ~= "") then
   obstacleQuery = taskParameters.query
end

-- Task Parameters Available in Script
--  taskParameters.destinationObject Type: SimObject
--  taskParameters.featureType Type: String
--  taskParameters.buffer Type: Real

destinationObject = taskParameters.destinationObject

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   if (subTask ~= nil) then
      vrf:stopSubtask(subTask)
      subTask = nil
   end
   
   if (not destinationObject:isValid()) then
      printWarn(vrf:trUtf8("Invalid destination object"))
      vrf:endTask(false)
      return
   end
   
   lastLocation = destinationObject:getLocation3D()
   
   local params = {
     obstacleQuery=obstacleQuery,   
     pathQuery=taskParameters.pathQuery,  
     destination=lastLocation,
     buffer=taskParameters.buffer,
     displayRoute=taskParameters.displayRoute }

   subTask = vrf:startSubtask("navigate-to-location", params)
end

-- Called each tick while this task is active.
function tick()
   -- check to make sure destination object is still valid
   if (not destinationObject:isValid()) then
      printInfo(vrf:trUtf8("Destination object has become invalid"))
      vrf:endTask(false)
      return
   end

   -- check to see if destination object has moved enough to reissue subtask
   local newLocation = destinationObject:getLocation3D()
   if (not lastLocation:isNearLocation3D(newLocation, checkDistance)) then
      init()
      return
   end
   
   -- check to see if subtask has completed
   if (not vrf:isSubtaskRunning(subTask)) then
      vrf:endTask(vrf:subtaskResult(subTask))
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
