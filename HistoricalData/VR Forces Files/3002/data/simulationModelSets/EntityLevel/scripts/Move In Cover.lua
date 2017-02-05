-- Move In Cover

-- This task moves the subordinates individuals of an infantry unit to a sequence
-- of cover positions, defined by phase line parameters.
-- The individuals are moved one at a time to positions evenly spaced along
-- the phase line. The individuals move to the first position in the order
-- that they are listed (in a getSubordinates() call); for succeeding positions,
-- the order reverses at each position.
-- At each position, the individuals face the first point of the phase line
-- when they arrive, except the first individual who kneels and faces the
-- given threat position with his weapon in firing position. At the last
-- cover position, none, one, or all individuals may go into this "guard"
-- posture depending on the input parameter.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- taskParameters
-- coverObjects - a table of phase line objects that are used as movment targets.
-- threatWaypoint - the aim point for individuals in "guard" posture
-- movementSpeed - desired speed for moving individuals. 
-- lastCoverGuard - determines which entities are set to "guard" when the entities reach the last cover object
-- 0 == "all" - all entities "guard"
-- 1 == "first"  - only first entity to reach cover "guards"
-- 2 == "none" - no entities "guard"

-- Global Variables, which are saved/restored with a scenario checkpoint.

-- The index of the cover position that the unit is currently moving to.
currentCoverIndex = 0
-- Table of currently moving subordinates and the taskIds of their tasks.
-- In the current version of this script, only one subordinate moves at 
-- a time, so this table will have only one entry.
movingSubs = {}
-- The index, in move order, of the currently moving subordinate.
-- This will be the reverse of the order in the subordinate list
-- on alternating cover positions.
movingSubIndex = 0
-- Indicates whether the subordinates move in normal or reverse
-- order from the subordinate list.
reverseMovementOrder = false

------- Index functions ----------

-- Determine the index position in the list of subordinates of the given subordinate
function indexForSub(subordinate)
   for i, sub in pairs(this:getSubordinates()) do 
      if subordinate == sub then
         return i
      end
   end
   --print ("couldn't match ", subordinate)
   return -1
end

--Returns the index in the subordinates list of the given index. 
--This is just the same thing unless the reverseMovementOrder is set,
--in which case the returned index goes backwards through the sub list.
function getSubIndex(movementIndex)
   if (not reverseMovementOrder) then 
      return movementIndex
   end
   
   return #this:getSubordinates() - (movementIndex - 1)
end

--Returns the subordinate index of index 1
--(which will be the last subordinate if going in reverse order).
function getFirstSubIndex()
   if (not reverseMovementOrder) then 
      return 1
   end
   
   return #this:getSubordinates()
end

------ Task functions ----------

--Set the subordinate's appearance to standing, weapon deployed and move it to
--the destination + offset. 
function taskSubToMove(subordinate, destination, offset)
   --print("subordinate:", subordinate)
   local destination = destination:addVector3D(offset);
   --print("destination: ", destination)
   local taskId = vrf:sendTask(subordinate, "move-to-location-task", {aiming_point = destination})
   --print("taskId: ", taskId)
   vrf:sendSetData(subordinate, "set-lifeform-posture", {lifeform_posture = "standing"})
   vrf:sendSetData(subordinate, "set-lifeform-weapon-state", {lifeform_weapon_state = "weapon-deployed"})
   vrf:sendSetData(subordinate, "set-speed", {speed = taskParameters.movementSpeed})
   movingSubs[subordinate] = taskId
end

--Compute the offset of this subordinate along the next cover object line and
--task it to move there.
function taskSub(subordinate)
   local coverObject = taskParameters.coverObjects[currentCoverIndex]
   local lineStart = coverObject:getLocations3D()[1]
   local lineEnd = coverObject:getLocations3D()[2]
   local offset = lineStart:vectorToLoc3D(lineEnd)
   --print("Offset: ", offset)
   offset = offset:getScaled(1/(#this:getSubordinates() - 1))
   --print("Offset: ", offset) 
   offset = offset:getScaled(movingSubIndex - 1)
   taskSubToMove(subordinate, lineStart, offset)
end

--Determine the desired "guard" state of the given indexed subordinate from 
--the task parameters. If it should be guarding, set it to guard state; 
--otherwise, set to it look along the cover object line.
function finishSubMove(subIndex)
   local guard = false
   if (currentCoverIndex ~= #taskParameters.coverObjects) then 
      if (subIndex == getFirstSubIndex()) then
         guard = true
      end
   else
       if (taskParameters.lastCoverGuard == 0 or 
	      (taskParameters.lastCoverGuard == 1 and 
		     subIndex == getFirstSubIndex())) then 
			 
          guard = true
	   end
   end
    
   if guard then
        setSubToGuard(this:getSubordinates()[subIndex])          	
   else
       local coverObject = taskParameters.coverObjects[currentCoverIndex]
       local lineStart = coverObject:getLocations3D()[1]
       local lineEnd = coverObject:getLocations3D()[2]
       local offset = lineEnd:vectorToLoc3D(lineStart)
       vrf:sendSetData(this:getSubordinates()[subIndex], "set-heading", {heading = offset:getBearing()})
	   if (subIndex == getFirstSubIndex()) then
		  vrf:sendSetData(this:getSubordinates()[subIndex], "set-lifeform-weapon-state", {lifeform_weapon_state = "weapon-in-fire-position"})
	   end 
	       --print ("not first sub index", movingSubIndex, ", ", getFirstSubIndex(), ", ", this:getSubordinates()[getSubIndex(movingSubIndex)])  
   end
end

-- Sets the appropriate attributes of a single subordinate when in the guarding mode.
function setSubToGuard(sub)
   vrf:sendSetData(sub, "set-lifeform-posture", {lifeform_posture = "kneeling"})
   vrf:sendSetData(sub, "set-lifeform-weapon-state", {lifeform_weapon_state = "weapon-in-fire-position"})
   vrf:sendSetData(sub, "set-aiming-point", {target_object=taskParameters.threatWaypoint:getUUID()})
end

------ Control functions ----------

--Checks to see if the currently moving subordinate(s) is done, and if so
--calls finishSubMove on it and increments the movingSubIndex. 
function checkSubordinateTasks()
   local activeSubsCount = 0;
   for sub, taskId in pairs(movingSubs) do
      if (sub:isDestroyed()) then
         movingSubs[sub] = nil;
      end      
      if (vrf:isTaskComplete(taskId)) then
         -- remove the subordinate from the table. It has completed its task.
         movingSubs[sub] = nil
	     --print ("finish move for: ", indexForSub(sub))
	     finishSubMove(indexForSub(sub))
	     movingSubIndex = movingSubIndex + 1
      else
         activeSubsCount = activeSubsCount + 1
      end
   end
   return activeSubsCount
end

--Starts the unit on a move to a new cover position.
--Resets the movingSubIndex, advances the currentCoverIndex, and flips
--reverseMovementOrder.
--Tasks the first subordinate to move to its new position.
function startMoveLeg()
   currentCoverIndex = currentCoverIndex + 1
   reverseMovementOrder = not reverseMovementOrder
   movingSubIndex = 1
         
   if (currentCoverIndex <= #taskParameters.coverObjects) then
	   --print ("SUB: ", movingSubIndex, ", ", getSubIndex(movingSubIndex), ", ", this:getSubordinates()[getSubIndex(movingSubIndex)])
	   taskSub(this:getSubordinates()[getSubIndex(movingSubIndex)])
   else
	--print ("Out of cover objects.")
	vrf:endTask(true)
   end
end
-----------------------------------------------------------------------------------
-- Called once when the task first starts.
function init()
   --print("init")
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   --printWarn("last cover mode: ", taskParameters.lastCoverGuard)
   
   local subordinates = this:getSubordinates()
      
   if (#subordinates < 1) then
      vrf:endTask(false)
      return
   end

   startMoveLeg()
end

--==================================================================================
-- Called each tick while this task is active.
-- Once endTask() is called, the task is inactive and tick() will not be called again
function tick()   
   if (checkSubordinateTasks() == 0) then      
      if (movingSubIndex > #this:getSubordinates() or movingSubIndex < 1) then
         startMoveLeg()
      else        
         taskSub(this:getSubordinates()[getSubIndex(movingSubIndex)])
      end
   end
end
--===================================================================================	 
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
