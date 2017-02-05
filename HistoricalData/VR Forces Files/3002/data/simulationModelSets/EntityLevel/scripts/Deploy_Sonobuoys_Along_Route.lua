-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.naval_mine Type: String (resource name)
--  taskParameters.mine_depth Type: Real Unit: meters
--  taskParameters.arm_time Type: Integer Unit: seconds - Amount of time after reaching final depth to arm the mine

mySubtaskId = -1
myState = 0
myCanDrop = false
myMovementSystem = nil

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(-1)
   myMovementSystem = this:getSystem("movement")
   if not myMovementSystem then
      vrf:endTask(false)
   end
end

-- Called to get the location to drop the mine from
function sonobuoyDropLocation()
  dropLocation = this:getLocation3D()
  dropLocation:setAlt(0)
  return dropLocation
end
-- Called to drop a mine.  If no mines left to drop after the mine is dropped task is complete
function deploySonobuoy(location)
   vrf:startSubtask("Deploy_Sonobuoy", {sonarType = taskParameters.sonarType, sonarDepth = taskParameters.sonarDepth})
   myLastDropPoint = this:getLocation3D()
end

function distance2D(point1, point2)
   point1:setAlt(0)
   point2:setAlt(0)
   
   return point1:distanceToLocation3D(point2)
end

function sonobuoyResourceName()
	local resources = this:getResourceNames()
	for i, r in ipairs(resources) do
		if (string.find(r, "|sonobuoy")) then return r end			
	end
	return nil
end

-- Called each tick while this task is active.
function tick()
   local bufferZone = 20
   
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   if (mySubtaskId == -1) then
      mySubtaskId = vrf:startSubtask("move-along", {route=taskParameters.route})
      myState = 1
   elseif (vrf:isSubtaskRunning(mySubtaskId)) then
   -- Don't start dropping until we are near the drop point start'
      if (this:getResourceAmounts(sonobuoyResourceName()) == 0) then
         printWarn("Out of sonobuoy resources.  Stopping task")
	      vrf:endTask(false)
      elseif (not myCanDrop) then
         local nextRouteVertex = myMovementSystem:getAttribute(
            "next-route-point-index")
         if (nextRouteVertex > 0) then
            myCanDrop = true
            deploySonobuoy(sonobuoyDropLocation())
         end
      else
         local distance = distance2D(myLastDropPoint, this:getLocation3D())
         if (distance > taskParameters.sonobuoySpacing) then
            deploySonobuoy(sonobuoyDropLocation())
         end
      end
   elseif (vrf:isSubtaskComplete(mySubtaskId)) then
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
