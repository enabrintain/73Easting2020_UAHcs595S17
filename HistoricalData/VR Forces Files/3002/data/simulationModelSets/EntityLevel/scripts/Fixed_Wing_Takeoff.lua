--
-- Copyright (c) 2013 MAK Technologies, Inc.
-- All rights reserved.
--

-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

mySubtaskId = -1
myPhase = nil
myMovementSystem = nil

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   -- The tick rate for this task is higher than usual because it needs to issue the fly heading task quickly after the animation finishes in order to avoid the plane being uncontrolled and diving.
   vrf:setTickPeriod(0.1)
   local routePoints = taskParameters.runway:getLocations3D()
   local rollPoint = routePoints[1]
   -- Make sure point is on the ground, so move-to-location taxis and doesn't try to fly
   if not this:isEmbarked() then
   local alt = vrf:getTerrainAltitude(routePoints[1]:getLat(),
      routePoints[1]:getLon())
   rollPoint:setAlt(alt)
   end
   mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point = rollPoint })

   myPhase = "taxiing"
   
   myMovementSystem = this:getSystem("movement")  
   if not myMovementSystem then
      printWarn(vrf:trUtf8("Fixed-wing-takeoff unable to find movement system in entity; aborting task."))
      vrf:endTask(false)
   end
end

-- Raises the landing gear
function landingGearUp()
	-- Move the articulated part if this entity has a langergear actuator on it.
	if (_G["landinggear"] ~= nil) then
		landinggear:close()
	end
	-- Set the landing lights appearance bit to off (some models key their landing gear off this bit)
	local a = Appearance.SetLandingLights(this:getAppearance(), false)
	a = Appearance.SetLandingGearExtended(a, false)
	vrf:executeSetData("set-appearance", {appearance = a})
end

function buildTakeoffAnimation(runwayLength)
	local takeoffDistance = runwayLength * 0.8 -- Lift off 80% of the way down the runway
	local takeoffSpeed = this:getParameter("min-speed") -- Runway speed before climbout is initiated
	
        if (takeoffSpeed == nil) then
           takeoffSpeed = 120
        end	
	
	takeoffSpeed = takeoffSpeed * 1.1
	
	local acceleration = takeoffSpeed ^ 2 / (2 * takeoffDistance)
	local takeoffTime = math.sqrt(2 * takeoffDistance / acceleration)
	--printInfo(vrf:trUtf8("Takeoff Acceleration: %1 Time: %2"):arg(acceleration):arg(takeoffTime))
	local numFrames = math.floor(takeoffTime * 5);
	local velocity = 0
	local position = 0
	local animation = ScriptAnimationModel(this)
	
	-- Altitude offset is from above ground clamped position
	animation:setClampType(5)
	
	-- Add the takeoff roll to the animation
	for frame = 1,numFrames do	
		animation:addAnimationRow(1 / 5, 0, position, 0, 0, 0, 0)
		velocity = velocity + acceleration / 5
		position = position + velocity / 5
	end

	-- Add the climbout to the animation
	local targetClimboutAngle = 20 -- The angle the plane will climb at
	local totalTransitionTime = 3 -- Number of seconds between reaching takeoff speed, and climbing at the target angle
	local climboutElevation = 500 -- The animation will end when the plane reaches this altitude (relative to its starting altitude)
	
   myDisembarkAtFrame = numFrames
   -- printWarn(vrf:trUtf8("Disembarking at frame %1"):arg(myDisembarkAtFrame))

	local transitionTime = 0
	local climboutAngle = 0
	local climboutVec = VectorOffset3D(0, velocity * math.cos(math.rad(climboutAngle)), velocity * math.sin(math.rad(climboutAngle)))	
	local elevation = 0
	while(elevation < climboutElevation) do
		if (transitionTime < totalTransitionTime) then
			climboutAngle = climboutAngle + targetClimboutAngle / (totalTransitionTime * 5)
			transitionTime = transitionTime + 1/5
			climboutVec:setForward(velocity/5 * math.cos(math.rad(climboutAngle)))
			climboutVec:setUp(velocity/5 * math.sin(math.rad(climboutAngle)))
		end
		position = position + climboutVec:getForward()
		elevation = elevation + climboutVec:getUp()
		animation:addAnimationRow(1 / 5, 0, position, elevation, 0, math.rad(climboutAngle), 0)
	end
	return animation
end


-- Called each tick while this task is active.
function tick()
	if (vrf:isSubtaskComplete(mySubtaskId)) then
		mySubtaskId = -1
		if (myPhase == "taxiing") then
			--printWarn(vrf:trUtf8("Ready to takeoff"))
			-- Calculate heading from point 1 to point 2 of the route
			local routePoints = taskParameters.runway:getLocations3D()
			local runwayVec = routePoints[1]:vectorToLoc3D(routePoints[2])
			animation = buildTakeoffAnimation(runwayVec:getRange())
			mySubtaskId = vrf:startSubtask("animated-movement-task", { animation_model = animation, reference_heading = runwayVec:getBearing()})
			--mySubtaskId = vrf:startSubtask("animated-movement-task", { animation_model = "Fixed Wing Takeoff", reference_heading = runwayVec:getBearing()})
			myPhase = "takeoff"
		elseif (myPhase == "takeoff") then
         -- After the animation, start the plane flying straight along the 
			-- runway heading
			-- This is here to prevent the default circle behavior of the plane from crashing down back on the runway.
			local routePoints = taskParameters.runway:getLocations3D()
			local runwayVec = routePoints[1]:vectorToLoc3D(routePoints[2])
			mySubtaskId = vrf:startSubtask("fly-heading", { heading = runwayVec:getBearing() })
			landingGearUp()
			myPhase = "fly-heading"
			-- There is no reason to wait for this next task to complete, just end the task right away.
			vrf:endTask(true)
		elseif (myPhase == "fly-heading") then
			vrf:endTask(true)
		end
   elseif ((myPhase == "takeoff") and this:isEmbarked()) then
      local animationFrame = myMovementSystem:getAttribute("animation-frame")

      -- once we are done taxiing and about to take off need to disembark if embarked
      if (animationFrame >= myDisembarkAtFrame) then
	      vrf:executeSetData("set-unload-entity", {})
      end
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