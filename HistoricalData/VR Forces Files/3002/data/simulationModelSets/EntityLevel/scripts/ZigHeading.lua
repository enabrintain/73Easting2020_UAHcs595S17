-- This is an experimental VR-Forces Lua task. It has been created to provide some basic example functionality 
-- that you can test, copy, use as-is, or modify to achieve your goals. It is not tested as part of the VR-Forces
-- standard task regression procedure and should be considered complete as is. We are happy to receive bug fixes and 
-- suggestions on ways to improve it via email to support@mak.com, Additionally will be happy to consider injecting any 
-- improvements or additional scripts which you may send to us. 
-- last Update: 11/6/2012

FSM = require "fsm"
require "vrfUtil"

mySubtaskId = -1

myRightHeading = 0
myLeftHeading = 0
myStartTime = vrf:getExerciseTime()
myLegTimeInSec = 0.0

function sailHeading(targetHeading)
	mySubtaskId = vrf:startSubtask("turn-move-sail-heading", { finalHeading = targetHeading})
end


-- Define State Transitions:
local myStateTransitionTable = {
    {"zigLeft", "turn", "zigRight", function() sailHeading(myRightHeading) end},
    {"zigRight", "turn", "zigLeft", function() sailHeading(myLeftheading) end},
    {"startup", "turn", "zigLeft", function () sailHeading(myLeftheading) end},
    {"*", "subtask-failed", "task-failed", function() vrf:endTask(false) end}
}

-- Create your instance of a finite state machine
fsm = FSM.new(myStateTransitionTable)


function init()

	mySubtaskId = -1
	
	-- As this is a naval task, let's slow down the tick rate 
	vrf:setTickPeriod(0.5)

	myRightHeading = taskParameters.heading - taskParameters.legOffset
	myLeftheading = taskParameters.heading + taskParameters.legOffset
	
	myStartTime = vrf:getExerciseTime()
	-- leg length is in minutes
	myLegTimeInSec = taskParameters.legLength * 60.0
	
	-- set up the initial state, then send a mesage to bootstrap the FSM.
	fsm:set("startup")
	fsm:fire("turn")
end

function tick()


   if (mySubtaskId > -1) then
	if (not vrf:isSubtaskRunning(mySubtaskId)) then
		if (vrf:isSubtaskComplete(mySubtaskId)) then
			if (vrf:subtaskResult(mySubtaskId)) then
				mySubtaskId = -1
				-- the subtask shouldn't have completed
				print("Subtask completed but it shouldn't have")    
				return
			else
				print("Subtask completed with fail state")
				mySubtaskId = -1
				fsm:fire("subtask-failed")
				return
			end
		else
			-- Not running, but no result?
			mySubtaskId = -1;
			print("Subtask is no longer running, but is not complete");
			fsm:fire("subtask-failed")
		end
	end
	
	 -- check if our time has expired so that we can start a new leg
	if (vrf:getExerciseTime() > myStartTime + myLegTimeInSec) then
		-- While you can get away with just clobbering an already running task, it is better to actually forceably end it
		-- as there will be some internal cleanup. 
		vrf:stopSubtask(mySubtaskId)
		mySubtaskId = -1
		myStartTime = vrf:getExerciseTime()
		fsm:fire("turn")
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
end
