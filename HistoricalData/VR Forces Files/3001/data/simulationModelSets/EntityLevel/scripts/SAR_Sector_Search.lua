-- Copyright 2012 VT-MAK
--
-- This is an experimental VR-Forces Lua task. It has been created to provide some basic example functionality 
-- that you can test, copy, use as-is, or modify to achieve your goals. It is not tested as part of the VR-Forces
-- standard task regression procedure and should be considered complete as is. We are happy to receive bug fixes and 
-- suggestions on ways to improve it via email to support@mak.com, Additionally will be happy to consider injecting any 
-- improvements or additional scripts which you may send to us. 
--
-- last Update: 12/16/2012
--
-- This task implements a standard Sector Search. Sector search is used when the last known point of the target is fairly well
-- known. This search will fly repeated passes over that point. 
-- This task works by generating a series of routes that the plane will fly, putting them into the routes table, and then
-- executing them one at a time until all routes have been flown. 

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- The task ID of the subtask that is currently running, if any.
mySubtaskId = -1
routes = {}
cspTG = {}


function flyRoute(theRoute)
	mySubtaskId = vrf:startSubtask("move-along", { route=theRoute, traversal_direction=0, start_at_closest_point=false })
end

-- a helper function to just inverse the heading. 
function inverseHeading(heading)
   return heading - math.rad(180)
end



-- Creates a route for a single pass. 
-- Parameters
--    segment -- the segment number, just used to give the route a unique name
--              When the segment is 0, then only a 1/2 pass is created. It is assumed the plane will be approaching
--               from the given angle, so no full route is required. Search commence actually begins at the CSP. 
--    cps -- the Commence Search point. This is the center of the star. All routes go through this point
--    Altitude -- the altitude of the pass
--    angle -- the angle of this pass
--    radius -- the search radius. 
function createPass(segment, csp, altitude, angle, radius)
	local routePoints = {}
	local localCsp = csp
	local offsetVector = Vector3D(0,0,0)
		
	localCsp:setAlt(altitude)
	if (segment > 1) then
		offsetVector:setBearingInclRange(inverseHeading(angle), 0, radius)
		table.insert(routePoints, localCsp:addVector3D(offsetVector))
	end
	table.insert(routePoints, localCsp)
	offsetVector:setBearingInclRange(angle, 0, radius)
	table.insert(routePoints,localCsp:addVector3D(offsetVector))
	table.insert(routes, vrf:createRoute({object_name=this:getName() .. " - Leg" .. segment,locations=routePoints}))
end



function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   cspTG = vrf:createTacticalGraphic({object_name=this:getName() .. "- CSP", entity_type="16:0:0:2:0:0:0", location=taskParameters.csp})
   local vectorToCsp = this:getLocation3D():vectorToLoc3D(taskParameters.csp)
   
   
   -- create all the passes, the createPass() function will add each route onto the routes() table. 
   local heading = vectorToCsp:getBearing()
   for segment = 1, 4, 1 do
	if  math.mod(segment, 2) == 0 then
		createPass(segment, taskParameters.csp, taskParameters.altitude,inverseHeading(heading),taskParameters.leg/2)
	else
		createPass(segment, taskParameters.csp, taskParameters.altitude,heading,taskParameters.leg/2)
	end
	heading = heading + math.rad(45)
   end
   
   -- set the right speed
   vrf:executeSetData("set-speed", {speed=taskParameters.airSpeed})

   -- fly the first route -- this kicks off the state machine. 
   flyRoute(routes[1]);
end

-- when called, this task will exit and clean up accordingly. This is to be called when an error state exists
function errorExit(message)
	print(message)
	mySubtaskId = -1;
	vrf:endTask(false)
end


function tick()
   -- Tick simply watches for subtask completions, and fires the "subtask-complete" event in the FSM.
   if (mySubtaskId > -1) then
      if (not vrf:isSubtaskRunning(mySubtaskId)) then
         if (vrf:isSubtaskComplete(mySubtaskId)) then
            if (vrf:subtaskResult(mySubtaskId)) then
               mySubtaskId = -1;
		-- execute next route segment
		-- first, remove the previous route segment. This only happens IF the segment has successfully been completed
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

-- If the task is ended prematurely, clean up all remaining routes
function shutdown()
	for key, value in pairs(routes) do
		vrf:deleteObject(value)
	end
	vrf:deleteObject(cspTG)
end



























































































