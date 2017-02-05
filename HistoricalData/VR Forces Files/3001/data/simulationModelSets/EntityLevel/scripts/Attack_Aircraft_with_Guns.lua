-- Script to fly an aircraft toward a target aircraft and attack it with guns.
-- 2014, VT-MAK


-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.target Type: SimObject - Target aircraft entity

--###########################################################################
-- Constant definitions

local DEBUG_DETAIL = true
local KNOTS_TO_MPS = 0.514

-- The max-deceleration parameter in the entity params is not used in the 
-- FWA controller or actuator (!), so guess at what is used.
local DECELERATION = 10

-- Time to prepare to shoot before getting to engage range-- time used
-- to slow AC to match target speed.
local AIM_TIME = 2.0

-- Minimum normalized visual signature needed for detection
local SIGNATURE_THRESHOLD = 1.1

-- If using real visual system:
-- Minimum CID level required to shoot at target. 1 = detect, 2 = classified, 3 = ID
--local MIN_CID_LEVEL = 1

-- How much faster than the target the AC will go while shooting.
-- >>> In KNOTS
local SHOOTING_RELATIVE_SPEED = 150.0

local MINIMUM_AIRSPEED = this:getParameter("min-speed")

-- Burst time-- assume this length burst. At any rate, the minimum time
-- between trigger pulls.
local BURST_TIME = 1.0

-- Minimum altitude (AGL) to maintain while approaching. In meters.
local MINIMUM_ALTITUDE = 80

-----------------------------------------------------------------
-- Global variables 

-- Recomputed on every load, so don't
-- need to be saved in a scenario save:

local _initErr = false
local _gunSystem = nil
local _gunName = ""

-- Global variables that are saved:

_state = {}

_state.originalRoe = ""
_state.taskId = -1 --  For movement
_state.shootingTaskId = -1
-- If using an actual visual sensor for acquisition:
--_state.visualSensor = nil

_state.aaEngageRange = 1000
_state.aaBreakOffRange = 200
_state.target = nil
_state.targetType = ""

_state.approachDistance = 2000 -- Distance needed to start approach
_state.timeOfFire = 0 -- Time the trigger pull was commanded



--###########################################################################
-- Script Initialization
--###########################################################################

-- Initialization functions called in the global block (every load):

-- Get the gun system and the parameters in it.
-- Returns true if everything is OK, or false if there was an error.
function getSystemData()
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
      printWarn("Cannot find a gun weapon. Aborting task.")
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
   
   _state.aaEngageRange, err = getGunParam("aa-engage-range")
   if not err then
      _state.aaBreakOffRange, err = getGunParam("aa-breakoff-range")
   end
   
   -- If using an actual visual system for acquisition,
   -- get _state.visualSensor here
   
   return not err
end

-----------------------------------------------------------------
-- Global block run every time the script is loaded:
   
if not getSystemData() then 
   vrf:endTask(false) 
   _initErr = true
   printWarn("Failed to get system data; exiting.")
elseif DEBUG_DETAIL then
   printDebug(string.format("Engage range %f, break off range %f",
      _state.aaEngageRange, _state.aaBreakOffRange))
end



-- Called when the task first starts. Never called again.
function init()
   if _initErr then
      return
   end
   if not taskParameters.target:isValid() then
      printWarn("Target not valid.")
      vrf:endTask(false)
      return
   else
      _state.target = taskParameters.target
      _state.targetType = taskParameters.target:getEntityType()
   end
   
   _state.originalRoe = this:getRulesOfEngagement()
   this:setRulesOfEngagement("hold") -- Keep other weapons from shooting
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.4)
   taskFSM:set("start")
end

--###########################################################################
-- Functions for FSM-- predicates, action functions, and support functions
--###########################################################################

-- Predicates:

-- Predicate for task finished. Check ID = -1, in case
-- a transition function ends the task before it starts.
function taskFinished(s)
   return s.taskId == -1 or
      not vrf:isSubtaskRunning(s.taskId)
end

function shootingTaskFinished(s)
   if s.timeOfFire + BURST_TIME > vrf:getSimulationTime() then
      return false
   else
      return s.shootingTaskId == -1 or
         not vrf:isSubtaskRunning(s.shootingTaskId)
   end
end

function targetDestroyed(s)
   if s.target:isDestroyed() then
      printVerbose("  Target destroyed.")
   end
   return s.target:isDestroyed()
end

function isTrue(s) 
   return true
end
   
function tooClose(s)
   local speed = this:getParameter("ordered-speed")
   local radius = speed * speed / 40 -- 4 g turns
   s.approachDistance = radius + s.aaEngageRange + speed * AIM_TIME
   
   local myLoc = this:getLocation3D()
   local targetLoc = s.target:getLocation3D()
   local range = myLoc:distanceToLocation3D(targetLoc)
   
   if range < s.approachDistance then
      if DEBUG_DETAIL then
         printDebug(string.format("%.3f Too close to turn, aim and shoot.",
            vrf:getSimulationTime()))
      end
      return true
   else
      local descendRate = this:getParameter("max-climb-rate")
      if descendRate > 0 then
         local descendTime = (myLoc:getAlt() - targetLoc:getAlt())/descendRate
         s.approachDistance = speed * descendTime
         if range < s.approachDistance then
            if DEBUG_DETAIL then
               printDebug(string.format(".3f Too close to match altitude before shooting.",
                  vrf:getSimulationTime()))
            end
            return true
         else
            return false
         end
      else
         return true
      end
   end
end

function farEnough(s)
   local myLoc = this:getLocation3D()
   local targetLoc = s.target:getLocation3D()
   local range = myLoc:distanceToLocation3D(targetLoc)
   
   return range > s.approachDistance
end

function belowMinAltitude(s)
   local agl = this:getHeightAboveTerrain()
   -- TMP
   printDebug("AGL: ", agl)
   
   local below =  agl < MINIMUM_ALTITUDE
   if below then
      printVerbose("Below minimum altitude; aborting task (altitude AGL ",
      agl, ")")
   end
   return below
end

function atAimDistance(s)
   local myLoc = this:getLocation3D()
   local targetLoc = s.target:getLocation3D()
   
   local myToTarget = myLoc:vectorToLoc3D(targetLoc)
   local isInFront = myToTarget:dotVector3D(this:getDirection3D()) > 0
   if isInFront then
      local range = myLoc:distanceToLocation3D(targetLoc)
      local mySpeed = this:getSpeed()
      myToTarget = myToTarget:getUnit()
      local targetRelativeSpeed = s.target:getVelocity3D():dotVector3D(
         myToTarget)
      local aimDistance = (mySpeed - targetRelativeSpeed) * AIM_TIME
      local decelDistance = (mySpeed * mySpeed - targetRelativeSpeed * targetRelativeSpeed)/
         (2 * DECELERATION)
      local prepDistance = math.max(aimDistance, decelDistance)
      if DEBUG_DETAIL then
         printDebug(string.format(
            "%.3f At aim distance? Speed %.1f, targ rel spd %.1f, prep dist %.1f, range %.1f",
            vrf:getSimulationTime(), mySpeed, targetRelativeSpeed,
            prepDistance, range))
      end
      return range < s.aaEngageRange + prepDistance
   else
      return false
   end
end

function atShootDistance(s)
   local myLoc = this:getLocation3D()
   local targetLoc = s.target:getLocation3D()
   local range = myLoc:distanceToLocation3D(targetLoc)
   if DEBUG_DETAIL and
      range < s.aaEngageRange then
      printDebug("  At shoot distance, speed ", this:getSpeed()/KNOTS_TO_MPS, " knots")
   end
   return range < s.aaEngageRange
end

function targetAcquired(s)
-- If using actual visual sensor:
--   local info = this:getContactInfo(s.target)
--~    if info ~= nil then
--~       if DEBUG_DETAIL then
--~          printDebug("  Target acq level ", info.detectionLevel)
--~       end
--~       return info.detectionLevel >= MIN_CID_LEVEL
   local targetSig = this:targetSignature(s.target, "visual")
   if DEBUG_DETAIL then
      printDebug("Target visual signature ", targetSig)
   end
   if targetSig >= SIGNATURE_THRESHOLD then
      return true
   else
      return false
   end
end

function atBreakOffDistance(s)
   local myLoc = this:getLocation3D()
   local targetLoc = s.target:getLocation3D()
   local myToTarget = myLoc:vectorToLoc3D(targetLoc)
   local isInFront = myToTarget:dotVector3D(this:getDirection3D()) > 0
   local range = myLoc:distanceToLocation3D(targetLoc)
   if DEBUG_DETAIL then
      printDebug(string.format("  At breakoff? In front? %s, Range %.1f, breakoff R %.1f",
         tostring(isInFront), range, s.aaBreakOffRange))
   end
   return range < s.aaBreakOffRange or
      (range < s.aaEngageRange and not isInFront)
end

---------------------------------------------------------------------
-- Action functions and supporting utilities:

function noOp(s)
end

function startMoveAway(s)
    local myLoc = this:getLocation3D()
   local targetLoc = s.target:getLocation3D()
   local myToTarget = myLoc:vectorToLoc3D(targetLoc)
   local isInFront = myToTarget:dotVector3D(this:getDirection3D()) > 0
   local goalHeading, turnDirection
   if isInFront then
      goalHeading = s.target:getHeading() + math.pi
      local onRight = myToTarget:crossVector3D(this:getDirection3D()):dotVector3D(Vector3D(0, 0, 1)) < 0
      if onRight then
         turnDirection = -1 -- left turn
      else
         turnDirection = 1 -- right turn
      end
   else
      goalHeading = myToTarget:getBearing() + math.pi
      turnDirection = 0 --closest direction
   end
   s.taskId = vrf:startSubtask("fly-heading-and-altitude",
      {heading= goalHeading,
      turn_rate = 0.8,
      turn_direction = turnDirection,
      altitude = targetLoc:getAlt(),
      climb_descent_rate = this:getParameter("max-climb-rate")})
   vrf:executeSetData("set-speed", 
      {speed = this:getParameter("ordered-speed")})
   printVerbose(string.format("%.3f Moving away from target.",
      vrf:getSimulationTime()))
end

function startFlyingTowards(s)
   local myLoc = this:getLocation3D()
   local targetLoc = s.target:getLocation3D()
   local range = myLoc:distanceToLocation3D(targetLoc)
   local mySpeed = this:getSpeed()
   local targetSpeed = s.target:getSpeed()
   local goalSpeed = targetSpeed + SHOOTING_RELATIVE_SPEED * KNOTS_TO_MPS
   if goalSpeed < this:getParameter("ordered-speed") then
      goalSpeed = this:getParameter("ordered-speed")
   end
   if mySpeed < goalSpeed then      
      vrf:executeSetData("set-speed", {speed = goalSpeed})
      printVerbose(string.format("   Increasing speed to %.1f knots", 
         goalSpeed / KNOTS_TO_MPS))
   end
   printVerbose(string.format("%.3f Starting to fly toward %s", 
      vrf:getSimulationTime(), s.target:getName()))
   s.taskId = vrf:startSubtask("crash-into", {target = s.target})
-- If using real visual sensor:
--   s.visualSensor:setAttribute("types-to-detect-for-task", s.targetType)
end

function prepareToShoot(s)
   printVerbose(string.format("%.1f Preparing to shoot.", vrf:getSimulationTime()))
   local mySpeed = this:getSpeed()
--~    local targetRelativeSpeed = s.target:getVelocity3D():dotVector3D(
--~       this:getDirection3D())
--~    local goalSpeed = targetRelativeSpeed + SHOOTING_RELATIVE_SPEED * KNOTS_TO_MPS
   local targetSpeed = s.target:getSpeed()
   local goalSpeed = targetSpeed + SHOOTING_RELATIVE_SPEED * KNOTS_TO_MPS
   goalSpeed = math.max(goalSpeed, MINIMUM_AIRSPEED * KNOTS_TO_MPS)
   printVerbose(string.format("   Reducing speed to %.1f knots",
      goalSpeed / KNOTS_TO_MPS))
   vrf:executeSetData("set-speed", {speed = goalSpeed})
end

function startShooting(s)
   printVerbose(string.format("%.3f Firing at target",
      vrf:getSimulationTime()))
   s.shootingTaskId = vrf:startSubtask("fire-at-target",
      {auto_select_weapon = false,
      weapon_to_fire = _gunName,
      target = s.target})  
   s.timeOfFire = vrf:getSimulationTime()
end

function startBreakOff(s)
   printVerbose(string.format("%.3f Breaking off engagement",
      vrf:getSimulationTime()))
   vrf:stopSubtask(s.taskId)
   s.taskId = vrf:startSubtask("fly-heading-and-altitude",
      {altitude = this:getLocation3D():getAlt() + 200.0,
      heading = s.target:getHeading() + math.pi,
      turn_rate = 0.8})
   vrf:executeSetData("set-speed",
      {speed = this:getParameter("ordered-speed")})
-- If using real visual sensor:
--   s.visualSensor:setAttribute("clear-types-to-detect", true)
end

function exitTask(s)
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
-- separating -- Fly away from target before starting pursuit approach
-- approaching -- Start flying pursuit approach, i.e. toward target.
-- aiming -- Continue flying toward target, but slow to a speed a little
--           higher than target
-- shooting -- Continue flying toward target, and start shooting
-- breaking-away -- Fly away from target's heading, and gain altitude
-- done

-- If the AC starts very close to target, move away first.
taskFSM:addTransition("start", tooClose, "separating", startMoveAway)
taskFSM:addTransition("start", isTrue, "approaching", startFlyingTowards)

taskFSM:addTransition("separating", farEnough, "approaching", startFlyingTowards)

taskFSM:addTransition("approaching", targetDestroyed, "breaking-away", startBreakOff)
taskFSM:addTransition("approaching", belowMinAltitude, "breaking-away", startBreakOff)
taskFSM:addTransition("approaching", atAimDistance, "aiming", prepareToShoot)

taskFSM:addTransition("aiming", targetDestroyed, "breaking-away", startBreakOff)
taskFSM:addTransition("aiming", belowMinAltitude, "breaking-away", startBreakOff)
taskFSM:addTransition("aiming", atBreakOffDistance, "breaking-away", startBreakOff)
taskFSM:addTransition("aiming", function (s) return atShootDistance(s) and
                                                   targetAcquired(s) end, 
                                 "shooting", startShooting)

taskFSM:addTransition("shooting", shootingTaskFinished, "aiming", startShooting)

taskFSM:addTransition("breaking-away", taskFinished, "done", exitTask)


--###########################################################################

-- Called each tick while this task is active.
function tick()
   if _initErr then
      vrf:endTask(false)
      return
   end
   taskFSM:tick(_state)
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
