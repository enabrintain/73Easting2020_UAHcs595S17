-- Copyright 2013 VT-MAK
--
-- This task approximates a standard aircraft holding pattern, using standard turns, and 1 minute legs.
-- This includes an entry into the holding pattern using one of the standard entry procedures "direct", "teardrop" or "parallel"
-- These entries are only approximate, and do not refect the actual entries in high detail.  Depending on the entry
-- angle of the aircraft, the holding pattern may take a couple of cycles before the aircraft is accurately situated on it.
--
-- This task is implemented in terms of another scripted task "AircraftHold" which takes a location instead of a waypoint.
-- This task simply takes the location of the waypoint, and passes it to the subtask.
-- This task also monitors for the user moving the waypoint, or the waypoint being deleted, and takes appropriate action.

require "vrfutil"

mySubtaskId = -1
-- Fix location is stored here so it can be periodically compared to the current location of the waypoint,
-- and if the waypoint has moved, the subtask can be reissued with a new location.
myFixLocation = nil

-- Starts the hold pattern at location subtask and sets the global myFixLocation to the location currently holding at.
function startSubtask()
	myFixLocation = taskParameters.fix:getLocation3D()
	mySubtaskId = vrf:startSubtask("AircraftHold", {fixPoint = myFixLocation,
		heading = taskParameters.heading, speed = taskParameters.speed, altitude = taskParameters.altitude,
		direction = taskParameters.direction})
end

function init()
   mySubtaskId = -1
   vrf:setTickPeriod(0.5)
end

function tick()
	if (mySubtaskId > -1) then
		-- Check for subtask completion
		if (not vrf:isSubtaskRunning(mySubtaskId)) then			
			vrf:endTask(vrf:subtaskResult(mySubtaskId))
			mySubtaskId = -1
		end
		
		-- Check to see if the waypoint has moved.  If so, reissue the subtask.
		if (taskParameters.fix:isValid()) then  
			if (myFixLocation:distanceToLocation3D(taskParameters.fix:getLocation3D()) > 10) then
				vrf:stopSubtask(mySubtaskId)
				mySubtaskId = -1
				startSubtask()
			end
		else
			-- End the task if the waypoint has been deleted.
			if (taskParameters.fix:isDeleted()) then
				vrf:endTask(false)
			end
		end
	else
		-- If the waypoint is valid, start the subtask.
		if (taskParameters.fix:isValid()) then
			startSubtask()
		else
			-- If the point has been deleted, then end the task.
			if (taskParameters.fix:isDeleted()) then
				vrf:endTask(false)
			end
		end			
	end
end

function saveState()
end

function loadState()
end











