--
-- Copyright (c) 2012 MAK Technologies, Inc.
-- All rights reserved.
--
-- This is an experimental VR-Forces Lua task. It has been created to provide some basic example functionality 
-- that you can test, copy, use as-is, or modify to achieve your goals. It is not tested as part of the VR-Forces
-- standard task regression procedure and should be considered complete as is. We are happy to receive bug fixes and 
-- suggestions on ways to improve it via email to support@mak.com, Additionally will be happy to consider injecting any 
-- improvements or additional scripts which you may send to us. 
--

--Move to a location, sets sonar mode and sonar depth, and waits for the specified amount of time.
--Then the entity retracts its sonar and completes the task.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables, which are saved/restored with a scenario checkpoint.

--states:
--	movingToLocation
--	waiting

myState = "movingToLocation"
moveToLocationSubtaskId = -1
waitSubtaskId = -1
activeSonarMode="first-enabled-mode"

-- Called once when the task first starts.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   if (taskParameters.sonarType == 1) then
      activeSonarMode="off"
   end
end

function moveToLocation()
   if (moveToLocationSubtaskId < 0) then
      moveToLocationSubtaskId = vrf:startSubtask(
         "move-to-location-task", 
         {aiming_point=taskParameters.location})
   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(moveToLocationSubtaskId)) then
      moveToLocationSubtaskId = -1
      return true;
   end

   return false
end

function performSonarDip()
   if (waitSubtaskId < 0) then
      waitSubtaskId = vrf:startSubtask("wait-duration", 
	{seconds_to_wait=taskParameters.duration})
      vrf:executeSetData("set-sonar-depth", {depth=taskParameters.sonarDepth, use_entity_depth=false})
      vrf:executeSetData("set-active-sonar-sensor-mode", {active_sonar_sensor_mode=activeSonarMode})
   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(waitSubtaskId)) then
      waitSubtaskId=-1
      vrf:executeSetData("set-sonar-depth", {depth=0, use_entity_depth=true})
      vrf:executeSetData("set-active-sonar-sensor-mode", {active_sonar_sensor_mode="off"})
      return true;
   end

   return false
end

-- Called each tick while this task is active.
function tick()
   if (myState == "movingToLocation") then
      if (moveToLocation()) then
         myState = "waiting"
      end
   end
   
   if (myState == "waiting") then
      if (performSonarDip()) then
         vrf:endTask(true)
      end
   end
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
