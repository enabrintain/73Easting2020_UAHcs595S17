-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

local ACTIVE_SONOBUOY_TYPE = "9:4:225:10:77:1:1"
local PASSIVE_SONOBUOY_TYPE = "9:4:225:11:77:1:1"

function sonobuoyResourceName()
	local resources = this:getResourceNames()
	for i, r in ipairs(resources) do
		if (string.find(r, "|sonobuoy")) then return r end			
	end
	return nil
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.1)
   sonobuoyResource = sonobuoyResourceName()
   if (sonobuoyResource == nil) then
      printWarn(vrf:trUtf8("No sonobuoy resource found"))
      vrf:endTask(false)
   else
      local amount = this:getResourceAmounts (sonobuoyResource)
      if (amount < 1) then
         printWarn(vrf:trUtf8("No sonobouys remaining."))
         vrf:endTask(false)
      end
   end
end

-- Called each tick while this task is active.
function tick()
   local deployAltitude, isValid = vrf:getTerrainAltitude(this:getLocation3D():getLat(), this:getLocation3D():getLon())
   if (isValid) then
      local deployLoc = this:getLocation3D()
      deployLoc:setAlt(0)
      local buoyType = nil
      local activeModeToUse = "first-active-mode"
      if (taskParameters.sonarType == 0) then
         buoyType = ACTIVE_SONOBUOY_TYPE
	 activeModeToUse="search-mode"
      else
         buoyType = PASSIVE_SONOBUOY_TYPE
         --If we're using a passive sonobuoy, it shouldn't have an active sensor anyway, but in case it does,
         --set it to inactive.
         activeModeToUse = "off" 
      end
      local buoyEntity = vrf:createEntity({entity_type=buoyType,location=deployLoc})
      vrf:sendSetData(buoyEntity, "set-sonar-depth", {depth=taskParameters.sonarDepth, use_entity_depth=false})
      vrf:sendSetData(buoyEntity, "set-active-sonar-sensor-mode", {active_sonar_sensor_mode=activeModeToUse})
      local receivers = {this}
      vrf:sendSetData(buoyEntity, "set-spot-reporting-request", {spot_reporting_turned_on=2, 
         spot_reporting_receivers=receivers, use_global_receivers=false})
      vrf:endTask(true)
      this:depleteResource(sonobuoyResource, 1)
   end
   --printInfo(vrf:trUtf8("Waiting for terrain data to be available"))
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