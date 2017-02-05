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
-- This task breaks the subordinates of an aggregate randomly into two groups, and moves the aggregate
-- one group at a time toward the destination.  
-- The group that is not moving crouches down and puts their weapon in firing position, while facing the heading
-- specified by the user.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Table of currently moving subordinates and the taskIds of their tasks.
movingSubs = {}
-- Table of subordinate names mapped to their initial offsets from the aggregate location.
subOffsets = {}
group1 = {} -- List of subordinates in group 1
group2 = {} -- List of subordinates in group 2
currentSubGoal = nil
currentSubGoalIsFinal = false

-- States are:
--  starting:  First initialization of task
--  move-group-1:  Group 1 is moving
--  move-group-2:  Group 2 is moving
myState = "starting"

-- Tasks a single subordinate to move to the new destination, with the specified offset.
function taskSubToMove(subordinate, destination, offset)
   destination = destination:addVector3D(offset);
   -- ground clamp the destination
   altitude = vrf:getTerrainAltitude(destination:getLat(), destination:getLon())
   destination:setAlt(altitude)
   local taskId = vrf:sendTask(subordinate, "move-to-location-task", {aiming_point = destination})
   vrf:sendSetData(subordinate, "set-lifeform-posture", {lifeform_posture = "standing"})
   vrf:sendSetData(subordinate, "set-lifeform-weapon-state", {lifeform_weapon_state = "weapon-deployed"})
   vrf:sendSetData(subordinate, "set-speed", {speed = taskParameters.speed})
   movingSubs[subordinate] = taskId;
end

-- Sets the appropriate attributes of a single subordinate when in the guarding mode.
function setSubToGuard(sub)
   vrf:sendSetData(sub, "set-lifeform-posture", {lifeform_posture = "kneeling"})
   vrf:sendSetData(sub, "set-lifeform-weapon-state", {lifeform_weapon_state = "weapon-in-fire-position"})
   vrf:sendSetData(sub, "set-heading", {heading = taskParameters.threatDirection})
end

-- Finds the next subgoal from startLoc to finalLoc, and returns that location.
-- Also returns true/false as a second value, indicating if this is the final location.
function findSubgoal(startLoc, finalLoc)
   local maxBoundDist = taskParameters.overwatchDistance
   local startToEnd = startLoc:vectorToLoc3D(finalLoc)
   if (startToEnd:getRange() <= maxBoundDist) then return finalLoc, true end -- already close enough, no subgoal needed.
   startToEnd:setBearingInclRange(startToEnd:getBearing(), 0, maxBoundDist);
   return startLoc:addVector3D(startToEnd), false;
end

-- Tasks the group specified to move to the destination specified.
function taskGroupToMove(group, destination)
   for i, sub in ipairs(group) do
      print("Tasking: ", sub:getName())
      taskSubToMove(sub, destination, subOffsets[sub:getName()])
   end
end

-- Starts group-1 moving.
function startMoveLeg()
   currentSubGoal, currentSubGoalIsFinal = findSubgoal(this:getLocation3D(), taskParameters.destination:getLocation3D())
   myState = "move-group-1"
   taskGroupToMove(group1, currentSubGoal);
end

function init()
   vrf:setTickPeriod(0.5)
   -- Record the subordinate distances from the aggregate center, to record the current formation.
   local subordinates = this:getSubordinates();
   
   if (#subordinates < 1) then
      vrf:endTask(false)
      return;
   end
   
   -- Record the initial offsets of the subordinates, and split them into two groups.
   for i,sub in ipairs(subordinates) do
      local subLocation = sub:getLocation3D()
      local offset = this:getLocation3D():vectorToLoc3D(subLocation)
      subOffsets[sub:getName()] = offset;      
      if (i > #subordinates / 2) then 
         table.insert(group2, sub)
      else
         table.insert(group1, sub)
      end
   end
   
   startMoveLeg()
   for i, sub in ipairs(group2) do
      setSubToGuard(sub)
   end
end

-- Checks the status of moving subordinates, and returns the count of subordinates that are still moving.
-- Additionally, this call will check to see if a subordinate has been killed, and removes it from the group if so.
function checkSubordinateTasks()
   local activeSubsCount = 0;
   for sub, taskId in pairs(movingSubs) do
      if (sub:isDestroyed()) then
         movingSubs[sub] = nil;
      end
      
      if (vrf:isTaskComplete(taskId)) then
         setSubToGuard(sub)
         
         -- remove the subordinate from the table it has completed its task
         movingSubs[sub] = nil
      else
         activeSubsCount = activeSubsCount + 1
      end
   end
   return activeSubsCount
end

function tick()
   if (checkSubordinateTasks() == 0) then
      if (myState == "move-group-1") then
         myState = "move-group-2"
         taskGroupToMove(group2, currentSubGoal)
      else
         if (currentSubGoalIsFinal) then
            vrf:endTask(true)
         else
            startMoveLeg();
         end
      end
   end
end





























































