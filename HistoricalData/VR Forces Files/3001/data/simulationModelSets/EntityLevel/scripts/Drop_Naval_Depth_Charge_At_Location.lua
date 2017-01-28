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

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.001)
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   if (mySubtaskId == -1) then
      local drop_location = taskParameters.drop_location
      
      -- If want to use current altitude, set drop location altitude to altitude of entity
      if (taskParameters.use_current_altitude) then
         drop_location:setAlt(this:getLocation3D():getAlt())
      end
      
      mySubtaskId = vrf:startSubtask("move-to-location", {aiming_point=drop_location})
      myState = 1
      myCurrentDistance = 1000
   elseif (vrf:isSubtaskComplete(mySubtaskId)) then
      -- Wait until we are "close enough" to the drop point to drop the mine.  If we ever move away from the last point we
      -- were closest to the location, drop as well
      if (myState == 1) then
         -- set altitude to 0 to perform 2D distance check
	 local cur = this:getLocation3D()
	 local dest = taskParameters.drop_location
	 
	 cur:setAlt(0)
	 dest:setAlt(0)

	 local distance = cur:distanceToLocation3D(dest)
	 
	 if ((distance <= 5) or (distance > myCurrentDistance)) then
	    myState = 2
	 else
	    myCurrentDistance = distance
	 end
      elseif (myState == 3) then
         vrf:endTask(true)
      end
      
      if (myState == 2) then
         if (this:getResourceAmounts(taskParameters.naval_depth_charge) > 0) then
            this:depleteResource(taskParameters.naval_depth_charge, 1)
            mySubtaskId = vrf:startSubtask("Drop_Naval_Depth_Charge", {naval_depth_charge = taskParameters.naval_depth_charge, 
	   	   explode_at_depth = taskParameters.explode_at_depth})
	         myState = 3
         else
            print("Out of resources ", taskParameters.naval_depth_charge)
            vrf:endTask(false)
         end
      end
   elseif (not vrf:isSubtaskRunning(mySubtaskId)) then
      vrf:endTask(false)
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