-- This script changes entity movement behavior when it is suppressed.
-- If the entity becomes suppressed, the posture is changed to crouching.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Posture the entity was in when it became supressed.
oldPosture = nil

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   -- Want a fairly quick response to fire.
   vrf:setTickPeriod(0.25)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   return this:getSuppressionLevel() > 0 and
      this:getLifeformPosture() ~= LifeformPosture.StringToEnum("prone") and
      this:getLifeformPosture() ~= LifeformPosture.StringToEnum("crawling")
end

-- Called when the task first starts. Never called again.
function init()
   oldPosture = this:getLifeformPosture()
   targetPosture = LifeformPosture.StringToEnum("crouching")
   vrf:executeSetData("set-lifeform-posture", 
      {lifeform_posture = targetPosture})
   vrf:setTickPeriod(1.0)
end

-- Called each tick while this task is active.
function tick()
   if this:getSuppressionLevel() == 0 then
   
      vrf:executeSetData("set-lifeform-posture", {lifeform_posture = oldPosture})
      vrf:endTask(true)
   end
end


-- Called when this task is being suspended, likely by a reaction activating.
function suspend()

end

-- Called when this task is being resumed after being suspended.
function resume()
   -- Don't call init. We don't really know what posture to recover to when the
   -- suppression level goes back to 0, but if we are "popping" tasks off the stack
   -- then we assume that whatever the entity was doing when oldPosture was 
   -- originally set will be resumed, and we'll want the original oldPosture.
   
   -- The suppression level could have gone to 0 and then back to 1 while this
   -- reaction was suspended, but don't try to second guess that and issue another
   -- set-posture Set. 
end
