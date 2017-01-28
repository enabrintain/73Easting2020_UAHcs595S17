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

mySubtaskId = -1
myState = 0
myCanDrop = false
myMovementSystem = nil
noMinesWarningPrinted = false

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

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(-1)
   myMovementSystem = this:getSystem("movement")
   if not myMovementSystem then
      printWarn("Movement system not found-- exiting task")
      vrf:endTask(false)
   else
      if DEBUG then 
         printWarn("Found movement system ", 
            myMovementSystem:getName())
         printWarn("Dropping mines every ", 
            taskParameters.drop_every)
      end
   end
end

-- Called to drop a mine.  If no mines left to drop after the mine is dropped task is complete
function dropMine()
   local mineStart = mineDropLocation()
   this:depleteResource(taskParameters.naval_mine, 1)
   local navalMine = vrf:createEntity({entity_type=
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
   myLastDropPoint = this:getLocation3D()
end

function distance2D(point1, point2)
   local p1 = point1:makeCopy()
   p1:setAlt(point2:getAlt())
   
   return p1:distanceToLocation3D(point2)
end

-- Called each tick while this task is active.
function tick()
   if (mySubtaskId == -1) then
      mySubtaskId = vrf:startSubtask("move-along", {route=taskParameters.drop_along_route})
      myState = 1
   elseif (vrf:isSubtaskRunning(mySubtaskId)) then
   -- Don't start dropping until we are near the drop point start'
      if (this:getResourceAmounts(taskParameters.naval_mine) == 0) then
         if not noMinesWarningPrinted then
            printWarn("Out of mines.")
--  Keep flying route          vrf:endTask(false) 
            noMinesWarningPrinted = true
         end
      elseif (not myCanDrop) then
         local nextRouteVertex = myMovementSystem:getAttribute(
            "next-route-point-index")
         if (nextRouteVertex > 0) then
            myCanDrop = true
            if DEBUG then printWarn("Dropping first mine") end
            dropMine()
         end
      else
         local distance = distance2D(myLastDropPoint, this:getLocation3D())
         if (distance > taskParameters.drop_every) then
            if DEBUG then 
               printWarn(string.format("%.3f Dropping mine",
                  vrf:getSimulationTime()))
            end
            dropMine() -- resets myLastDropPoint
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
