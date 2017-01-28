require "vrfutil"

-- Cached value of the last detected terrain type.
last_terrain = ""

function init()
   -- Increase or decrease to change detection resolution for faster/slower entities.
   vrf:setTickPeriod(0.1)
end

-- Called each tick while this task is active.
function tick()
   
   loc = this:getLocation3D()
   ent_lat = loc:getLat()
   ent_lon = loc:getLon()
   
   elev, valid, terrain_type = vrf:getTerrainAltitude(ent_lat, ent_lon)
   
   if not valid then
      -- If this happens, you're going to have a bad time.
      printWarn(vrf:trUtf8("Invalid terrain intersection."))
   elseif not (terrain_type == last_terrain) then
      last_terrain = terrain_type
      printDebug("Elevation: "..elev..".")
      printWarn(vrf:trUtf8("Now on terrain type: %1"):arg(terrain_type))
   end
   
   -- This task never ends and must be explicitly stopped by the user.
   -- vrf:endTask(true)
end


function suspend()
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
end

function resume()
   -- Default, simply call init() to start the task over.
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
