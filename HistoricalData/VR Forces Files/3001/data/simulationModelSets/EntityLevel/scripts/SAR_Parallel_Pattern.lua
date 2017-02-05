-- Copyright 2012 VT-MAK
--
-- This is an experimental VR-Forces Lua task. It has been created to provide some basic example functionality 
-- that you can test, copy, use as-is, or modify to achieve your goals. It is not tested as part of the VR-Forces
-- standard task regression procedure and should be considered complete as is. We are happy to receive bug fixes and 
-- suggestions on ways to improve it via email to support@mak.com, Additionally will be happy to consider injecting any 
-- improvements or additional scripts which you may send to us. 
--
-- last Update: 11/19/2012

-- This executes a basic Parallel Search and Rescue (SAR) aircraft pattern.  The Parallel pattern provides uniform coverage
-- on a fairly large level search area. 


-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- The task ID of the subtask that is currently running, if any.
mySubtaskId = -1
routes = {}
currentLeg = 0
-- a market for the CSP
cspTG = {}
-- save off the object name for route name differentiation. This 
-- prevents errors if multiple copies of this script are run at the same time.
local object = this

function flyRoute(theRoute)
	mySubtaskId = vrf:startSubtask("move-along", { route=theRoute, traversal_direction=0, start_at_closest_point=false })
end

-- a helper function to just inverse the heading. 
function inverseHeading(heading)
   return heading - math.rad(180)
end


-- generates an approach route to line the plane up on a target Location, Target Heading, and TargetAltitude
-- parameters: 
--    targetAltitude -- the final altitude on exit
--    targetHeading -- The final heading on exit
--    targetCSP -- The location of the first segment of the target route. This is not the final point on the Approach.
--    lastPoint -- a location where OS is coming from. This is where we will compute the apprach from. This isn't used 
--      at this moment. 
function createApproachRoutePoints(lastPoint, targetAltitude, targetHeading, targetCSP)
   local points = {}
   local offsetVector = Vector3D(0,0,0)
   local currentPoint = targetCSP
   
   -- meters from the tartgetRoute that we want our approach to end at.  This gives a little bit of separation between the two routes. 
   local routeOffset = 500

   currentPoint:setAlt(targetAltitude)

   local inverseHeading = inverseHeading(targetHeading)
   print("one")
   offsetVector:setBearingInclRange(inverseHeading , 0, routeOffset)

   points[3] = currentPoint:addVector3D(offsetVector)
   points[2] = points[3]:addVector3D(offsetVector)
   points[1] = points[2]:addVector3D(offsetVector)
   return points
end

-- The goal of this function is to create a full leg, including the approach route. 
-- This function will push two routes (leg  + approach) to the routes table
-- It will also return the last point of the leg that was created so that the next first point can be calculated. 
-- Parameters
-- Leg: the leg number, used to keep leg names unique
-- legCSP: this is the start search point for that specific leg. It does not include the leg approach
-- lastPoint: either the position of the OS or the last known point where OS will be. This helps us figure out the route approach
-- legAltitude: the altitude of this leg
-- legHeading: the direction to fly the leg
-- legLength: the number of meters in the leg, that is, how long is the leg. 
function createLeg(legNumber, lastPoint, legCsp, legAltitude, legHeading, legLength)
	local routePoints = {}
	local approachPoints = {}
	local currentPoint = legCsp
	local offsetVector = Vector3D(0,0,0)
	
	
	currentPoint:setAlt(legAltitude)

	 -- offset the first route, since the aircarft will hit CSP first and then needs to move to route. It should quickly normalize 
	 -- its altitude and direction of travel. 
	 print("create Leg" .. legHeading .. " " .. legLength)
	 offsetVector:setBearingInclRange(legHeading, 0, legLength)
	 routePoints[1] = legCsp
	 routePoints[2] = currentPoint:addVector3D(offsetVector)
   
	approachPoints = createApproachRoutePoints(lastPoint, legAltitude, legHeading, routePoints[1])
	table.insert(routes, vrf:createRoute ({object_name=object:getName()  .. " - Aproach" .. legNumber, locations=approachPoints}))
	table.insert(routes, vrf:createRoute({object_name=object:getName() .. " - Leg" .. legNumber,locations=routePoints}))
	
	-- return the last point
	return routePoints[2]
end


-- Called once when the task first starts.
-- The goal for this function is to set up the initial state. To do that it will 
-- create all the routes/legs that the aircraft will fly. It will also set the initial 
-- state of the aircraft, such as target velocity.
-- 
-- Please note, that routes need to be created in the order they are to be flown
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   cspTG = vrf:createTacticalGraphic({object_name=object:getName() .. "- CSP", entity_type="16:0:0:2:0:0:0", location=taskParameters.csp})

   --set up flight routes
   local offsetVector = Vector3D(0,0,0)
   local firstPoint = taskParameters.csp
   local lastPoint = this:getLocation3D()
   
   for i=1, taskParameters.numSweeps, 1 do
   
	local heading= 0
	if  math.mod(i, 2) == 0 then
		heading = inverseHeading(taskParameters.majorAxis)
	else
		heading = taskParameters.majorAxis
	end
	lastPoint = createLeg(i,lastPoint, firstPoint, taskParameters.altitude,heading,taskParameters.leg)
	offsetVector:setBearingInclRange(taskParameters.minorAxis, 0, taskParameters.creepDistance)
	firstPoint = lastPoint:addVector3D(offsetVector)
	
   end
   
   -- set the right speed
   vrf:executeSetData("set-speed", {speed=taskParameters.airSpeed})

   -- fly the first route -- this kicks off the state machine. 
   flyRoute(routes[1]);
end

-- when called, this task will exit and clean up accordinly. This is to be called when an error state exists
function errorExit(message)
	print(message)
	mySubtaskId = -1;
	vrf:endTask(false)
end

-- Called each tick while this task is active.
-- The tick function is basically only looking for a completion of a route, in which case it
-- kicks off the next flyRoute command, or its looking for an error, in which case it will exit. 
function tick()
   -- Tick simply watches for subtask completions, and fires the "subtask-complete" event in the FSM.
   if (mySubtaskId > -1) then
      if (not vrf:isSubtaskRunning(mySubtaskId)) then
         if (vrf:isSubtaskComplete(mySubtaskId)) then
            if (vrf:subtaskResult(mySubtaskId)) then
               mySubtaskId = -1;
		-- execute next route segment
		-- first, remove the previous route segment. This only happens IF the segment has successfully been completed.
		vrf:deleteObject(routes[1])
		table.remove(routes,1)
		print (table.getn(routes))
		if (table.getn(routes) > 0) then
			-- kick off the next task on the next route which is now rout #1
			flyRoute(routes[1])
		else
			-- we ran out of routes, we are done!
			vrf:endTask(false)
		end
	      
            else
	       errorExit("Subtask completed with fail state")
            end
         else
	    errorExit("Subtask is no longer running, but is not complete");
         end
      end
   else
      -- subtask ID should never be -1 unless one of the subtasks failed to start.
      errorExit("Subtask ID is -1")
   end
end

function shutdown()
	for key, value in pairs(routes) do
		vrf:deleteObject(value)
	end
	vrf:deleteObject(cspTG)
end









































































