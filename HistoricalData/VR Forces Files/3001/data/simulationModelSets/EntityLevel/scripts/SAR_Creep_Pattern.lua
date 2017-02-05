-- Copyright 2012 VT-MAK
--
-- This is an experimental VR-Forces Lua task. It has been created to provide some basic example functionality 
-- that you can test, copy, use as-is, or modify to achieve your goals. It is not tested as part of the VR-Forces
-- standard task regression procedure and should be considered complete as is. We are happy to receive bug fixes and 
-- suggestions on ways to improve it via email to support@mak.com, Additionally will be happy to consider injecting any 
-- improvements or additional scripts which you may send to us. 
--
-- last Update:  12/16/2012

-- This executes a basic Creep Search and Rescue (SAR) aircraft pattern. The Creep Pattern is the same as the parallel pattern, 
-- except the major and minor legs are reversed. This pattern is used when
--   1. The search area is narrow and long.
--   2. The location of the target is thought to be on either side of the search track within two points.
--   3. There is immediate need for coverage of one end of the search area. 

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- The task ID of the subtask that is currently running, if any.
mySubtaskId = -1




-- At initialization, just call the Parallel Pattern but reverse the Major and Minor Legs. 
function init()

   mySubtaskId = vrf:startSubtask("SAR_Parallel_Pattern", {
	majorAxis = taskParameters.minorAxis, 
	minorAxis = taskParameters.majorAxis,
	csp = taskParameters.csp,
	leg = taskParameters.leg,
	creepDistance = taskParameters.creepDistance,
	altitude = taskParameters.altitude,
	airSpeed = taskParameters.airSpeed,
	numSweeps = taskParameters.numSweeps
	})
end

function tick()
end









































































