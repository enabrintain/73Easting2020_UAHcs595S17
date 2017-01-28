-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

local TAXI_SPEED = 1.5 -- In m/s
local LAUNCH_PAUSE_TIME = 15 -- time in seconds after reaching catapult, before launch

local HOLD_PATTERN_PT_FORWARD = 3000
local HOLD_PATTERN_PT_RIGHT = 3000

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
subtaskId = -1
taskState = ""
flyingSpeed = 0 -- Save the ordered speed for flying and restore after taxiing
routePoints = {}
catapultPoints = {}
launchHeading = 0
launchTime = 0 -- Time that the launch pause expires
carrierLocation = nil
carrierDirection = nil
gearUp = false

-- Task Parameters Available in Script
--  taskParameters.catapult Type: SimObject - The 2-point route that models the catapult track.
--  taskParameters.route Type: SimObject - Create a route to a point close to the destination.

-- Called when the task first starts. Never called again.
function init()
   taskState = "start"
   flyingSpeed = this:getParameter("ordered-speed")
   catapultPoints = taskParameters.catapult:getLocations3D()
   local launchVector = catapultPoints[1]:vectorToLoc3D(
      catapultPoints[2])
   launchHeading = launchVector:getBearing()
   carrierLocation = Location3D(0, 0, 0)
   carrierDirection = Vector3D(1.0, 0.0, 0.0)
end

-- Called each tick while this task is active.
function tick()
   if taskState == "start" then
      if taskParameters.route:isValid() then
         subtaskId = vrf:startSubtask("Taxi_To_On_Carrier", 
            {destinationPoint = catapultPoints[1],
            route = taskParameters.route,
            assumeHeading = true,
            finalHeading = launchHeading})
      else
         subtaskId = vrf:startSubtask("Taxi_To_On_Carrier", 
            {destinationPoint = catapultPoints[1],
            assumeHeading = true,
            finalHeading = launchHeading})      
      end
      
      taskState = "move to catapult"
   elseif taskState == "waiting for launch" then
   
      if vrf:getSimulationTime() > launchTime then
                  subtaskId = vrf:startSubtask("Fixed_Wing_Takeoff", 
            {runway = taskParameters.catapult})
         taskState = "taking off"
         if subtaskId == -1 then
            DtWarn("Could not start takeoff task.")
            vrf:endTask(false)
         end
      end
      
   elseif taskDone(subtaskId, true) then
   
      if taskState == "move to catapult" then
         launchTime = vrf:getSimulationTime() + 
            LAUNCH_PAUSE_TIME
         taskState = "waiting for launch"
         subtaskId = -1
      elseif taskState == "taking off" then
         if taskParameters.doHold then
            local offsetVector = VectorOffset3D(
               HOLD_PATTERN_PT_RIGHT, HOLD_PATTERN_PT_FORWARD, 
               taskParameters.holdAltitude)
            local vecToHoldPoint = offsetVector:makeVectorRefToDirection(
               carrierDirection)
            local holdPoint = carrierLocation:addVector3D(
               vecToHoldPoint)
            
            subtaskId = vrf:startSubtask("AircraftHold",
               {fixPoint = holdPoint,
               heading = carrierDirection:getBearing(),
               speed = flyingSpeed,
               altitude = taskParameters.holdAltitude,
               direction = 0}) -- Right turns 
         else
            vrf:endTask(true)
         end
      end
   elseif taskState == "taking off" and
      gearUp == false then
      -- This code could be eliminated when the takeoff is from a carrier on which
      -- the plane was embarked; the take-off task does this automatically
      local catVector = catapultPoints[1]:vectorToLoc3D(catapultPoints[2])
      local acVector = this:getLocation3D():vectorToLoc3D(catapultPoints[2])
      local dotProd = catVector:dotVector3D(acVector)
      if dotProd < 0.0 then
         landingGearUp()
         gearUp = true
      end
   end
   
end
      
function landingGearUp()
	-- Move the articulated part if this entity has a langergear actuator on it.
	if (_G["landinggear"] ~= nil) then
		landinggear:close()
	end
	-- Set the landing lights appearance bit to off (some models key their landing gear off this bit)
	local a = Appearance.SetLandingLights(this:getAppearance(), false)
	vrf:executeSetData("set-appearance", {appearance = a})
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
   vrf:executeSetData("set-speed", {speed = flyingSpeed})
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
