-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

local DEBUG = false

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.naval_mine Type: String (resource name)
--  taskParameters.mine_depth Type: Real Unit: meters
--  taskParameters.arm_time Type: Integer Unit: seconds - Amount of time after reaching final depth to arm the mine


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called to get the location to drop the mine from
function mineDropLocation()
   if (vrf:entityTypeMatches(this:getEntityType(), EntityType.PlatformSurface())) then
      local mineStart = this:getLocation3D()
      local boundingVolume = this:getBoundingVolume()
      local bodyOffset = VectorOffset3D(0, -(boundingVolume:getForward() / 2 + 2), -(boundingVolume:getUp() / 2))
      local direction = this:getDirection3D()
      local offset = bodyOffset:makeVectorRefToDirection(direction)
      return mineStart:addVector3D(offset)
   elseif (vrf:entityTypeMatches(this:getEntityType(), EntityType.PlatformSubsurface())) then
      local mineStart = this:getLocation3D()
      local boundingVolume = this:getBoundingVolume()
      local bodyOffset = VectorOffset3D(0, 0, -(boundingVolume:getUp() / 2))
      local direction = this:getDirection3D()
      local offset = bodyOffset:makeVectorRefToDirection(direction)

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
   if (this:getResourceAmounts(taskParameters.naval_mine) > 0) then
      mineStart = mineDropLocation()
      this:depleteResource(taskParameters.naval_mine, 1)
      navalMine = vrf:createEntity({entity_type=
         this:getMunitionType(taskParameters.naval_mine), location=mineStart})
      
      if (navalMine == nil) then
         printWarn("Could not create naval mine of type ", this:getMunitionType(taskParameters.naval_mine))
      else
         if DEBUG then 
            printWarn(string.format("Creating mine at location (%f, %f, %f)",
               math.deg(mineStart:getLat()),
               math.deg(mineStart:getLon()),
               mineStart:getAlt()))
         end
         vrf:sendTask(navalMine, "Arm_Mine_At_Depth", {mine_depth=taskParameters.mine_depth,
	       explode_within_radius=taskParameters.explode_within_radius,
	       arm_time=taskParameters.arm_time,
	       targets=taskParameters.targets,
	       hostile_only=taskParameters.hostile_only}, false)
      end
   else
      printWarn("Entity does not have enough resources of type ", taskParameters.naval_mine)
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