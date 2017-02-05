-- Copyright 2012 VT-MAK
--
-- This is an experimental VR-Forces Lua task. It has been created to provide some basic example functionality 
-- that you can test, copy, use as-is, or modify to achieve your goals. It is not tested as part of the VR-Forces
-- standard task regression procedure and should be considered complete as is. We are happy to receive bug fixes and 
-- suggestions on ways to improve it via email to support@mak.com, Additionally will be happy to consider injecting any 
-- improvements or additional scripts which you may send to us. 
--
-- last Update: 11/19/2012

-- This task illustrates using text messages between entities to get some cooperative behavior.
-- This is intended for use on civilian entities, and will cause entities to execute a Wander task (if B-HAVE is installed)
-- and periodically search for nearby entities.  It will then send a message to a random nearby entity asking
-- if it would like to have a conversation.  If the other entity is running this same task, then 
-- that entity (if not having a conversation already) will respond positively.  The two entities
-- will move toward each other, and then run a DI-Guy "talk" animation, before returning to their 
-- original wandering state.

require "vrfutil"

-- Some constants defined for use in this script.
-- the 'local' key is used here to prevent these from being written to the VRF checkpoint file.
local searchInterval = 10;  -- Number of seconds between attempts to locate a nearby friend.
local askTimeout = 2;  -- Number of seconds to wait for a response after asking an entity to talk.

-- State variables.
-- These will be saved to the VRF checkpoint file, and restored when a scenario is loaded.
myFriend = nil;
myState = "searching";
moveSubtaskId = -1;
talkSubtaskId = -1;
lastSearchTime = vrf:getExerciseTime() - math.random(searchInterval); -- Make the first search be a random fraction of searchInterval.
wanderSubtaskId = -1
-- Get the wander values from the dialog box.
wanderArea = taskParameters.Area
movement = taskParameters.movement

-- Check boxes return true or false, but the wander task needs a 1 or 0, so convert the possible values.
if (movement == true) then
	movement = 1
else
	movement = 0
end

   
function init()
     vrf:setTickPeriod(0.5)
end

function startWander()
  -- If B-HAVE module is loaded, then issue a wander task.
  -- If B-HAVE is not present, entity will simply stand still.
  if (bhaveLoaded()) then
    wanderSubtaskId = vrf:startSubtask("bhave-wander-task", {area=wanderArea,movement=movement})
  end
end

-- Stop the wander subtask if it is running.
function stopWander()
  vrf:stopSubtask(wanderSubtaskId)
  wanderSubtaskId = -1
end

-- Locates a nearby friend entity, and sends a message asking to initiate a conversation.
-- Sets myFriend to be the friend entity, if one is found.
-- Sets the lastSearchTime to the current time.
function findFriend()
   lastSearchTime = vrf:getExerciseTime();
   local nearbyEntities = vrf:getSimObjectsNear(this:getLocation3D(), taskParameters.FriendDistance);
   if (#nearbyEntities < 1) then
      return nil;
   end
   -- Choose a random entry from the list.
   local choice = math.random(1, #nearbyEntities);
   -- If self was randomly chosen, then return.
   if (nearbyEntities[choice] == this) then 
      return nil;
   end
   
   -- For some reason I can't copy an object from the table.
   myFriend = nearbyEntities[choice];
   -- Only try to talk to non-hostile forces.
   if (vrf:forcesHostile(this:getForceType(), myFriend:getForceType())) then      
      myFriend = nil
      return nil
   end
   myState = "asking"
   askTime = vrf:getExerciseTime();
   -- Send a message to the other entity asking if it wants to talk.
   -- If that entity is not running this same task, it will not respond.
   vrf:sendMessage(myFriend, "Want to talk?");

end

-- Run while in the movement state.
-- Starts a movement task if one is not running.
-- If the movement task completes, then returns true.
function moveToFriend()
   if (moveSubtaskId < 0) then
      moveSubtaskId = vrf:startSubtask("move-to", {destination=myFriend})
   end
   -- Check the state of an already started movement task.
   if (vrf:isSubtaskComplete(moveSubtaskId)) then
      moveSubtaskId = -1;
      return true;
   end
   
   
   return false;
end

-- Run while in the talking state.
-- Plays a single DI-Guy talking animation to completion, and returns true once that has completed.
function talkToFriend()
   if (talkSubtaskId < 0) then
      -- This animation name is specific to the DI-Guy civilian model, and will not play if another model is being used.
      talkSubtaskId = vrf:startSubtask("di-guy-animation-task", { di_guy_animation_task_kind="talk1" } );
   end
   if (vrf:isSubtaskComplete(talkSubtaskId)) then
      talkSubtaskId = -1;
      return true;
   end
   return false;
end

-- Main tick function runs the appropriate function given the current state.
function tick()

   if (myState == "asking") then
      -- If ask times out, then go back to searching.  This happens when the target entity is not running this task and so has not responded to the message.
      if (vrf:getExerciseTime() > askTime + askTimeout) then
         myState = "searching"
      end
   end
   
   if (myState == "searching") then
      -- If the search interval has elapsed, then try to find a new friend.
      if (vrf:getExerciseTime() > lastSearchTime + searchInterval) then
		  findFriend();
	  end
      -- Start wandering around.
      if (wanderSubtaskId == -1) then
         startWander()
      end
   end
   
   if (myState == "moving") then
      -- Make sure the wander subtask has been stopped if we are moving toward a friend.
      if (wanderSubtaskId ~= -1) then
         stopWander()
      end
      -- If move to friend has completed, start talking.
      if (moveToFriend()) then
         myState = "talking"
      end
   end
   
   if (myState == "talking") then
      -- Once the talking has completed, return to the searching state.
      if (talkToFriend()) then
         myState = "searching";
      end
   end
   
end

-- This function is called for each text message received.
function receiveTextMessage(message, sender)
   if (message == "Want to talk?") then
      -- This message is from another entity running this same task.
      --  If this entity is not busy (i.e. currently in searching mode) then agree to talk.  Otherwise, don't.
      if (myState == "searching") then
         -- Start moving to this new friend.
         myState = "moving"
         myFriend = sender;
         vrf:sendMessage(sender, "Let's talk");
      else
         vrf:sendMessage(sender, "Can't talk");
      end
   end
   if (message =="Let's talk") then
      -- This should come in response to this entity asking another to talk.  This puts us in the movement state.
      if (myState == "asking") then
         myState = "moving"
         myFriend = sender;
      end
   end
   if (message == "Can't talk") then
      -- This message will come in response to this entity asking another to talk.  In this case, there is no need to wait for the timeout
      -- before returning to the searching state.
      if (myState == "asking") then
         myState = "searching"
      end
   end
end
