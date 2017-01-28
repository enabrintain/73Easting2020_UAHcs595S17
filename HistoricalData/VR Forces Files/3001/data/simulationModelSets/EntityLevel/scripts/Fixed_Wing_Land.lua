-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.runway Type: SimObject

mySubtaskId = -1
myPhase = nil
myLandingSpeedSet = false
myGearDown = false

local heightAboveRunway = this:getParameter("right-support"):getUp()

-- Called when the task first starts. Never called again.
function init()
	-- Set the tick period for this script.
	vrf:setTickPeriod(0.1)
	
	approachRoute = createApproachRoute()
	mySubtaskId = vrf:startSubtask("fly-along", {route = approachRoute, use_fixed_pitch = true})
	myPhase = "approach"	
end

-- Gets a turn radius given speed and g limit
function getRadius(speed, gLimit)
   if gLimit == 0 then
      return 1e10
   else
      return speed * speed / (gLimit * 9.83)
   end
end

function createApproachRoute()
	-- Create a task to get the plane to the start of the landing animation
	local runwayPoints = taskParameters.runway:getLocations3D()
	local runwayVec = runwayPoints[1]:vectorToLoc3D(runwayPoints[2])
	
	local approachStartVec = runwayVec:getNegated()
	approachStartVec:setBearingInclRange(approachStartVec:getBearing(), 0, 3300) -- Distance from end of runway to start descent
	approachStartVec:setNorthEastDown(approachStartVec:getNorth(), approachStartVec:getEast(), -300 - heightAboveRunway)
	approachStart = runwayPoints[1]:addVector3D(approachStartVec)
	approachStartVec:setBearingInclRange(approachStartVec:getBearing(), 0, 350) -- Distance from end of runway to level the descent path
	approachStartVec:setNorthEastDown(approachStartVec:getNorth(), approachStartVec:getEast(), -17 - heightAboveRunway)
	local approachLevel = runwayPoints[1]:addVector3D(approachStartVec)
	approachStartVec:setBearingInclRange(approachStartVec:getBearing() + math.rad(180), 0, 100) -- Distance from end of runway to end descent path
	approachStartVec:setNorthEastDown(approachStartVec:getNorth(), approachStartVec:getEast(), -17 - heightAboveRunway)
	local approachEnd = runwayPoints[1]:addVector3D(approachStartVec)
	
	local routePoints = {}
	
	-- If the plane is on the "wrong" side of the approach path start, add a base leg to the start of the approach route
	local approachToPlaneVec = approachStart:vectorToLoc3D(this:getLocation3D())
	local headingDiff = approachToPlaneVec:headingDiff(runwayVec)
	if (math.abs(headingDiff) < math.rad(90)) then
	        local turnRadius = getRadius(approachSpeed(), 1.5)
		local baseStartVec = Vector3D(0,0,0)
		local baseEndVec = Vector3D(0,0,0)
		local baseAngle = 0
		if (headingDiff < 0) then
			baseAngle = math.rad(90)
		else
			baseAngle = 0 - math.rad(90)
		end
		baseEndVec:setBearingInclRange(runwayVec:getBearing() + baseAngle * 1.5 , 0, turnRadius)
		baseStartVec:setBearingInclRange(runwayVec:getBearing() + baseAngle, 0, 1000)
		local baseEnd = approachStart:addVector3D(baseEndVec)
		table.insert(routePoints, baseEnd:addVector3D(baseStartVec))
		table.insert(routePoints, baseEnd)
	end
	
	-- Add some points along the final approach path to help the a/c line up well by the end of the route.
	local intermeadiateVec = approachStart:vectorToLoc3D(approachLevel)
	intermeadiateVec = intermeadiateVec:getScaled(0.25)
	
	table.insert(routePoints, approachStart)
	table.insert(routePoints, approachStart:addVector3D(intermeadiateVec))
	table.insert(routePoints, approachStart:addVector3D(intermeadiateVec:getScaled(2)))
	table.insert(routePoints, approachStart:addVector3D(intermeadiateVec:getScaled(3)))
	table.insert(routePoints, approachLevel)
	table.insert(routePoints, approachEnd)
	
	approachRoute = vrf:createRoute({locations = routePoints, entity_type = "17:0:0:2:32:0:0", publish = false, object_name = "Landing Approach" })
	return approachRoute
end


-- Returns the approach speed for the aircraft
function approachSpeed()
	return this:getParameter("min-speed") * 1.1
end

-- Returns the distance needed to slow from current speed to approach speed
function decelerationDistance()
	local deltaSpeed = this:getSpeed() - approachSpeed()
	if (deltaSpeed < 0) then
		return 0
	end
	local decelTime = deltaSpeed / this:getParameter("flaps-deceleration")
	return this:getSpeed() * decelTime
end

-- Lowers the landing gear
function landingGearDown()
	-- Move the articulated part if this entity has a langergear actuator on it.
	if (_G["landinggear"] ~= nil) then
		landinggear:open()
	end
	-- Set the landing lights appearance bit to on (some models key their landing gear off this bit)
	local a = Appearance.SetLandingLights(this:getAppearance(), true)
	a = Appearance.SetLandingGearExtended(a, true)
	vrf:executeSetData("set-appearance", {appearance = a})
end

function startTouchdownAnimation()
	local runwayPoints = taskParameters.runway:getLocations3D()
	local runwayVec = runwayPoints[1]:vectorToLoc3D(runwayPoints[2])
	local timeScale = this:getSpeed() / 100 -- Animation is recorded at 100m/s
	local animationRefPoint = runwayPoints[1]
	animationRefPoint:setAlt(animationRefPoint:getAlt() + heightAboveRunway) -- Height above runway to end
	mySubtaskId = vrf:startSubtask("animated-movement-task", { animation_model = "Fixed Wing Landing", reference_heading = runwayVec:getBearing(),
		reference_point = animationRefPoint, time_scale = timeScale })
end

-- Called each tick while this task is active.
function tick()
	-- Monitor for the plane being near the start point of the touchdown animation.
   local runwayPoints = taskParameters.runway:getLocations3D()
	if (myPhase == "approach") then
		local offsetVec = this:getLocation3D():vectorToLoc3D(runwayPoints[1])
		if (offsetVec:getRange() < 215) then
			vrf:stopSubtask(mySubtaskId)
			startTouchdownAnimation()
			myPhase = "touch-down"
			return
		end
		
		-- Check for close to the start of the approach route and set the landing speed
		if (not myLandingSpeedSet) then
			local distToApproach = this:getLocation3D():vectorToLoc3D(approachStart):getRange()
			if (distToApproach < decelerationDistance()) then
				vrf:executeSetData("set-speed", { speed = approachSpeed() }) 
				myLandingSpeedSet = true
				printInfo(vrf:trUtf8("Setting approach speed: %1"):arg(approachSpeed()))
			end			
		end
		
		-- Check for how close the touchdown point is, and lower landing gear if needed
		if (not myGearDown) then
			local distToApproach = this:getLocation3D():vectorToLoc3D(taskParameters.runway:getLocations3D()[1]):getRange()
			if (distToApproach < 1000) then 
				landingGearDown()
				myGearDown = true
			end
		end
	end
	
	if (myPhase == "just-embarked") or (vrf:isSubtaskComplete(mySubtaskId)) then
		if (myPhase == "approach") then
			startTouchdownAnimation()
			myPhase = "touch-down"
		elseif ((myPhase == "touch-down") or (myPhase == "just-embarked")) then	
			-- clamp the entity to the terrain surface
			local alt, valid  = vrf:getTerrainAltitude(this:getLocation3D():getLat(), this:getLocation3D():getLon())
			local newPos = this:getLocation3D()
			newPos:setAlt(alt + heightAboveRunway)
			this:setLocation3D(newPos)
			mySubtaskId = vrf:startSubtask("move-to-location", { aiming_point = runwayPoints[2] })
			myPhase = "on-runway"
		elseif (myPhase == "on-runway") then
                        vrf:executeSetData("set-current-speed", {speed = 0})
			vrf:endTask(true)
		end
	elseif ((myPhase == "touch-down") and taskParameters.runway:isEmbarked() and this:isOnTopOf(taskParameters.runway:getEmbarkedOn())) then
	   -- Stop the animation at this point and continue with the move to the last point
	   vrf:stopSubtask(mySubtaskId)
	   myPhase = "just-embarked"
	   this:attachToParent(taskParameters.runway:getEmbarkedOn())
	end
end

-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
   -- By default, halt all subtasks and other entity tasks started by this task when suspending.
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
   if (approachRoute:isValid()) then
	vrf:deleteObject(approachRoute)
   end
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
	if (approachRoute:isValid()) then
		vrf:deleteObject(approachRoute)
	end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
