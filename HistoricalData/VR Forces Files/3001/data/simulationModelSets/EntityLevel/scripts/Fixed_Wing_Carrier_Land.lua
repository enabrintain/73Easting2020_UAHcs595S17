-- Land a (small) fixed-wing aircraft, but on an aircraft carrier where it is 
-- caught by wires and stopped quickly.
-- Assumes that the route provided to define the landing area has the first point on 
-- the deck, and the second point at the 3rd wire where the ideal trap
-- occurs. Assume the altitude of the route points is on the deck.
--
-- This task runs an animation of the landing to put the aircraft in 
-- a high angle of attack, and then a second animation to decelerate it.
--
-- **** Written for a carrier that is part of the terrain, not an entity ****

DEBUG = false

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

approachSpeed = this:getParameter("min-speed") * 1.1 -- Ought to be 120-130 knots,
   -- or 62-67 mps
   
-- A point a km from the stern of the ship, where the aircraft
-- begins its landing approach.
approachStart = nil


-- Data for F-18, from https://answers.yahoo.com/question/index?qid=20090501100633AAbcVwg
local GLIDE_SLOPE = math.rad(3.5) 
local APPROACH_AOA = math.rad(8)

-- Deceleration rate in the wire-- 10 == 1g
local DECEL_RATE = 40

-- For debugging: prints a stream of 
local refPt = Location3D(0, 0, 0)
local lastTime = vrf:getSimulationTime()
local lastPt = refPt
function printPosition(obj)
   local loc = obj:getLocation3D()
   local vec = refPt:vectorToLoc3D(loc)
   local t = vrf:getSimulationTime()
   local elapsed = t - lastTime
   local dx = lastPt:distanceToLocation3D(loc)
   printWarn(string.format("%.3f:  %f %f %f, dx = %f, dt = %.3f, v = %f",
      t, 
      vec:getEast(), vec:getNorth(), -vec:getDown(),
      dx, elapsed, dx/elapsed))
   lastTime = t
   lastPt = loc
end

-- Task Parameters Available in Script
--  taskParameters.runway Type: SimObject

mySubtaskId = -1
myPhase = nil
myLandingSpeedSet = false
myGearDown = false
approachRoute = nil

local heightAboveRunway = this:getParameter("right-support"):getUp()

-- Get the points in the runway object. Raise them up to the height of
-- the plane origin (assumes they started on the ground)
runwayPoints = taskParameters.runway:getLocations3D()
runwayPoints[1]:setAlt(runwayPoints[1]:getAlt() + heightAboveRunway)
runwayPoints[2]:setAlt(runwayPoints[2]:getAlt() + heightAboveRunway)

	-- Create a task to get the plane to the start of the landing animation
runwayVec = runwayPoints[1]:vectorToLoc3D(runwayPoints[2])

-- Called when the task first starts. Never called again.
function init()
	-- Set the tick period for this script.
	vrf:setTickPeriod(0.1)
	
	approachRoute = createApproachRoute()
	mySubtaskId = vrf:startSubtask("fly-along", {route = approachRoute, use_fixed_pitch = true})
	myPhase = "approach"	
end

function createApproachRoute()
	
	local approachStartVec = runwayVec:getNegated()
   -- Compute point for start of final approach
	approachStartVec:setBearingInclRange(approachStartVec:getBearing(), GLIDE_SLOPE, 1000)
   -- Use the second point, which is the touchdown target, as the reference.
	approachStart = runwayPoints[2]:addVector3D(approachStartVec)
   
   -- Compute point to level out (before landing animation)
	approachStartVec:setBearingInclRange(approachStartVec:getBearing(), GLIDE_SLOPE, 300)
	local approachLevel = runwayPoints[2]:addVector3D(approachStartVec)
   
   -- Compute another aiming point at the same elevation. The plane
   -- should be down before it gets here.
	local approachEnd = runwayPoints[2]:makeCopy()
   approachEnd:setAlt( approachLevel:getAlt())
	
	local routePoints = {}
	
	-- If the plane is on the "wrong" side of the approach path start, 
   -- add a base leg to the start of the approach route
	local approachToPlaneVec = approachStart:vectorToLoc3D(this:getLocation3D())
	local headingDiff = approachToPlaneVec:headingDiff(runwayVec)
	if (math.abs(headingDiff) < math.rad(90)) then
		local baseStartVec = Vector3D(0,0,0)
      local approachVec = Vector3D(0, 0, 0)
		if (headingDiff < 0) then
			baseStartVec:setBearingInclRange(runwayVec:getBearing() + math.rad(90), 0, 1000)
         approachVec:setBearingInclRange(runwayVec:getBearing() + math.rad(135), 0, 150)
		else
			baseStartVec:setBearingInclRange(runwayVec:getBearing() - math.rad(90), 0, 1000)
         approachVec:setBearingInclRange(runwayVec:getBearing() - math.rad(135), 0, 150)
		end
		table.insert(routePoints, approachStart:addVector3D(baseStartVec))
		table.insert(routePoints, approachStart:addVector3D(approachVec))
	end
	
	-- Add some points along the final approach path to help the a/c line up well by the end of the route.
	local intermeadiateVec = approachStart:vectorToLoc3D(approachLevel)
	intermeadiateVec = intermeadiateVec:getScaled(0.25)
	
	table.insert(routePoints, approachStart)
--	table.insert(routePoints, approachStart:addVector3D(intermeadiateVec))
--	table.insert(routePoints, approachStart:addVector3D(intermeadiateVec:getScaled(2)))
	table.insert(routePoints, approachStart:addVector3D(intermeadiateVec:getScaled(3)))
	table.insert(routePoints, approachLevel)
	table.insert(routePoints, approachEnd)
	
	approachRoute = vrf:createRoute({locations = routePoints, 
      entity_type = "17:0:0:2:32:0:0", publish = false, 
      object_name = "Landing Approach" })
	return approachRoute
end

function buildTrappedAnimation()
	local stopTime = approachSpeed / DECEL_RATE
   local frameRate = 5
	local numFrames = math.ceil(stopTime * frameRate);
	local velocity = approachSpeed
	local position = 0
	local animation = ScriptAnimationModel(this)
	
	-- Altitude offset is from above ground clamped position
	animation:setClampType(5)
	
	for frame = 1,numFrames do	
		animation:addAnimationRow(1 / frameRate, 0, position, 0, 0, 0, 0)
		position = position + velocity / frameRate
		velocity = velocity - DECEL_RATE / frameRate
      if velocity < 0 then velocity = 0 end
	end
	return animation
end

-- Returns the distance needed to slow from current speed to approach speed
function decelerationDistance()
	local deltaSpeed = this:getSpeed() - approachSpeed
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
	vrf:executeSetData("set-appearance", {appearance = a})
end

function buildTouchdownAnimation()
   local frameRate = 5
   local vectorToTouchdown = this:getLocation3D():
      vectorToLoc3D(runwayPoints[2])
   local height = vectorToTouchdown:getDown() -- Distance to descend
   
   vectorToTouchdown:setNorthEastDown(
      vectorToTouchdown:getNorth(),
      vectorToTouchdown:getEast(),
      0)
   local rangeH = vectorToTouchdown:getRange() -- Distance to go forward
	local velocityH = approachSpeed * rangeH /
      math.sqrt(rangeH * rangeH + height * height)
   local approachTime = rangeH / velocityH
   velocityH = velocityH / frameRate -- convert to dt size
   
	local numFrames = math.ceil(approachTime * frameRate) + 1 --  a fudge
   local velocityV = height / approachTime / frameRate
   local pitchRate = APPROACH_AOA / 4.0 / frameRate -- take 4 second to pitch up
	local position = 0
   local alt = 0
   local pitch = this:getDirection3D():getInclination()
	local animation = ScriptAnimationModel(this)
	
	-- No clamping
	animation:setClampType(4)
	
	-- Add the takeoff roll to the animation
	for frame = 1,numFrames do	
		animation:addAnimationRow(1 / frameRate, 0, position, alt, 0, pitch, 0)
		position = position + velocityH
      alt = alt - velocityV
      if alt < -height then alt = -height end
      pitch = pitch + pitchRate
      if pitch > APPROACH_AOA then pitch = APPROACH_AOA end
	end
	return animation
end
   
--~ function startTouchdownAnimation()
--~ 	local runwayVec = runwayPoints[1]:vectorToLoc3D(runwayPoints[2])
--~ 	local timeScale = this:getSpeed() / 100 -- Animation is recorded at 100m/s
--~ 	local animationRefPoint = runwayPoints[1]
--~ 	animationRefPoint:setAlt(animationRefPoint:getAlt() + heightAboveRunway) -- Height above runway to end
--~ 	mySubtaskId = vrf:startSubtask("animated-movement-task", { animation_model = "Fixed Wing Landing", reference_heading = runwayVec:getBearing(),
--~ 		reference_point = runwayPoints[1], time_scale = timeScale })
--~ end

-- Called each tick while this task is active.
function tick()
   if DEBUG then printPosition(this) end
	-- Monitor for the plane being near the start point of the touchdown animation.
	if (myPhase == "approach") then
		local offsetVec = this:getLocation3D():vectorToLoc3D(runwayPoints[2])
		if offsetVec:getRange() < 350 and
         math.abs(offsetVec:headingDiff(runwayVec)) < math.rad(5) and
         (math.abs(offsetVec:getInclination() + GLIDE_SLOPE) < math.rad(5))
         then
      
         if DEBUG then printWarn("Starting landing animation") end
			vrf:stopSubtask(mySubtaskId)
         local animation = buildTouchdownAnimation()
			mySubtaskId = vrf:startSubtask("animated-movement-task",
            {animation_model = animation,
            reference_heading = offsetVec:getBearing()})
			myPhase = "touch-down"
			return
      else
         if DEBUG and offsetVec:getRange() < 400 then 
            printWarn(string.format("  Range %.1f, heading diff %.1f, incl %.1f",
               offsetVec:getRange(),
               math.deg(offsetVec:headingDiff(runwayVec)),
               math.deg(offsetVec:getInclination())))
         end
		end
		
		-- Check for close to the start of the approach route and set the landing speed
		if (not myLandingSpeedSet) then
			local distToApproach = this:getLocation3D():vectorToLoc3D(approachStart):getRange()
			if (distToApproach < decelerationDistance() ) then
            if DEBUG then 
               printWarn("Distance to approach start point ", distToApproach)
               printWarn("Deceleration distance ", decelerationDistance())
               printWarn("=> Commanding speed to approach speed ", approachSpeed)
            end
				vrf:executeSetData("set-speed", { speed = approachSpeed }) 
				myLandingSpeedSet = true
				printInfo(vrf:trUtf8("Setting approach speed: %1"):arg(approachSpeed))
			end			
		end
		
		-- Check for how close the touchdown point is, and lower landing gear if needed
		if (not myGearDown) then
			local distToApproach = this:getLocation3D():vectorToLoc3D(
            taskParameters.runway:getLocations3D()[2]):getRange()
			if (distToApproach < 1000 and
            this:getSpeed() < approachSpeed * 1.2) then 
				landingGearDown()
            if DEBUG then printWarn("Gear down") end
				myGearDown = true
			end
		end
	end
	
	
	if (vrf:isSubtaskComplete(mySubtaskId)) then
		if (myPhase == "approach") then
         printWarn("Bolting")
			mySubtaskId = vrf:startSubtask("fly-along", 
            {route = approachRoute, use_fixed_pitch = true})
		elseif (myPhase == "touch-down") then	
			-- clamp the entity to the terrain surface
			local alt = vrf:getTerrainAltitude(this:getLocation3D():getLat(), 
            this:getLocation3D():getLon())
         
			local newPos = this:getLocation3D()
			newPos:setAlt(alt + heightAboveRunway)
			this:setLocation3D(newPos)

         if DEBUG then printWarn("Clamping AC to alt ", alt + heightAboveRunway) end
         
         -- bring it to a quick stop
         local animation = buildTrappedAnimation()
         
--~          vrf:createWaypoint({location = this:getLocation3D(), 
--~             object_name = "Trap",
--~             publish = true})
            
         if DEBUG then printWarn("Starting trap animation") end
         mySubtaskId = vrf:startSubtask("animated-movement-task", 
            { animation_model = animation})
         myPhase = "trapped"
		elseif (myPhase == "trapped") then
			vrf:endTask(true)
		end
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
