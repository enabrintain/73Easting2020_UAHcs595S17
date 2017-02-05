-- This script runs on a torpedo launcher and on a torpedo; it launches
-- the torpedo from the launcher, then guides the torpedo.
-- It is "polymorphic" in that it runs on both entities.
-- If the taskParamter parentLauncheris not valid, then the
-- script assumes it is running on the entity with the launcher.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
-- Common functions for launchers
require "munitionLauncherUtils"

LAUNCHER_SYSTEM_NAME = "Homing Torpedo Capability (Forward Launched)"
MUNITION_CREATION_TIMEOUT = 10 --How long launcher waits for munition to be created

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.targetEntity Type: SimObject - The target (ship or submarine)
--  taskParameters.homingDelay Type: Real Unit: meters - Distance torpedo travels before starting to home to target.
--  taskParameters.initialBearing Type: Heading Unit: radians - Initial bearing from platform that torpedo sails before homing
--  taskParameters.cruiseDepth Type: Real Unit: meters - Torpedo cruise depth; distance below surface.
--  taskParameters.proximityTrigger Type: Real Unit: meters - Distance to target that triggers detonation.
--  taskParameters.parentLauncher Type: Simulation Object - Parent platform

taskId = -1

-- For launcher logic:
launcherSytstem = nil
startTime = vrf:getExerciseTime()

-- For torpedo logic:
depthTaskId = -1
moveTaskId = -1
initialPosition = nil
torpedoCruiseSpeed = 0
waterElev = 0
torpedoState = "unguided-phase"

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)

   if (taskParameters.parentLauncher == nil or
       taskParameters.parentLauncher == "-" or
       not taskParameters.parentLauncher:isValid()) then
   
        -- Launcher---------------------------------
      
      --Finds the system and tells it to create a munition.
      --Aborts the task if there is an error.
      launcherSystem = launcherInit(LAUNCHER_SYSTEM_NAME)
   else
   
        -- Torpedo------------------------------------
        
       -- Start with active sonar off
      vrf:executeSetData("set-active-sonar-sensor-mode", 
         {active_sonar_sensor_mode = "off"})
         
        -- Initial unguided heading
      local initialHeading = taskParameters.initialBearing
      local parentPlatform = taskParameters.parentLauncher
      if not parentPlatform:isValid() then 
         printWarn ("Parent launcher not valid.")
         intialHeading = initialHeading + this:getHeading()
      else
         initialHeading = initialHeading + parentPlatform:getHeading()
      end      
      moveTaskId = vrf:startSubtask("turn-move-sail-heading",
         {finalHeading = initialHeading})
      if moveTaskId == -1 then
         printWarn(vrf:trUtf8("Could not start sail heading task"))
         vrf:endTask(false)
      end
      
      -- Initial position for testing end of unguided phase
      initialPosition = this:getLocation3D()
      -- Remember ordered speed during re-attack
      torpedoCruiseSpeed = this:getParameter("ordered-speed")
      
         -- Go to given depth
      depthTaskId = vrf:startSubtask("goto-depth",
         {depthType = 4,
         goalDepth = taskParameters.cruiseDepth})
      if depthTaskId == -1 then
         printWarn(vrf:trUtf8("Could not start goto-depth task"))
         vrf:endTask(false)
      end
      printDebug("Torpedo initialized")
    end
end

-- Called each tick while this task is active.
function tick()
   if (launcherSystem ~= nil) then
   
    -- Launcher *********************************************************************
    
      --This function will exit if it successfully tasks the munition
      --or abort if there is an error or the timeout expires
      launcherTaskMunition(launcherSystem, vrf:getScriptId(),
         startTime, MUNITION_CREATION_TIMEOUT)

   else

    -- Torpedo *******************************************************************
    
      if torpedoState == "unguided-phase" then
         if initialPosition:distanceToLocation3D(this:getLocation3D()) >
            taskParameters.homingDelay then
         
            torpedoState = "guided-phase"
            printDebug("Switching to guided phase")
            vrf:stopSubtask(moveTaskId)
            
            -- Turn sonar on
            vrf:executeSetData("set-active-sonar-sensor-mode", 
               {active_sonar_sensor_mode = "search-mode"})
               
               -- Set warhead data if possible
            if taskParameters.targetEntity:isValid() then
               local Id = vrf:executeSetData("set-warhead-info",
                  {target_name = taskParameters.targetEntity,
                   detonation_proximity = taskParameters.proximityTrigger})
               if Id == -1 then
                  printWarn(vrf:trUtf8("Could not set warhead target name and proximity"))
                  --vrf:endTask(false)
               end
            end
            
	         -- Move toward target (...if none, snake search?)
            if taskParameters.targetEntity:isValid() then
               moveTaskId = vrf:startSubtask("move-to",
                  {control_point = taskParameters.targetEntity,
                  continue_moving_flag = true})
               if moveTaskId == -1 then
                  printWarn(vrf:trUtf8("Could not start move-to task to track target"))
                  vrf:endTask(false)
               end
            end
         end
      else -- torpedo is in guided phase
         if taskParameters.targetEntity:isValid() and taskDone(moveTaskId) then
	         printDebug("Torpedo passed target; circling back")
            -- Must have missed; circle back
            local vectToTarget = this:getLocation3D():vectorToLoc3D(
               taskParameters.targetEntity:getLocation3D())
            local x = vectToTarget:getEast()
            local y = vectToTarget:getNorth()
            local horizDist = math.sqrt(x*x + y*y)
            if horizDist < 1000.0 then -- If close, slow down to make sharper turn
               local setId = vrf:sendSetData(this, "set-speed", 
               {speed = torpedoCruiseSpeed / 2.0})
            else
               local setId = vrf:sendSetData(this, "set-speed",
               {speed = torpedoCruiseSpeed})
            end
            moveTaskId = vrf:startSubtask("move-to",
               {control_point = taskParameters.targetEntity,
               continue_moving_flag = true})
            if moveTaskId == -1 then
               printWarn(vrf:trUtf8("Could not start move-to task to track target"))
               vrf:endTask(false)
            end
	    
         end
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
--   sender is the SimObject which sent the message.

function receiveTextMessage(message, sender)

end
