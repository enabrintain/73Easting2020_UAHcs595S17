-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.naval_depth_charge Type: String (resource name)
--  taskParameters.explode_at_depth Type: Real Unit: meters


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called to get the location to drop the mine from
function mineDropLocation()
   if (vrf:entityTypeMatches(this:getEntityType(), EntityType.PlatformSurface())) then
      local mineStart = this:getLocation3D()
      boundingVolume = this:getBoundingVolume()
      offset = Vector3D(-(boundingVolume:getForward() / 2 + 2), 0, -(boundingVolume:getUp() / 2))
            
      return mineStart:addVector3D(offset)
   elseif (vrf:entityTypeMatches(this:getEntityType(), EntityType.PlatformSubsurface())) then
      mineStart = this:getLocation3D()
      boundingVolume = this:getBoundingVolume()
      offset = Vector3D(0, 0, -(boundingVolume:getUp() / 2))

      return mineStart:addVector3D(offset)
   else
      mineStart = this:getLocation3D()
      
      -- start a bit below the launching entity so it doesn't explode on release
      mineStart:setAlt(mineStart:getAlt() - 2)

      return mineStart
   end
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   if (this:getResourceAmounts(taskParameters.naval_depth_charge) > 0) then
      this:depleteResource(taskParameters.naval_depth_charge, 1)
      mineStart = mineDropLocation()
      navalMine = vrf:createEntity({entity_type=this:getMunitionType(taskParameters.naval_depth_charge), location=mineStart})
      
      if (navalMine == nil) then
         printWarn(vrf:trUtf8("Could not create naval depth charge of type %1"):arg(this:getMunitionType(taskParameters.naval_depth_charge)))
      else
         vrf:sendTask(navalMine, "Explode_Charge_At_Depth", {explode_at_depth=taskParameters.explode_at_depth}, false)
      end
   else
      print("Entity does not have enough resources of type ", taskParameters.naval_depth_charge)
   end
   vrf:endTask(true)
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