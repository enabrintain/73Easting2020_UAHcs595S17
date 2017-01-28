-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.route Type: SimObject - Route to move along.
--  taskParameters.timeOnTarget Type: Integer Unit: seconds - Arrival time for the end of the route

CurrentDestinationPointIndex = 0
myMovementSystem = nil
mySubtaskId = -1
myLastOrderedSpeed = -1
myArrivingLate = false -- flag to indicate that we have already calculated that we will arrive late.
myHolding = false


-- Determine if the ideal speed (default ordered speed) would get to the end of the route too early,
-- and the plane should execute a holding pattern at the start of the route for some amount of time
-- instead of directly moving along the route.
function determineIfHoldRequired()
   local speed, distToGo, timeToGo = calculateTargetSpeedDistanceTime()
   local idealSpeed = this:getParameter("ordered-speed")
   if (idealSpeed == nil) then
      return false, 0
   end
   if (speed < idealSpeed) then
      local timeAtIdeal = distToGo / idealSpeed
      local extraTime = timeToGo - timeAtIdeal
      if (extraTime >  4*60) then  -- Only hold if there are at least 4 extra minutes
         return true, taskParameters.timeOnTarget - timeAtIdeal - 2*60
      end
   end
   return false, 0
end

function startHold(holdReleaseTime)
   local routePoints = taskParameters.route:getLocations3D()
   local holdHeading = routePoints[1]:vectorToLoc3D(routePoints[2]):getBearing()
   mySubtaskId = vrf:startSubtask("AircraftHold", {fixPoint = routePoints[1],
		heading = holdHeading, speed = this:getParameter("ordered-speed"), altitude = routePoints[1]:getAlt(),
		direction = 0, releaseTime=holdReleaseTime})
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(1.0)
   
   myMovementSystem = this:getSystem("movement")
   if not myMovementSystem then
      vrf:endTask(false)
   end
   
   local holdRequired, holdReleaseTime = determineIfHoldRequired()
   if (holdRequired) then
      startHold(holdReleaseTime)
      myHolding = true
   else
      mySubtaskId = vrf:startSubtask("move-along", {route=taskParameters.route})
   end
end

-- Return the index of the next point (current destination point) along route
function nextRoutePointIndex()
   local nextRouteVertex = myMovementSystem:getAttribute(
            "next-route-point-index")
   return nextRouteVertex
end

-- Calculate approximate distance remaining to travel.
function distanceRemaining()
  local routePoints = taskParameters.route:getLocations3D()
  local nextPointIndex = nextRoutePointIndex() + 1 -- next point starts at 0, but table starts index at 1
  local distance = 0
  for i, point in ipairs(routePoints) do
      if (nextPointIndex == i) then
         distance = this:getLocation3D():distanceToLocation3D(point)
      elseif (nextPointIndex > i) then
         -- do nothing
      else      
         distance = distance + routePoints[i-1]:distanceToLocation3D(point)
      end
  end
  return distance
end

function setDesiredSpeed(targetSpeed)
-- Only actually adjust the speed if it is more than 5% different from the previously ordered speed.
   if (targetSpeed < myLastOrderedSpeed - myLastOrderedSpeed * 0.05 or 
      targetSpeed > myLastOrderedSpeed + myLastOrderedSpeed * 0.05) then 
     vrf:executeSetData("set-speed", {speed = targetSpeed})
     myLastOrderedSpeed = targetSpeed
     printInfo(vrf:trUtf8("Adjusting speed: %1"):arg(targetSpeed))
   end
end

-- Calculate the target speed.  Also returns distance and time to go.
function calculateTargetSpeedDistanceTime()
   local distanceToGo = distanceRemaining()
   local timeToGo = taskParameters.timeOnTarget - vrf:getSimulationTime()
   if (timeToGo <= 0) then
      printWarn(vrf:trUtf8("Missed time on target."))
      timeToGo = 1.0
   end
   local targetSpeed = distanceToGo / timeToGo
   return targetSpeed, distanceToGo, timeToGo
end

-- Called each tick while this task is active.
function tick()
   if (not taskParameters.route:isValid()) then
      printWarn("Failed to find route")
      vrf:endTask(false)
   end

   if (myHolding) then
      if (not vrf:isSubtaskRunning(mySubtaskId)) then
         printInfo("Finished hold.  Proceeding along route.")
         mySubtaskId = vrf:startSubtask("move-along", {route=taskParameters.route})
	 myHolding = false
      end
      return
   end
   
   if (mySubtaskId == -1) then 
      printWarn("Failed to start move-along subtask")
      vrf:endTask(false)
   elseif (vrf:isSubtaskRunning(mySubtaskId)) then
      if (not myArrivingLate) then
	      -- Calculate and adjust speed
	      local targetSpeed, distToGo, timeToGo = calculateTargetSpeedDistanceTime()
	      
	      local maxSpeed = this:getParameter("max-speed")
	      if (maxSpeed ~= nil and maxSpeed < targetSpeed) then
	         local lateTime = distToGo / maxSpeed - taskParameters.timeOnTarget + vrf:getSimulationTime()
		 printWarn(vrf:trUtf8("Cannot reach target by specified time.  Expecting to arrive %1 seconds late."):arg(lateTime))
		 targetSpeed = maxSpeed
		 myArrivingLate = true
	      end
              setDesiredSpeed(targetSpeed)
      end
   else
      vrf:endTask(true)
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
