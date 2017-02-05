-- This script runs on a torpedo launcher and on a torpedo; it launches
-- the torpedo from the launcher, then guides the torpedo.
-- It is "polymorphic" in that it runs on both entities.
-- If the taskParamter parentLauncher (a name) is "-", then the
-- script assumes it is running on 

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "munitionLauncherUtils"

LAUNCHER_SYSTEM_NAME = "Anti-Submarine Missile (Vertically Launched)"
MUNITION_CREATION_TIMEOUT = 10 --How long launcher waits for munition to be created

-- For missile:
LAUNCH_ALTITUDE = 50.0 -- Missile goes up this far before transitioning to cruise
MISSILE_CRUISE_ALTITUDE = 100.0

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.targetEntity Type: SimObject - The target (ship or submarine)
--  taskParameters.dropLocation Type: Location3D Unit: Where the torpedo should be dropped
--  taskParameters.parentLauncher Type: String - Parent platform

taskId = -1

-- For launcher logic:
launcherSytstem = nil
startTime = vrf:getExerciseTime()

-- For missile logic:
startLocation = nil
flyoutDistance = 0
targetHeading = 0
missileTaskId = -1
missileState = "launch"

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
      
--~       
--~       launcherSystem = this:getSystem(LAUNCHER_SYSTEM_NAME)
--~       if (not launcherSystem) then
--~          printWarn ("Error: unable to find ", LAUNCHER_SYSTEM_NAME)
--~          vrf:endTask(false)
--~       else
--~          -- Causes launcher to create missile:
--~          local error = launcherSystem:setAttribute("launch-munition", true)
--~          if error then
--~             printWarn(vrf:trUtf8("Error: unable to launch munition; launcher set-attribute error."))
--~             vrf:endTask(false)
--~          else
--~             printInfo(vrf:trUtf8("Launching ASW missile"))
--~             startTime = vrf:getExerciseTime()
--~          end
--~       end
   else
        -- ASW missile------------------------------------
        
      startLocation = this:getLocation3D()
      local flyoutVector = startLocation:vectorToLoc3D(
         taskParameters.dropLocation)
      flyoutVector:setNorthEastDown(flyoutVector:getNorth(),
         flyoutVector:getEast(), 0.0)
      flyoutDistance = flyoutVector:getRange()
      
      targetHeading = flyoutVector:getBearing()
   end
end

-- Called each tick while this task is active.
function tick()
   if (launcherSystem ~= nil) then
   
    -- Launcher *********************************************************************      
      
      --This function will exit if it successfully tasks the munition
      --and abort if there is an error or the timeout expires
      launcherTaskMunition(launcherSystem, vrf:getScriptId(),
         startTime, MUNITION_CREATION_TIMEOUT)

--~       --The munition should be created immediately, but check that the name returned
--~       --by the launcher is valid just to be sure. When it is valid, send the munition
--~       --this same task, but with the parent name filled in. If no valid munition is
--~       --returned after a threshold time, give up and exit.
--~       local missileName
--~       local errorFlag
--~       missileName, errorFlag = launcherSystem:getAttribute("launched-munition-name")
--~       if not errorFlag then
--~          printDebug("ASW missile name: ", missileName)
--~          local missile = vrf:getSimObjectByName(missileName)
--~          if missile:isValid() then
--~ 	         local missileParams = table.copy(taskParameters)
--~ 	         missileParams.parentLauncher = this
--~             taskId = vrf:sendTask(missile, vrf:getScriptId(), 
--~ 	             missileParams,
--~                 false) -- Last argument allows torpedo task to run even when launcher task exits
--~             vrf:endTask(true)
--~          end
--~       end
--~       if vrf:getExerciseTime() - startTime > MUNITION_CREATION_TIMEOUT then
--~          printWarn(vrf:trUtf8("Error: launcher could not create missile"))
--~          vrf:endTask(false)
--~       end
   else

    -- ASW missile *******************************************************************
    
      if (missileState == "launch") then
         -- Let the missile rise to clear the ship; when this happens,
         -- start it on its way to the target location.
         if this:getLocation3D():getAlt() > LAUNCH_ALTITUDE then
            missileTaskId = vrf:startSubtask("fly-heading-and-altitude", 
               {heading = targetHeading,
                turn_rate = 1.6,
                altitude = MISSILE_CRUISE_ALTITUDE})
            if missileTaskId == -1 then
               printWarn(vrf:trUtf8("Could not start fly-heading task"))
               vrf:endTask(false)
            end
            missileState = "flyout"
         end
      elseif (missileState == "flyout") then
         -- When the missile has flown as far as the target location,
         -- start a launch-torpedo task, which creates a torpedo and
         -- gives it a program.
         local flyoutVector = startLocation:vectorToLoc3D(this:getLocation3D())
         flyoutVector:setNorthEastDown(flyoutVector:getNorth(),
            flyoutVector:getEast(), 0.0)
         local flightProgress = flyoutVector:getRange()
         if (flightProgress > flyoutDistance) then
            -- Launch torpedo
            taskId = vrf:startSubtask("Delayed_homing_ASW",
               {targetEntity = taskParameters.targetEntity,
               homingDelay = 10,
               initialBearing = 0,
               parentLauncher = ""})
            if (taskId == -1) then
               printWarn(vrf:trUtf8("Missile unable to perform torpedo launch task"))
               vrf:endTask(false)
            end
            missileState = "torpedo"
         end
      elseif (missileState == "torpedo") then
         -- Make sure the torpedo entity has been created, then self-delete
         if taskDone(taskId) then
            vrf:deleteObject(this)
            vrf:endTask(true)
         end
      else
         printWarn(vrf:trUtf8("Illegal missile task state"))
         vrf:endTask(false)
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
