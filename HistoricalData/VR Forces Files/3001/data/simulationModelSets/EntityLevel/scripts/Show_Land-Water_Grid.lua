-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.sampleSpacing Type: Real Unit: meters - The horizontal and vertical spacing between sample locations in the grid.

TRP_TYPE = "16:0:0:2:0:0:0"
COORD_PT_TYPE = "16:0:0:10:0:0:0"
WATER_TYPES = {"Ocean", "DeepLake", "ShallowLake", 
   "DeepRiver","ShallowRiver", "DeepPond", "ShallowPond", "DeepStream",
   "ShallowStream", "DeepBrook", "ShallowBrook"}
UNSPECIFIED_TYPES = {"UnspecifiedBodyOfWater", "Unspecified"}

function isWater(surfaceName)
   local i, v
   for i, v in ipairs(WATER_TYPES) do
      if surfaceName == v then
         return true
      end
   end
   return false
end
   
function isUnspecified(surfaceName)
   local i, v
   for i, v in ipairs(UNSPECIFIED_TYPES) do
      if surfaceName == v then
         return true
      end
   end
   return false
end

-- Called when the task first starts. Never called again.
function init()
   local row, col
   local startLoc = this:getLocation3D()
   local vectorEast = Vector3D(0, taskParameters.sampleSpacing, 0)
   local vectorNorth = Vector3D(taskParameters.sampleSpacing, 0, 0)
   startLoc = startLoc:addVector3D(
      vectorNorth:getScaled(-4.5)):addVector3D(
      vectorEast:getScaled(-4.5))
 
   for row = 0, 9 do
      for col = 0, 9 do
         local sampleLoc = startLoc:addVector3D(
            vectorNorth:getScaled(row)):addVector3D(
            vectorEast:getScaled(col))
         
         local alt, valid, surfaceType = vrf:getTerrainAltitude(
            sampleLoc:getLat(), sampleLoc:getLon())
         if valid then
            printDebug("Surface type: ", surfaceType)
            if isWater(surfaceType) then
               vrf:createTacticalGraphic({entity_type = TRP_TYPE,
                  location = sampleLoc})
            elseif isUnspecified(surfaceType) then
               vrf:createTacticalGraphic({entity_type = TRP_TYPE,
                  location = sampleLoc})
               vrf:createTacticalGraphic({entity_type = COORD_PT_TYPE,
                  location = sampleLoc})
            else
               vrf:createTacticalGraphic({entity_type = COORD_PT_TYPE,
                  location = sampleLoc})
            end
         end
      end
   end
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
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
