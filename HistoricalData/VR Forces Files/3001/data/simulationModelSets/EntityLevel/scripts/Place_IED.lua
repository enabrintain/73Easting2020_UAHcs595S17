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

-- Tasks an entity to move to a location, place an IED and then move to another 
-- location. The user can choose between an immediate, timed or proximity fuse. 
-- The timeDelay parameter only affects a timed fuse and the proximity parameter
-- only affects a proximity fuse. The user can choose an armLocation which is 
-- either at the placement point or the post placement point. Note that 
-- immediate or proximity fuses can potentially destroy the entity placing the 
-- IED if armed at the placement point or if the post placement point is not far 
-- enough away. 

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables, which are saved/restored with a scenario checkpoint.

myState = "movingToPlacementLocation"
moveToPlacementLocationSubtaskId = -1
moveToPostPlacementLocationSubtaskId = -1
placeStartTime = -1
placeFinishTime = -1
fuseType = -1
timeDelay = 0
proximity = 0
armLocation = "arm at post placement location"

-- Called once when the task first starts.
function init()
   -- translate the fuse type from the parameter to the value expected by the
   -- set detonate command (as defined in VR-Link's disEnums.h)
   if (taskParameters.fuseType == 0) then
      -- immediate fuse
      fuseType = 4000
   elseif (taskParameters.fuseType == 1) then
      -- timed fuse, apply time delay parameter as well
      fuseType = 2000
      timeDelay = taskParameters.timeDelay      
   elseif (taskParameters.fuseType == 2) then
      -- proximity fuse, apply the proximity parameter as well
      fuseType = 3000
      proximity = taskParameters.proximity
   end

   -- read out the armLocation parameter which determines when armIED() gets
   -- called
   if (taskParameters.armLocation == 0) then
      armLocation = "arm at placement location"
   elseif (taskParameters.armLocation == 1) then
      armLocation = "arm at post placement location"
   end
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

function moveToPlacementLocation()
   if (moveToPlacementLocationSubtaskId < 0) then	 
      moveToPlacementLocationSubtaskId = vrf:startSubtask(
         "move-to-location-task", 
         {aiming_point=taskParameters.placementLocation})
   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(moveToPlacementLocationSubtaskId)) then
      moveToPlacementLocationSubtaskId = -1;
      return true;
   end

   return false
end

function placeIED()
   if (placeStartTime < 0) then
      -- set start & finish times baced on the user specified placementDuration
      placeStartTime = vrf:getExerciseTime()
      placeFinishTime = placeStartTime + taskParameters.placementDuration
      print("starting IED placement at ", placeStartTime, " will finish at ",
         placeFinishTime)
      -- change the posture to kneeling
      vrf:sendSetData(this, "set-lifeform-posture", 
         {lifeform_posture="kneeling"})
      -- create the IED, this is global so it can be referenced from armIED()
      ied = vrf:createEntity({entity_type="2:2:0:3:1:1:0",
         location=this:getLocation3D()})
   end
   -- wait until the finish time
   if (vrf:getExerciseTime() > placeFinishTime) then
      -- if the user said to arm at the placement location, go ahead & do it
      if (armLocation == "arm at placement location") then
         armIED()
      end
      -- return to standing posture
      vrf:sendSetData(this, "set-lifeform-posture", 
         {lifeform_posture="standing"})
      -- done, allow tick to transition to the next state
      return true
   end

   return false
end

function armIED()
   print("arming IED")
   -- issue a set detonate command
   vrf:sendSetData(ied, "set-detonate", {fuse_type=fuseType, 
      detonation_time=timeDelay, detonation_proximity=proximity})
end

function moveToPostPlacementLocation()
   if (moveToPostPlacementLocationSubtaskId < 0) then
      moveToPostPlacementLocationSubtaskId = 
         vrf:startSubtask("move-to-location-task", 
         {aiming_point=taskParameters.postPlacementLocation})
   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(moveToPostPlacementLocationSubtaskId)) then
      moveToPostPlacementLocationSubtaskId = -1;
      return true;
   end
   
   return false
end

-- Called each tick while this task is active.
function tick()
   if (myState == "movingToPlacementLocation") then
      if (moveToPlacementLocation()) then
         myState = "placingIED"
      end
   end
   
   if (myState == "placingIED") then
      if (placeIED()) then
         myState = "movingToPostPlacementLocation"
      end
   end
   
   if (myState == "movingToPostPlacementLocation") then
      if (moveToPostPlacementLocation()) then
         myState = "inPostPlacementLocation"
      end
   end
   
   if (myState == "inPostPlacementLocation") then
      -- check if the user used the default of arming at post placement location
      if (armLocation == "arm at post placement location") then
         armIED()
      end
      vrf:endTask(true)
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
