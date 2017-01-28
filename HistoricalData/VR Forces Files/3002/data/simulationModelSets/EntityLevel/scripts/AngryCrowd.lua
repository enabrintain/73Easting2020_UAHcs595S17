-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
talkSubtaskId = -1
waitTaskId = -1

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   -- get the entity type.
   entityType = this:getEntityType()
   --number of times to execute a task
   repetitions = taskParameters.taskRepetitions
   -- counter for task repetitions
   taskCounter =  0
   
   -- the randomness algorithm
   -- 0 is execute tasks in order
   -- 1 is use a random task
   randomness = taskParameters.randomness
  -- print("entity type is ", entityType)
   --characterType = taskParameters.characterType
   
   -- the entity type matches a particular character type. Different character types have different talk animations
   -- based on the entity type, create a table of animations that area available to the character.
   -- set the number of animations in the table so we can use it as a counter later on
   -- generate a random number to be the first task so not everyone starts with the same task.
   if entityType == "3:1:225:3:0:1:0" then
      -- aka mped_07
	--character = "civilian_adult"
	talkAnimations ={"angry_chant_1_arm", "angry_chant_2_arms", "angry_yell", "angry_yell_forward_back"}
	number_of_animations = 4
	startTask = math.random(number_of_animations)
   elseif entityType == "3:1:225:3:1:1:0" then
      -- aka fped_07
	--character = "civilian_adult"
	talkAnimations ={"angry_chant_1_arm", "angry_chant_2_arms", "angry_yell", "angry_yell_forward_back"}
	number_of_animations = 4
	startTask = math.random(number_of_animations)
    elseif entityType == "3:1:225:3:1:0:0" then
        -- aka mped5_crowd1
	--character = "civilian_male_crowd"  
	talkAnimations = {"angry_crowd1", "angry_crowd2", "angry_crowd3", "angry_crowd4", "angry_crowd5", "chant_1_arm", "chant_2_arms"} 
	number_of_animations = 7
	startTask = math.random(number_of_animations)	
   elseif entityType == "3:1:225:3:1:0:2" then
      -- aka fped3_crowd1
	--character = "civilian_female_crowd"
	talkAnimations = {"angry_crowd1", "angry_crowd2", "angry_crowd3", "angry_crowd4", "angry_crowd5", "chant_1_hand", "chant_2_hands"}
	number_of_animations = 7
	startTask = math.random(number_of_animations)	
   end	
   
   -- need to hang on to the original start task number for later
   originalStartTask = startTask
  
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.

	if talkSubtaskId == -1 then
		talkSubtaskId = vrf:startSubtask( "di-guy-animation-task", { di_guy_animation_task_kind=talkAnimations[startTask], di_guy_animation_duration=0} );
	end   

  
	if vrf:isSubtaskComplete(talkSubtaskId) then
		-- before issuing a new talk task, wait a little bit
		if waitTaskId == -1 then
			wait()
		end
		-- when done waiting, issue another task
		if vrf:isSubtaskComplete(waitTaskId) then
			waitTaskId = -1
			talkSubtaskId = -1

			taskCounter = taskCounter +1
			--print ("task is ", startTask)
		
			-- algorithm for sequential execution
			if randomness == 0 then
				startTask = startTask + 1
		
				-- start the task list back at the beginning
				if startTask > number_of_animations then
					startTask = 1
				end
			elseif randomness == 1 then
				startTask = math.random(number_of_animations)
		
			end
		
			if taskCounter > repetitions then
			vrf:endTask(true)
			end
		end

	end
end

function wait()
	-- sends a wait task
	waitTime = math.random(2)
	print ("waiting ", waitTime, " seconds")
	waitTaskId = vrf:startSubtask("wait-duration",  {seconds_to_wait=waitTime})

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
