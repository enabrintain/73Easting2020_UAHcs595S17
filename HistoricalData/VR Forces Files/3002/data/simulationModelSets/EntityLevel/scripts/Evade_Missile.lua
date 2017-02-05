-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

myMissile = nil
myManuverSubtaskId = -1
myCountermeasuresSubtaskId = -1
myEvadedMissiles = {} -- list of missiles that have been evaded, so we don't trigger and start evading them right away

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

function expireEvadedMissiles()
	for i, m in ipairs(myEvadedMissiles) do
		if (not m:isValid()) then
			--printInfo(vrf:trUtf8("Expiring missile: %1"):arg(m:getName()))
			table.remove(myEvadedMissiles, i)
			return
		end
	end
end

function inEvadedList(missile)
	for i, m in ipairs(myEvadedMissiles) do
		if (missile:getName() == m:getName()) then
			return true
		end
	end
	return false
end

function check()
    expireEvadedMissiles()
    -- Find nearby missiles.  In the future, check for missile lock.
    local nearbyEntities = vrf:getSimObjectsNear(this:getLocation3D(), 3000);
    if (#nearbyEntities > 0) then
       for i, entity in ipairs(nearbyEntities) do
          if (vrf:forcesHostile(this:getForceType(), entity:getForceType())) then
             if (vrf:entityTypeMatches(entity:getEntityType(), EntityType.Munition()) and not inEvadedList(entity)) then
	        myMissile = entity
	        return true   
	     end
          end
       end
   end
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   printWarn(vrf:trUtf8("Missile incoming!"))
   local vecAwayFromMissile = this:getLocation3D():vectorToLoc3D(myMissile:getLocation3D())
   vecAwayFromMissile = vecAwayFromMissile:getScaled(-10)
   local destination = this:getLocation3D():addVector3D(vecAwayFromMissile)
   myManuverSubtaskId = vrf:startSubtask("fly-heading", {heading=vecAwayFromMissile:getBearing(), turn_rate = 50 })
   vrf:startSubtask("fly-altitude", {altitude=this:getLocation3D():getAlt() + 1000, climb_descent_rate = 500 })
   myLastMissileDist = this:getLocation3D():distanceToLocation3D(myMissile:getLocation3D())
   --myCountermeasuresSubtaskId = -1
   myCountermeasuresSubtaskId = vrf:startSubtask("launch-expendable-resource", {expendable_resource_name="m206-flare", 
			number_to_fire=5, time_interval=0.5})
end

function angleToMissile()
	local vecToMissile = this:getLocation3D():vectorToLoc3D(myMissile:getLocation3D())
	local headingDiff = this:getDirection3D():headingDiff(vecToMissile)
	return headingDiff
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   -- vrf:endTask(true)
   local missileDist = this:getLocation3D():distanceToLocation3D(myMissile:getLocation3D())
   if (missileDist > myLastMissileDist) then
	vrf:stopAllSubtasks()
	table.insert(myEvadedMissiles, myMissile)
        printWarn(vrf:trUtf8("Missile getting farther away.  Ending task"))
	myMissile = nil
	vrf:endTask(true)
	return
   end
   myLastMissileDist = missileDist
   
   local bearingToMissile = angleToMissile()
   if (myCountermeasuresSubtaskId == -1) then
	if (bearingToMissile > math.rad(160) or bearingToMissile < math.rad(-160)) then
		myCountermeasuresSubtaskId = vrf:startSubtask("launch-expendable-resource", {expendable_resource_name="m206-flare", 
			number_to_fire=5, time_interval=0.5})
		local newHeading = this:getHeading();
		if (math.random(2) == 2) then
			newHeading = newHeading + math.rad(90)
		else
			newHeading = newHeading - math.rad(90)
		end
		myManuverSubtaskId = vrf:startSubtask("fly-heading", {heading=newHeading, turn_rate = 50 })
		vrf:startSubtask("fly-altitude", {altitude=this:getLocation3D():getAlt() + 1000, climb_descent_rate = 500 })
	end
   else
	if (vrf:isSubtaskComplete(myCountermeasuresSubtaskId)) then
		myCountermeasuresSubtaskId = -1
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