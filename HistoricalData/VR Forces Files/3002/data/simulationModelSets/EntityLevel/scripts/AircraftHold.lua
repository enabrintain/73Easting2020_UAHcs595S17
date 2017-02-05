-- Copyright 2013 VT-MAK
--
-- This task approximates a standard aircraft holding pattern, using standard turns, and 1 minute legs.
-- This includes an entry into the holding pattern using one of the standard entry procedures "direct", "teardrop" or "parallel"
-- These entries are only approximate, and do not refect the actual entries in high detail.  Depending on the entry
-- angle of the aircraft, the holding pattern may take a couple of cycles before the aircraft is accurately situated on it.
--
-- This task uses the FSM module for its state machine.

FSM = require "fsm"
require "vrfutil"

-- The task ID of the subtask that is currently running, if any.
mySubtaskId = -1

-- 1 for right turn holds, -1 for left.
direction = 1

myWaitExpires = -1;

local createTaskVis = true

-- The following functions are called during state transitions in the state machine.

-- Sets the ordered speed of the aircraft to the holding speed specified in the parameters.
function setHoldSpeed()
   vrf:executeSetData("set-speed", {speed=taskParameters.speed})
end

-- Issues a subtask to fly the aircraft directly to the fix point specified in the parameters.
function flyToFix() 
   local fixLocation = taskParameters.fixPoint
   fixLocation:setAlt(taskParameters.altitude)
   mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point = fixLocation })
end

-- Issues a subtask to do a turn to the specified heading, turning in the direction specified in the parameters.
function startDirectionalTurn(targetHeading)
   mySubtaskId = vrf:startSubtask("fly-heading-task", { heading = targetHeading, turn_direction = direction });
end

-- Issues a subtask to do a turn to the specified heading, turning in the opposite direction specified in the parameters.
function startReverseTurn(targetHeading)
   mySubtaskId = vrf:startSubtask("fly-heading-task", { heading = targetHeading, turn_direction = -1 * direction });
end

-- Issues a subtask to do a turn to the specified heading, turning in whichever direction will arrive at the heading sooner.
function startNonDirectionalTurn(targetHeading)
   mySubtaskId = vrf:startSubtask("fly-heading-task", { heading = targetHeading, turn_direction = 0 });
end

-- Issues a subtask that will wait for the specified number of seconds before completing.
function startWait(duration)
   myWaitExpires = vrf:getExerciseTime() + 60
   print("starting wait at ", vrf:getExerciseTime(), " complete time: ",
      myWaitExpires);
end

-- If the hold release time has expired
function checkReleaseTime()
    if (taskParameters.releaseTime > 0 and vrf:getSimulationTime() > taskParameters.releaseTime) then
       return true
    end
    return false
end

-- Define State Transitions:
-- This is in the format { { <start-state>, <event>, <end-state>, action}, ... }
-- startup is the name of the state when the task starts.
-- The various xxx-approach events are fired based on which approach should be used right after the task starts.
-- The subtask-complete event fires every time any subtask completes.
--    This state machine is set up to operate by always running one subtask, and then sequencing those together to 
--     create the overall task behavior.
local myStateTransitionTable = {
    -- State transitions specific to the direct entry 
    {"startup", "direct-entry", "direct-approach", flyToFix},
    {"direct-approach", "subtask-complete", "prep-outbound-turn", 
	function() setHoldSpeed(); startNonDirectionalTurn(taskParameters.heading) end},
    -- State transitions specific to the teardrop entry
    {"startup", "teardrop-entry", "teardrop-approach", flyToFix},
    {"teardrop-approach", "subtask-complete", "outbound-turn", 
	function() setHoldSpeed(); startNonDirectionalTurn(taskParameters.heading + 3.14 - direction * math.rad(30)) end},
    -- State transitions specific to the parallel entry
    {"startup", "parallel-entry", "parallel-approach", flyToFix},
    {"parallel-approach", "subtask-complete", "parallel-outbound-turn", 
	function() setHoldSpeed(); startNonDirectionalTurn(taskParameters.heading + 3.14) end},
    -- State transitions for maintaining the hold after entry has been completed.
    {"parallel-outbound-turn", "subtask-complete", "parallel-outbound-leg", function() startWait(60) end},
    {"parallel-outbound-leg", "wait-complete", "inbound-turn", function() startReverseTurn(taskParameters.heading) end},
    {"prep-outbound-turn", "subtask-complete", "outbound-turn", function() startDirectionalTurn(taskParameters.heading + 3.14) end},
    {"outbound-turn", "subtask-complete", "outbound-leg", function() startWait(60) end},
    {"outbound-leg", "wait-complete", "inbound-turn", function() startDirectionalTurn(taskParameters.heading) end},
    {"inbound-turn", "subtask-complete", "inbound-leg", function() if checkReleaseTime() then vrf:endTask(true) else flyToFix() end end},
    {"inbound-leg", "subtask-complete", "prep-outbound-turn", function() startDirectionalTurn(taskParameters.heading + 3.14) end},   
    -- This entry will catch the state of a subtask failing anywhere in the state machine, and about this task.
    {"*", "subtask-failed", "task-failed", function() vrf:endTask(false) end}
}

-- Create your instance of a finite state machine
fsm = FSM.new(myStateTransitionTable)

-- Simple function for determining if testVal is between val1 and val2.
function between(testVal, val1, val2)
  if (testVal >= math.min(val1, val2) and testVal <= math.max(val1, val2)) then
     return true
  else
     return false
  end
end

function init()
   mySubtaskId = -1;
   vrf:setTickPeriod(0.5)
   
   -- Record the direction of the turns as either -1 (left) or 1 (right).
   if (taskParameters.direction == 1) then
      direction = -1
   end
     
   -- Figure out entry procedure:
   -- Entry procedure is based on the bearing from the aircraft to the fix, the direction, and also the desired turn direction.
   --   A good diagram of this is here: http://www.americanflyers.net/aviationlibrary/instrument_flying_handbook/chapter_10.htm
   --   There is an arc from the hold direction and 70 degrees to the left (for right turns) for teardrop entry.
   --    An arc from the hold direction and 110 degrees to the right (for right turns) for parallel entry.
   --    The remaining 180 degree arc uses direct entry.
   --    For left turns, the arcs are a mirror image.
   local fixPosition = taskParameters.fixPoint
   local vecFromFix = fixPosition:vectorToLoc3D(this:getLocation3D())
   local bearing = math.deg(vecFromFix:getBearing())
   bearing = bearing - math.deg(taskParameters.heading)
   
   -- Make sure the bearing is between -180 and 180
   if (bearing > 180) then
      bearing = bearing - 360
   end
   if (bearing < -180) then
      bearing = bearing + 360
   end
   
   -- Set the initial state of the FSM.
   fsm:set("startup");
   
   -- Fire the appropriate FSM event based on the angle from the fix.
   if (between(bearing, 0, direction * -70)) then
      print("Teardrop Entry")
      fsm:fire("teardrop-entry")
   elseif (between(bearing, 0, direction * 110)) then
      print("Parallel Entry")
      fsm:fire("parallel-entry")
   else
      print("Direct Entry")
      fsm:fire("direct-entry")
   end
   
end

function showTaskVisualizations()

   -- Frequency (in seconds of flying time) between points on turn
   local turnPointFreq = 5
   
   -- Length of time in seconds to fly each leg
   local legLength = 60

   -- Estimate the hold pattern of the aircraft
   local fixLocation = taskParameters.fixPoint
   fixLocation:setAlt(taskParameters.altitude)
   
   -- First point is the fix location
   local pattern = { fixLocation }
   local currentPoint = fixLocation
   local currentVector = Vector3D(0,0,0)
   currentVector:setBearingInclRange(taskParameters.heading, 0, taskParameters.speed)
   
   -- Default turn rate of fly heading task is 3 degrees/sec.
   local turnRate = math.rad(3)
   local turnTime = math.rad(180)/turnRate
   local numTurnPoints = turnTime/turnPointFreq
   
   -- Calculate points on out outbound turn
   local ptNum = 0
   while (ptNum < numTurnPoints) do
      currentVector:setBearingInclRange(
         currentVector:getBearing() + (turnRate * turnPointFreq * direction), 
         0,
         taskParameters.speed * turnPointFreq)
      currentPoint = currentPoint:addVector3D(currentVector)
      table.insert(pattern, currentPoint:makeCopy())
      ptNum = ptNum + 1
   end
   
   -- Calculate point at end of outbend leg
   currentVector:setBearingInclRange(
      taskParameters.heading + 3.14,
      0,
      taskParameters.speed * legLength)
   currentPoint = currentPoint:addVector3D(currentVector)
   table.insert(pattern, currentPoint:makeCopy())
   
   -- Calculate points on out outbound turn
   ptNum = 0
   while (ptNum < numTurnPoints) do
      currentVector:setBearingInclRange(
         currentVector:getBearing() + (turnRate * turnPointFreq * direction), 
         0,
         taskParameters.speed * turnPointFreq)
      currentPoint = currentPoint:addVector3D(currentVector)
      table.insert(pattern, currentPoint:makeCopy())
      ptNum = ptNum + 1
   end
   
   -- Should be back at the start point
   table.insert(pattern, fixLocation:makeCopy())
   
   -- Create visualization
   vrf:updateTaskVisualization("HoldPattern", "line", 
      {color={0,255,0,255}, locations=pattern})
   
   -- Create visualization
   vrf:updateTaskVisualization("FixLocation", "point", 
      {color={0,255,0,255}, size=10, location=fixLocation})
end

function tick()
   if (checkReleaseTime()) then
      if (fsm:get() == "inbound-leg") then
         vrf:endTask(true)
         return
      end
   end
   
   -- If the task visualizations are not yet created
   if (createTaskVis) then
      createTaskVis = false
      showTaskVisualizations()
   end
   
   -- Tick simply watches for subtask completions, and fires the "subtask-complete" event in the FSM.
   if (myWaitExpires > -1) then
      if (vrf:getExerciseTime() > myWaitExpires) then
		  myWaitExpires = -1
		  print("wait completed at ", vrf:getExerciseTime())
		  fsm:fire("wait-complete")
      end
      return 
   elseif (mySubtaskId > -1) then
      if (not vrf:isSubtaskRunning(mySubtaskId)) then
         if (vrf:isSubtaskComplete(mySubtaskId)) then
            if (vrf:subtaskResult(mySubtaskId)) then
               mySubtaskId = -1;
               fsm:fire("subtask-complete")         
            else
	       print("Subtask completed with fail state")
               mySubtaskId = -1;
               fsm:fire("subtask-failed")
            end
         else
            -- Not running, but no result?
            mySubtaskId = -1;
	    print("Subtask is no longer running, but is not complete");
            fsm:fire("subtask-failed")
         end
      end
   else
      -- subtask ID should never be -1 unless one of the subtasks failed to start.
      print("Subtask ID is -1")
      fsm:fire("subtask-failed")
   end
end

function saveState()
end

function loadState()
   showTaskVisualizations()
end
