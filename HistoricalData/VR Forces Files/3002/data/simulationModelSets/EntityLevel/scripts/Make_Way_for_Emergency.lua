-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
myPullingOverState = "onRoad"
mySubtaskId = 0

-- Task Parameters Available in Script

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5) 
end

-- Returns true if there are emergency vehicles nearby with their lights flashing.
function emergencyVehiclesNearby()

   -- Find nearby police cars, fire engines, and ambulances (that are not us)
   local nearbyEntities = vrf:getSimObjectsNearWithFilter(
      this:getLocation3D(), 50,
      {types={"1:1:225:27:0:0:2", "1:1:225:27:0:0:3", "1:1:225:27:0:0:6"}, ignore={this}})
   
   for entityNum,entity in pairs(nearbyEntities) do
	 
      -- Check if the lights are on. We're using spot lights as a substitute for
      -- flashing lights and sirens. If our own lights/sirens are on, don't pull over.
      local appearance = entity:getAppearance()
      local ownAppearance = this:getAppearance()
      if(Appearance.SpotLightsOn(appearance) and
         not (Appearance.SpotLightsOn(ownAppearance))) then         
         -- There is a nearby emergency vehicle	    
         return true
      end
   end
   
   return false
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   -- Returning true will cause the reactive task to become active and will call init()
   -- and tick() until the task completes.
   
   return emergencyVehiclesNearby()
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0)
   
   myPullingOverState = "onRoad"
end

-- Called each tick while this task is active.
function tick()

   if( myPullingOverState == "onRoad" ) then
   
      myPullingOverState = "pullingOver"
      
      mySubtaskId = vrf:startSubtask("animated-movement-task", 
         {animation_model="Pull Over"})
	 
   elseif( myPullingOverState == "pullingOver" ) then
      
      if( vrf:isSubtaskComplete(mySubtaskId) ) then
         myPullingOverState = "pulledOver"
      end
   
   elseif( myPullingOverState == "pulledOver" ) then
   
      if( not (emergencyVehiclesNearby()) ) then
         myPullingOverState = "pullingIn"
      
         mySubtaskId = vrf:startSubtask("animated-movement-task", 
            {animation_model="Pull In"})	     
      end
   
   elseif( myPullingOverState == "pullingIn" ) then

      if( vrf:isSubtaskComplete(mySubtaskId) ) then
         myPullingOverState = "onRoad"
      
         -- resume normal behavior
         vrf:endTask(true)
      end
   
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

