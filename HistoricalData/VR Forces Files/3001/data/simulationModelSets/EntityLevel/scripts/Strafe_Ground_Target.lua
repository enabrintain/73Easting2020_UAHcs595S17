-- Script to fly an aircraft on a strafing mission
-- 2014, VT-MAK

-- TODO:
-- Add a goal point state variable, and collapse the two at-point predicates


-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Spatial utilities. For the CSC path function.
spatialUtil = require "spatialUtil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.targetPoint Type: SimObject - The location of the strafing target
--  taskParameters.targetType Type: Enumeration - The type of the target to find and engage at the target point
--  taskParameters.abortWithoutTarget Type boolean - If a target type is selected, and no entity of that type is acquired, the AC will not shoot.
--  taskParameters.initialPoint Type: SimObject - Initial Point, from which the aircraft will begin its strafing attack.
--  taskParameters.initialPointLocation Type: Location3D - Initial point; use if initalPoint control object is not valid.
--  taskParameters.egressManeuver Type: Integer (0 - choice limit) - The initial egress maneuver. "Juke" is a sharp S-turn before a climb.
--  taskParameters.finalEgressHeading Type: number (heading) - The final flight direction when the task ends.
--###########################################################################
-- Constant definitions

local DEBUG_DETAIL = true

local HALF_PI = math.pi * 0.5

-- Entity types to target

-- Enumeration in the parameter:
local NO_TYPES = 0 
local TANKS = 1
local ARMORED_VEHICLES = 2
local ANY_VEHICLES = 3
local INFANTRY = 4
local BUILDING = 5

local TANK_TYPES = {"1:1:-1:1:-1:-1:-1"}
local ARMORED_VEHICLE_TYPES = {"1:1:-1:1:-1:-1:-1", "1:1:-1:2:-1:-1:-1", "1:1:-1:3:-1:-1:-1", "1:1:-1:4:-1:-1:-1"}
local ANY_VEHICLE_TYPES = {"1:1:-1:-1:-1:-1:-1"} -- Note: targets must be on the ground though
-- "Infantry" includes civilians-- really, any humans.
-- Aggregate infantry unit is included; some aggregates may have their own sensor signatures.
-- That way, a target may be found, even if individuals are not acquired.
local INFANTRY_TYPE = {"3:1:-1:1:-1:-1:-1", "3:1:-1:3:-1:-1:-1", "3:1:-1:4:-1:-1:-1", "11:1:-1:-1:3:-1:-1"}
local BUILDING_TYPE = {EntityType.CulturalFeature()}

local TARGET_TYPE_MAP = {
   [TANKS] = TANK_TYPES,
   [ARMORED_VEHICLES] = ARMORED_VEHICLE_TYPES,
   [ANY_VEHICLES] = ANY_VEHICLE_TYPES,
   [INFANTRY] = INFANTRY_TYPE,
   [BUILDING] = BUILDING_TYPE
   }

-- Signature threshold used to assume detection
local DETECTION_THRESHOLD = 1.1

-- Maximum height AGL a target can be (avoid targeting airborne aircraft)
local MAX_TARGET_HEIGHT = 3.0

-- Task delay before a subtask starts (and the movement begins, 
-- e.g. a turn). Used to try to make maneuvers a little more
-- precise. (in seconds):
local TASK_DELAY = 0.5

-- Minimum altitude at which AC is allowed to fly while strafing.
-- In meters.
local MIN_ALTITUDE = 100

-- If the AC starts the task this much faster than the entry air speed, then
-- it slows down first before starting to maneuver to the IP.
-- In KNOTS. (1 knot = 0.514 mps)
local SPEED_DIFF_THRESHOLD = 100

-- If the AC starts more than this distance above the entry altitude,
-- it will descend before starting the maneuver to the IP. This allows
-- the AC to avoid descending turns and allows it to hit the IP more accurately.
-- In meters.
local ALT_DIFF_THRESHOLD = 300

-- Factor that determines when AC starts too far away from IP to maneuver to it
-- immediately, and must instead fly to an approach point. This factor is multiplied
-- by a radius to compute the threshold distance. The radius is determined by the AC
-- start speed and the IP_MANEUVER_G.
-- For an AC flying at 200 m/s (400 knots), with an IP_MANEUVER_G of 2, the radius
-- is about 2km.
local DIST_THRESHOLD_FACTOR = 4

-- Presumed G limit that the move-to-location subtask uses.
local MOVE_TO_G   = 1.0

-- Nominal acceleration rate (g's) for maneuver to IP
local IP_MANEUVER_G = 4.0

-- Threshold angle at which the AC is considered to have reached its
-- goal heading. In radians.
local ANGLE_THRESHOLD = 0.05

-- The radius from the target point to look for target entities. In meters.
local TARGET_RADIUS = 100

-- Minimum Combat ID Level needed to target an entity. 1=detected, 
-- 2=classified, 3=identified, 4= full knowledge
local MIN_CID_LEVEL = 2

-- Amount of time the AC has to dive toward the target before firing.
-- Note that aiming can be done while flying level toward the dive point,
-- so this constant doesn't reflect all the time the pilot has to aim.
-- If this value is too high, the dive will be extended, meaning that the
-- dive start point may end up higher than the entry altitude parameter.
local AIM_TIME = 2.0

-- The burst length for strafing
local BURST_TIME = 1.2

-- Minimum time from end of burst to when the AC would hit the ground
-- at the target point... during which the AC should pull up.
local SAFETY_TIME = 3.0

-- Enumerated values for egress maneuver parameter
local LEFT_JUKE = 0
local IMM_CLIMB = 1
local RIGHT_JUKE = 2

-- AC climbs after attack to this altitude before turning to final heading.
-- (In meters AGL):
local FINAL_ALTITUDE = 1000

-- The factor multiplied by max-speed to determine egress maneuver speed.
local EGRESS_SPEED_FACTOR = 0.7
-----------------------------------------------------------------
-- Global variables 

-- Recomputed on every load, so don't
-- need to be saved in a scenario save:

local _maxGs
local _gunSystem
local _gunName
local _initErr = false

-- Global variables that are saved:
_state = {}

_state.originalRoe = ""
_state.taskId = -1
-- Using visual sensor-- see similar comments throughout code.
--_state.visualSensor = nil
_state.ipLocation = nil
_state.ipAltMSL = 300.0 -- Terrain height at IP + _state.entryAltitude
_state.targetLocation = nil
_state.terrainHeightAtTgt = 0

-- Strafing parameters (aerial gun descriptor). Defaults here are overwritten.
_state.entryAltitude = 0
_state.entryAirSpeed = 0
_state.diveAngle = 0
_state.strafeRange = 0

-- A preliminary point to go to while dropping altitude or
-- reducing speed.
_state.approachPoint = nil

-- Maneuver to IP computed characteristics.
-- The maneuver is a turn, straight segment, and turn.
_state.maneuverSpeed = 0 -- Current speed at start of maneuvering to IP
_state.maneuverRadius = 1 -- Turn radius for start speed and IP_MANEUVER_G
_state.initialIsLeft = false
_state.exitHeading = nil -- heading at which initial turn is complete
_state.turnInLocation = nil -- location3D where final turn starts
_state.finalIsLeft = false
_state.finalHeading = nil -- heading from IP to target point

_state.goalHeading = 0 -- the current goal heading for different maneuvers
_state.lineToPoint = nil -- a line from the AC to a goal point, for testing move completion
_state.desiredAltitude = 0

_state.diveLocation = nil -- the location where the AC starts firing. At _state.strafeRange from target.
_state.targetEntity = nil -- the target found at the target point, if any
_state.eventEndTime = 0 -- A timer
_state.abort = false -- True if target is not acquired, and abortWithoutTarget is true.

--###########################################################################
-- Script Initialization
--###########################################################################

-- Initialization functions called in the global block (every load):

-- Get the gun system and the parameters in it.
-- Returns true if everything is OK, or false if there was an error.
function getSystemData()
   local err
   local moveSystem = this:getSystem("movement")
   if moveSystem ~= nil then
      _maxGs, err = moveSystem:getAttribute("max-gs")
      if err then _maxGs = 2.0 end
   else
      printWarn("Strafe Ground: could not find movement system.")
      return false
   end
   
   local weaponList = Util.getWeaponSystems()
   local i, weaponSys, found
   _gunSystem = nil
   for i, weaponSys in ipairs(weaponList) do
      if weaponSys:getAttribute("strafing-use") == "true" then
         _gunSystem = weaponSys
         break
      end
   end
   if _gunSystem == nil then
      printWarn("Cannot find a strafing weapon. Aborting task.")
      return false
   else
      _gunName = _gunSystem:getName()
      printVerbose("Using gun ", _gunName, " for strafing.")
   end
   
   -- Get param and print error if not found
   local function getGunParam(name)
      local val, err
      val, err = _gunSystem:getAttribute(name)
      if err then
         printWarn("Strafe Ground: cound not find ", name, 
            " parameter.")
         return nil, true
      else
         return val, false
      end
   end
   
   _state.entryAltitude, err = getGunParam("entry-altitude")
   if not err then
      _state.entryAirSpeed, err = getGunParam("entry-airspeed")
   end
   if not err then 
      _state.diveAngle, err = getGunParam("dive-angle")
   end
   if not err then
      _state.strafeRange, err = getGunParam("strafe-range")
   end
   
-- Using visual sensor:
--~    if not err then
--~       local sensors = Util.getSensorSystems()
--~       local i, sensor
--~       for i, sensor in ipairs(sensors) do
--~          if string.find(sensor:getName(), "Visual") ~= nil then
--~             _state.visualSensor = sensor
--~             break
--~          end
--~       end
--~       err = (_state.visualSensor == nil)
--~    end
   
   return not err
end

-- Gets a turn radius given speed and g limit
function getRadius(speed, gLimit)
   if gLimit == 0 then
      return 1e10
   else
      return speed * speed / (gLimit * 9.83)
   end
end

-----------------------------------------------------------------
-- Global block run every time the script is loaded:
   
if not getSystemData() then 
   vrf:endTask(false) 
   _initErr = true
   printWarn("Failed to get system data; exiting.")
elseif DEBUG_DETAIL then
   printDebug(string.format("Entry speed %f, altitude %f, dive angle %f, strafe range %f",
      _state.entryAirSpeed, _state.entryAltitude, 
      _state.diveAngle, _state.strafeRange))
end

--========================================================================
-- Called when the task first starts. Never called again.
function init()
   if _initErr then
      return
   end
   if not taskParameters.targetPoint:isValid() then
      printWarn("Target point not valid.")
      vrf:endTask(false)
      return
   else
      _state.targetLocation = taskParameters.targetPoint:getLocation3D()
      _state.terrainHeightAtTgt = vrf:getTerrainAltitude(
         _state.targetLocation:getLat(), _state.targetLocation:getLon())
      _state.targetLocation:setAlt(_state.terrainHeightAtTgt + 1) -- Make sure it is above ground for LOS
      
      if taskParameters.initialPoint:isValid() then
         _state.ipLocation = taskParameters.initialPoint:getLocation3D()
      else
         _state.ipLocation = taskParameters.initialPointLocation
      end
      
      local terrainHeightAtIp = vrf:getTerrainAltitude(_state.ipLocation:getLat(), _state.ipLocation:getLon())
      local IpAGL = _state.terrainHeightAtTgt + _state.entryAltitude - terrainHeightAtIp
      if IpAGL < MIN_ALTITUDE then
         IpAGL = _state.entryAltitude
         printInfo("Terrain height at IP is too high for nominal strafing profile; increasing profile altitude at IP.")
      end   
      _state.ipAltMSL = terrainHeightAtIp + IpAGL
      _state.ipLocation:setAlt(_state.ipAltMSL)
      if DEBUG_DETAIL then
         printDebug(string.format("Terrain height at IP: %f; AC goal alt %f",
            terrainHeightAtIp, _state.ipAltMSL))
      end
   
   end
   local distance = _state.targetLocation:distanceToLocation3D(_state.ipLocation)
   if distance < _state.entryAirSpeed * (AIM_TIME + BURST_TIME + SAFETY_TIME) then
      printWarn("IP is too close to target to allow strafing run. Exiting.")
      vrf:endTask(false)
      return
   end
   
   _state.originalRoe = this:getRulesOfEngagement()
   this:setRulesOfEngagement("hold") -- Keep other weapons from shooting
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   taskFSM:set("start")
   if DEBUG_DETAIL then printDebug("Finished initialization. State ", taskFSM:get()) end
end


--###########################################################################
-- Functions for FSM-- predicates, action functions, and support functions
--###########################################################################

-- Predicates:

-- Predicate for task finished. Check ID = -1, in case
-- a transition function ends the task before it starts.
function taskFinished(s)
   return s.taskId == -1 or
      taskDone(s.taskId, true)
end

function abortFlagged(s)
   return s.abort
end

-- At goal heading predicate. Uses the global s.goalHeading, 
-- which should be set by the function that starts a fly-heading subtask.
-- Checks task finished as well, in case the task has already exited.
function atGoalHeading(s)
   if taskFinished(s) then
      return true
   else
      local diff = this:getHeading() - s.goalHeading
      if diff < -math.pi then
         diff = diff + 2 * math.pi
      elseif diff > math.pi then
         diff = diff - 2 * math.pi
      end
      if DEBUG_DETAIL then
         printDebug(string.format(".   At heading? Mine %f, goal %f",
            this:getHeading(), s.goalHeading))
      end
      return math.abs(diff) < ANGLE_THRESHOLD
   end
end

function isTrue(s) 
   return true
end
   
function tooFarFromIp(s)
   local myLocation = this:getLocation3D()
   local myAlt = myLocation:getAlt()
   myLocation:setAlt(s.ipAltMSL)
   local distance = myLocation:distanceToLocation3D(s.ipLocation)
   local altDiff = math.abs(myAlt - s.ipAltMSL)
   if DEBUG_DETAIL then
      if distance > getRadius(this:getSpeed(), IP_MANEUVER_G) * DIST_THRESHOLD_FACTOR then
         printDebug(".   At distance ", distance, " from IP; go to approach point.")
      elseif altDiff > ALT_DIFF_THRESHOLD then
         printDebug(".   At altitude ", altDiff, " above IP; descend to approach point.")
      end
   end
   return distance > getRadius(this:getSpeed(), IP_MANEUVER_G) * DIST_THRESHOLD_FACTOR or
      altDiff > ALT_DIFF_THRESHOLD
end

function tooFast(s)
   if DEBUG_DETAIL then
      printDebug(string.format("Speed %f, goal %f",
         this:getSpeed(), s.entryAirSpeed + SPEED_DIFF_THRESHOLD * 0.514))
   end
   return this:getSpeed() > s.entryAirSpeed + SPEED_DIFF_THRESHOLD * 0.514 -- Knots to mps
end

-- This also checks near-IP in case the AC is flying in over the target
function nearApproachPoint(s)
   local myLocation = this:getLocation3D()
   local myAlt = myLocation:getAlt()
   local apprchPtAlt = s.approachPoint:getAlt()
   myLocation:setAlt(apprchPtAlt)
   local distance = myLocation:distanceToLocation3D(s.approachPoint)
   myLocation:setAlt(s.ipLocation:getAlt())
   local ipDistance = myLocation:distanceToLocation3D(s.ipLocation)
   local altDiff = math.abs(myAlt - apprchPtAlt)
   if DEBUG_DETAIL then
      printDebug(string.format("Near appoach or IP pt? Dist limit %f; appr pt dist %f, ip dist %f.",
         getRadius(this:getSpeed(), IP_MANEUVER_G),
         distance, ipDistance))
      printDebug(string.format("    Alt diff limit %f; alt diff %f.",
         ALT_DIFF_THRESHOLD, altDiff))
   end   
   distance = math.min(distance, ipDistance)
   return distance <= getRadius(this:getSpeed(), MOVE_TO_G) and
      altDiff <= ALT_DIFF_THRESHOLD
end
      
function atEntryParameters(s)
   return (nearApproachPoint(s) or taskFinished(s)) and
      not tooFast(s)
end
   
function pastTurnInPoint(s)
   local lineToGoalNow = this:getLocation3D():
      vectorToLoc3D(s.turnInLocation)
   local dot = s.lineToPoint:dotVector3D(lineToGoalNow)
   if DEBUG_DETAIL then
      printDebug(string.format("Turn-in-point pred: orig line (%f, %f, %f), now (%f, %f, %f), dot %f",
         s.lineToPoint:getEast(), s.lineToPoint:getNorth(), - s.lineToPoint:getDown(),
         lineToGoalNow:getEast(), lineToGoalNow:getNorth(), - lineToGoalNow:getDown(),
         dot))
   end
   if dot <= 0 then 
      return true
   else
      return false
   end
end

function pastDivePoint(s)
   -- Check if we were already past the point before entering this state
   if s.taskId == -1 then
      return true
   end
   local lineToGoalNow = this:getLocation3D():
      vectorToLoc3D(s.diveLocation)
   local dot = s.lineToPoint:dotVector3D(lineToGoalNow)
   if dot <= 0 then 
      return true
   else
      return false
   end
end

function eventFinished(s)
   return vrf:getSimulationTime() > s.eventEndTime
end

function atDesiredAlt(s)
   return this:getLocation3D():getAlt() > s.desiredAltitude
end

---------------------------------------------------------------------
-- Action functions and supporting utilities:

function noOp(s)
   s.eventTime = vrf:getSimulationTime() -- Set to allow state to transition immediately
end

-- Too high or too far from IP; start a move toward a point behind
-- the IP, while descending.
function goToApproachPoint(s)
   local speedThresh = SPEED_DIFF_THRESHOLD * 0.514 -- knots to m/s
   local initialSpeedGoal = s.entryAirSpeed + speedThresh
   
   local finalDirection = s.targetLocation:vectorToLoc3D(s.ipLocation)
   s.maneuverRadius = getRadius(initialSpeedGoal, IP_MANEUVER_G)
   finalDirection:setBearingInclRange(finalDirection:getBearing(), 0, s.maneuverRadius * 3.)
   
   s.approachPoint = s.ipLocation:addVector3D(finalDirection)
   local approachPtTerrain = vrf:getTerrainAltitude(s.approachPoint:getLat(), 
      s.approachPoint:getLon())
   s.approachPoint:setAlt(math.max(s.ipAltMSL, approachPtTerrain + s.entryAltitude ))
   
   s.taskId = vrf:startSubtask("fly-to-location", {aiming_point = s.approachPoint})
   -- Make sure the AC is not flying slowly toward approach point
   vrf:executeSetData("set-speed", {speed = this:getParameter("ordered-speed")})
   
   printVerbose(string.format("%.3f Strafe: Flying to approach point point at (%f, %f), alt %.1f m",
      vrf:getSimulationTime(),
      math.deg(s.approachPoint:getLat()), math.deg(s.approachPoint:getLon()),
      s.approachPoint:getAlt()))
end

function reduceSpeed(s)
   -- Slow down, but not all the way yet. Final speed adjustment at IP.
   vrf:executeSetData("set-speed", {speed = s.entryAirSpeed + SPEED_DIFF_THRESHOLD * 0.514})
   printVerbose(string.format("%.3f Strafe: Slowing to speed %f",
      vrf:getSimulationTime(), s.entryAirSpeed + SPEED_DIFF_THRESHOLD * 0.514))
end

-- Get the circle-segment-circle maneuver parameters for the path to the IP.
-- Uses the heading and position of the AC, the heading from IP to target,
-- and the IP. 
-- Uses the maneuver speed, which is the current speed whtn the maneuver starts.
-- Returns: computes values and fills in the global variables containing
-- the maneuver characteristics:
-- s.initialIsLeft 
-- s.exitHeading 
-- s.turnInLocation 
-- s.finalIsLeft
-- s.finalHeading
--
function getCscManeuver(s, speed, R)
   -- Assume that there will be a TASK_DELAY time delay before the
   -- aircraft starts its turn.
   local moveDelay = speed * TASK_DELAY
   local position = this:getLocation3D():addVector3D(
      this:getDirection3D():getScaled(moveDelay))
   local heading = this:getHeading()
   
   -- Assume the points have similar altitudes...we are only looking at 2D.
   local finalVector = s.ipLocation:
      vectorToLoc3D(s.targetLocation)
   s.finalHeading = finalVector:getBearing()
   local finalDirection = Vector3D(0, 0, 0)
   finalDirection:setBearingInclRange(s.finalHeading, 0, 1.0)
   -- Move the goal IP back away from the target by a small distance
   -- to give the AC a moment to roll out of the turn
   local finalPosition = s.ipLocation:addVector3D(
      finalDirection:getScaled(-moveDelay))
   
   local pathLength, err
   s.initialIsLeft, s.exitHeading, s.turnInLocation, s.finalIsLeft, pathLength, err = 
       spatialUtil.cscManeuver(position, heading, finalPosition, s.finalHeading,
           R)
   -- Adjust the turn-in point back to account for task delays:
   finalDirection:setBearingInclRange(s.exitHeading, 0, 1.0)
   s.turnInLocation = s.turnInLocation:addVector3D(
      finalDirection:getScaled(-moveDelay))
end

-- Determines parameters for the flight to the IP. 
-- Sets  altitude MSL for the entry altitude (AGL)
-- specified in the gun system for this AC.
-- Computes the maneuver points and starts the AC on the first turn.
function startFirstTurn(s)
   if vrf:isSubtaskRunning(s.taskId) then
      vrf:stopSubtask(s.taskId)
   end
   s.maneuverSpeed = this:getSpeed()
   s.maneuverRadius = getRadius(s.maneuverSpeed, IP_MANEUVER_G)
   
   -- Keep speed the same to fly constant-radius turns
   vrf:executeSetData("set-speed", {speed = s.maneuverSpeed})

   -- Compute s.initialIsLeft, s.exitHeading, s.turnInLocation, s.finalIsLeft and s.finalHeading
   getCscManeuver(s, s.maneuverSpeed, s.maneuverRadius)
   s.turnInLocation:setAlt(s.ipAltMSL)
   
   local turnDir = 1 -- Signifies right turn
   if s.initialIsLeft then turnDir = -1 end -- Signifies left turn
   
   local turnRate = s.maneuverSpeed/s.maneuverRadius
   
   printVerbose(string.format("%.3f Strafe: Starting first turn to heading %.1f (deg)",
      vrf:getSimulationTime(), math.deg(s.exitHeading)))
   s.taskId = vrf:startSubtask("fly-heading-and-altitude", 
      {altitude = s.ipAltMSL,
      heading = s.exitHeading,
      turn_rate = turnRate,
      turn_direction = turnDir})
   if (s.taskId == -1) then
      printWarn("fly-heading-and-altitude task failed to start.")
   end
   s.goalHeading = s.exitHeading
end
 
function startMoveToTurnInPoint(s)
   if vrf:isSubtaskRunning(s.taskId) then
      vrf:stopSubtask(s.taskId)
   end
   printVerbose(string.format("%.3f Strafe: Starting task to fly to turn in point (%f, %f) alt %.2f)",
      vrf:getSimulationTime(), math.deg(s.turnInLocation:getLat()),
      math.deg(s.turnInLocation:getLon()), s.turnInLocation:getAlt()))
   s.taskId = vrf:startSubtask("fly-to-location", {aiming_point = s.turnInLocation})
   s.lineToPoint = this:getLocation3D():vectorToLoc3D(s.turnInLocation)
end

function startFinalTurn(s)
   local turnRate = this:getSpeed()/s.maneuverRadius
   
   local turnDir = 1 -- Signifies right turn
   if s.finalIsLeft then turnDir = -1 end -- Signifies left turn
   
   printVerbose(string.format("%.3f Strafe: Starting final turn to IP",
      vrf:getSimulationTime()))
   s.taskId = vrf:startSubtask("fly-heading-and-altitude",
      {heading = s.finalHeading,
      turn_rate = turnRate,
      altitude = s.ipAltMSL,
      turn_direction = turnDir})
   
   if taskParameters.targetType ~= NO_TYPES then
      local stringOfTypes, j, typeString = ""
      for j, typeString in ipairs(TARGET_TYPE_MAP[taskParameters.targetType]) do
         if j > 1 then
            stringOfTypes = stringOfTypes .. ", "
         end
         stringOfTypes = stringOfTypes .. typeString
      end
-- Using visual sensor:
--      s.visualSensor:setAttribute("types-to-detect-for-task", stringOfTypes)
   end
         
   s.goalHeading = s.finalHeading
end

-- Pick a target, if possible; 
-- identify the location where firing will begin;
-- and start a task to move to the firing location.
function startFinalApproach(s)
   if vrf:isSubtaskRunning(s.taskId) then
      vrf:stopSubtask(s.taskId)
   end
   -- Bring the speed to the strafing speed
   vrf:executeSetData("set-speed", {speed = s.entryAirSpeed})

   -- The point where the dive begins should be distance s.strafeRange 
   -- plus aim-distance from the target point,
   -- on a bearing that goes from the AC to the target and slopes down at s.diveAngle.
   -- Check also that for the s.entryAirSpeed, s.strafeRange is a distance away
   -- greater than BURST_TIME + SAFETY_TIME.
   -- Returns the dive point, or nil if no suitable location is found.
   local function computeDiveLocation()
      local mySpeed = this:getSpeed()
      local shootRange = s.strafeRange + s.entryAirSpeed * TASK_DELAY
      local aimRange = shootRange + s.entryAirSpeed * AIM_TIME
      local minDistance = s.entryAirSpeed * (AIM_TIME + BURST_TIME + SAFETY_TIME)
      if DEBUG_DETAIL then
         printDebug(string.format("Comp dive pt dist from targ: start shoot at %.1f, start aim at %.1f",
            shootRange, aimRange))
         printDebug("Entry air speed ", s.entryAirSpeed, ", strafe range param ", s.strafeRange)
      end
      
      if minDistance > aimRange then
         printInfo("Strafe range from gun is too close for safety; using ",
            minDistance)
         aimRange = minDistance
      end
      local distToTarget = this:getLocation3D():distanceToLocation3D(s.targetLocation)
      if distToTarget < aimRange then
         if distToTarget < minDistance then
            printWarn("Aircraft is too close to target for strafe run. Exiting.")
            vrf:endTask(false)
            return nil
         else
            aimRange = (distToTarget + minDistance) * 0.5 -- halfway to the min distance point
         end
      end
      -- We don't want to start the task and have it find out that the AC is past the point...
      if distToTarget - aimRange < mySpeed * 3 * TASK_DELAY then
         if DEBUG_DETAIL then
            printDebug("Too close to firing point, skip to next state")
         end
         return nil
      end
      local glideLine = s.targetLocation:vectorToLoc3D(this:getLocation3D())
      glideLine:setBearingInclRange(glideLine:getBearing(),
         s.diveAngle, aimRange)
      return s.targetLocation:addVector3D(glideLine)
   end
   --
   s.diveLocation = computeDiveLocation()
   if s.diveLocation ~= nil then
      printVerbose(string.format("%.3f Strafe: Starting flight to dive point at (%f, %f), alt %.1f",
         vrf:getSimulationTime(),
         math.deg(s.diveLocation:getLat()), math.deg(s.diveLocation:getLon()), 
         s.diveLocation:getAlt()))
      s.taskId = vrf:startSubtask("fly-to-location", {aiming_point = s.diveLocation})
      -- For testing completion:
      s.lineToPoint = this:getLocation3D():vectorToLoc3D(s.diveLocation)
   else
      s.taskId = -1 -- signal the task is "done," and the state should transition immediately
   end
end
   
function startDive(s)
   if vrf:isSubtaskRunning(s.taskId) then
      vrf:stopSubtask(s.taskId)
   end
   -- Look for an entity of the correct type within a radius
   -- of the target point.
   local function findTargetEntity()
-- Using visual sensor:
--~       local targetList = this:getContactsWithFilter(
--~          TARGET_TYPE_MAP[taskParameters.targetType],
--~          true) -- Only directly observed contacts
      local targetList = vrf:getSimObjectsNearWithFilter(
         s.targetLocation, TARGET_RADIUS,
         {types = TARGET_TYPE_MAP[taskParameters.targetType]})
      if DEBUG_DETAIL then
         printDebug("Found ", #targetList, " potential targets")
      end
      local i, target
      local closestDist = math.huge
      local closestTarget = nil
      local myForce = this:getForceType()
      for i, target in ipairs(targetList) do
         if DEBUG_DETAIL then
            printDebug("Considering contact ", target:getName())
         end
         if target:isValid() and
            target ~= this 
-- To prevent fratricide:
            --and vrf:forcesHostile(myForce, target:getForceType()) 
-- Using visual sensor:
--            and this:getContactInfo(target).detectionLevel >= MIN_CID_LEVEL then
            then
            
            local targHeight = target:getHeightAboveTerrain()
            local targSig = this:targetSignature(target, "visual")
            if targHeight <= MAX_TARGET_HEIGHT and
               targSig >= DETECTION_THRESHOLD  then
            
               local distance = s.targetLocation:distanceToLocation3D(target:getLocation3D())
               if DEBUG_DETAIL then
                  printDebug(string.format("...OK, height %.1f, target signature %.3f"..
                     "; target dist to target point %.1f",
                     targHeight, targSig, distance))
               end
               if distance < closestDist then 
                  closestTarget = target
                  closestDist = distance
               end
            elseif DEBUG_DETAIL then
               printDebug("  No target: HAT ", targHeight,
                  ", visual signature ", targSig)
            end   
         end
      end
      if DEBUG_DETAIL and closestTarget ~= nil then
         printDebug("Selecting target ", closestTarget:getName())
      end
      return closestTarget
   end
   --
   -- TMP
--~   printInfo("Target types (Param=", taskParameters.targetType, "):")
--~    if taskParameters.targetType == NO_TYPES then
--~       printWarn("None")
--~    else
--~       local j, t
--~       for j, t in ipairs(TARGET_TYPE_MAP[taskParameters.targetType]) do
--~          printInfo(t)
--~       end
--~    end
   if taskParameters.targetType == NO_TYPES then
      s.targetEntity = taskParameters.targetPoint
   else
      s.targetEntity = findTargetEntity()
      if s.targetEntity == nil then
         if taskParameters.abortWithoutTarget then
            printWarn("No Joy (target not acquired). Aborting strafing run.")
            s.abort = true
            s.goalHeading = this:getHeading() -- The goal heading of the initial egress maneuvers
            return
         else
            s.targetEntity = taskParameters.targetPoint
         end
      end
   end
   s.targetLocation = s.targetEntity:getLocation3D()
   
   printVerbose(string.format("%.3f Starting dive toward target.",
      vrf:getSimulationTime()))
   printInfo("Target: ", s.targetEntity:getName())
      
   s.taskId = vrf:startSubtask("fly-to-location",
      {aiming_point = s.targetLocation,
      use_fixed_pitch = true})

   s.eventEndTime = vrf:getSimulationTime() + AIM_TIME
end

function fireGuns(s)
   printVerbose(string.format("%.3f Starting strafing run, shooting at %s, range %f",
      vrf:getSimulationTime(), s.targetEntity:getName(),
      this:getLocation3D():distanceToLocation3D(s.targetLocation)))
   local fireId = vrf:startSubtask("fire-at-target",
      {auto_select_weapon = false,
      weapon_to_fire = _gunName,
      target = s.targetEntity})  
   s.eventEndTime = vrf:getSimulationTime() + BURST_TIME
   s.goalHeading = this:getHeading() -- The goal heading of the initial egress maneuvers
end

function startJukeLeft(s)
   vrf:stopSubtask(s.taskId)
   vrf:executeSetData("set-speed",
      {speed = s.entryAirSpeed * 1.5})
   s.goalHeading = s.goalHeading - HALF_PI
   s.taskId = vrf:startSubtask("fly-heading",
      {heading = s.goalHeading,
      turn_direction = -1, -- left
      turn_rate = 1.0}) -- Rapid turn; will probably be limited in actuator
   printVerbose(string.format("%.3f Starting juke left",
      vrf:getSimulationTime()))
-- Using visual sensor:
--   s.visualSensor:setAttribute("clear-types-to-detect", true)

end

function startJukeRight(s)
   vrf:stopSubtask(s.taskId)
   vrf:executeSetData("set-speed",
      {speed = s.entryAirSpeed * 1.5})
   s.goalHeading = s.goalHeading + HALF_PI
   s.taskId = vrf:startSubtask("fly-heading",
      {heading = s.goalHeading,
      turn_direction = 1, -- right
      turn_rate = 1.0}) -- Rapid turn; will probably be limited in actuator
   printVerbose(string.format("%.3f Starting juke right",
      vrf:getSimulationTime()))
-- Using visual sensor:
--   s.visualSensor:setAttribute("clear-types-to-detect", true)
end

function startSecondTurn(s)
   vrf:stopSubtask(s.taskId)
   vrf:executeSetData("set-speed",
      {speed = this:getParameter("max-speed") * EGRESS_SPEED_FACTOR})
   s.taskId = vrf:startSubtask("fly-heading",
      {heading = s.finalHeading,   -- Set during fire state
      turn_direction = 0, -- closest direction
      turn_rate = 1.0}) -- Rapid turn; will probably be limited in actuator
   printVerbose(string.format("%.3f Starting second juke turn",
      vrf:getSimulationTime()))
   s.goalHeading = s.finalHeading
end
   
function startClimbEgress(s)
   vrf:stopSubtask(s.taskId)
   s.taskId = vrf:startSubtask("fly-heading-and-altitude",
      {altitude = 2.0 * FINAL_ALTITUDE + s.terrainHeightAtTgt, -- Aim past desired altitude to get there faster
      heading = s.finalHeading,  -- Set during fire state
      turn_rate = 0.8, 
      climb_descent_rate = this:getParameter("max-climb-rate")})
   vrf:executeSetData("set-speed",
      {speed = this:getParameter("max-speed") * EGRESS_SPEED_FACTOR})
   printVerbose(string.format("%.3f Starting climb-out egress, rate %.1f m/s to altitude %.1f m; speed %.1f m/s",
      vrf:getSimulationTime(),
      this:getParameter("max-climb-rate"), FINAL_ALTITUDE + s.terrainHeightAtTgt,
      this:getParameter("max-speed") * EGRESS_SPEED_FACTOR))
      
   s.desiredAltitude = FINAL_ALTITUDE + s.terrainHeightAtTgt -- For state transition condition
-- Using visual sensor:
--   s.visualSensor:setAttribute("clear-types-to-detect", true)
end
      
function resetCruiseSpeedAndExit(s)
   vrf:executeSetData("set-speed",
      {speed = this:getParameter("ordered-speed")})
   vrf:startSubtask("fly-heading-and-altitude", 
      {heading = taskParameters.finalEgressHeading,
      turn_rate = 0.3,
      altitude = s.desiredAltitude})
   this:setRulesOfEngagement(_state.originalRoe)
   vrf:endTask(true)
end

--###########################################################################
-- Define FSM for task
--###########################################################################

FSM = require "fsm2"
taskFSM = FSM.new()

-- States:
-- start
-- going-to-approach-point
-- slowing-down
-- first-turn-to-ip
-- segment-to-ip
-- final-turn-to-ip
-- fly-to-attack-point
-- aiming
-- firing
-- juke-left
-- juke-right
-- juke-second-turn
-- egress-climb 

-- If far from IP or too high, create and goto approach location; fixes both. Don't slow down yet though.
taskFSM:addTransition("start", tooFarFromIp, "going-to-approach-point", goToApproachPoint)
-- If already close enough, but going too fast, just slow
taskFSM:addTransition("start", tooFast, "slowing-down", reduceSpeed)
-- Otherwise start CSC maneuver to IP
taskFSM:addTransition("start", isTrue, "first-turn-to-ip", startFirstTurn)

-- If close enough, low enough and slow enough, start CSC maneuver to IP
taskFSM:addTransition("going-to-approach-point", atEntryParameters, "first-turn-to-ip", startFirstTurn)
-- Otherwise if near goal, must be just too fast, so slow down
taskFSM:addTransition("going-to-approach-point", nearApproachPoint, "slowing-down", reduceSpeed)

-- Already near approach point or IP, so transition when speed is slow enough
taskFSM:addTransition("slowing-down", function (s)
                                        return not tooFast(s)
                                        end, 
                                        "first-turn-to-ip", startFirstTurn)

taskFSM:addTransition("first-turn-to-ip", atGoalHeading, "segment-to-ip", startMoveToTurnInPoint)
taskFSM:addTransition("segment-to-ip", pastTurnInPoint, "final-turn-to-ip", startFinalTurn)
taskFSM:addTransition("final-turn-to-ip", atGoalHeading, "fly-to-dive-point", startFinalApproach)
taskFSM:addTransition("fly-to-dive-point", pastDivePoint, "aiming", startDive)
taskFSM:addTransition("aiming", abortFlagged, "firing", noOp)
taskFSM:addTransition("aiming", eventFinished, "firing", fireGuns)
taskFSM:addTransition("firing", function(w) 
                                 return eventFinished(w) and
                                       taskParameters.egressManeuver == LEFT_JUKE
                              end, 
                              "juke-left", startJukeLeft)
taskFSM:addTransition("firing", function(w) 
                                 return eventFinished(w) and
                                       taskParameters.egressManeuver == RIGHT_JUKE
                              end, 
                              "juke-right", startJukeRight)
taskFSM:addTransition("firing",  eventFinished, "egress-climb", startClimbEgress)
taskFSM:addTransition("juke-left",  atGoalHeading, "juke-second-turn", startSecondTurn)
taskFSM:addTransition("juke-right",  atGoalHeading, "juke-second-turn", startSecondTurn)
taskFSM:addTransition("juke-second-turn", atGoalHeading, "egress-climb", startClimbEgress)
taskFSM:addTransition("egress-climb", atDesiredAlt, "done", resetCruiseSpeedAndExit)

--###########################################################################
function tick()
--~    if DEBUG_DETAIL then printDebug(string.format("\n%.3f Strafe Ground, state %s",
--~       vrf:getSimulationTime(), taskFSM:get()))
--~    end
   taskFSM:tick(_state)
end

--###########################################################################

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
