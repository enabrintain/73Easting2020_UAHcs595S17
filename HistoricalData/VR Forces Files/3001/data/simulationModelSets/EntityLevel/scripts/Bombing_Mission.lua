--
-- Copyright (c) 2012 MAK Technologies, Inc.
-- All rights reserved.
--
-- This is an experimental VR-Forces Lua task. It has been created to provide some basic example functionality 
-- that you can test, copy, use as-is, or modify to achieve your goals. It is not tested as part of the VR-Forces
-- standard task regression procedure and should be considered complete as is. We are happy to receive bug fixes and 
-- suggestions on ways to improve it via email to support@mak.com, Additionally will be happy to consider injecting any 
-- improvements or additional scripts which you may send to us. 
--

-- Used to call in close air support on a named target. The initial point is 
-- the location which the plane will use to line up with the target. The offset,
-- if specified, will determine which side of the initial point to target line 
-- the bomber will prefer. The user can also select the type of bomb to use, the
-- heading to take after the bomb is released and the altitude to use (current 
-- or max).


-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Enumeration to match taskParameters.attackWeaponType
local BOMB_ATTACK = 0
local GUN_ATTACK = 1

myState = "movingToOffset"
moveToOffsetSubtaskId = -1
approachIPSubtaskId = -1
moveToIPSubtaskId = -1
moveToLARSubtaskId = -1
releaseBombSubtaskId = -1

strafeSubtaskId = -1
offset = "none"
offsetHeading = 0

-- If the user doesn't specify the altitude as "use current", use a really big 
-- default to insure that all planes will go to their maximum altitudes
bombingAltitude = 50000
-- This will be set up in init() based on the bombingAltitude
bombRange = 0

function init()
   -- Check to see if the bomber is on the ground (plus some tolerance for the
   -- bounding volume offset) and if so abort the task.
   if (this:getHeightAboveTerrain() < 10) then
      print("Can't execute close air support when on the ground, aborting.")
      vrf:endTask(false)
      return
   end
   
   if (taskParameters.targetName == nil or not taskParameters.targetName:isValid()) then
      printWarn("Can't execute close air support: invalid target")
      vrf:endTask(false)
      return
   end

   -- setup the offset (if any) from the task parameters
   if (taskParameters.offset == 0) then
      offset = "none"
   elseif (taskParameters.offset == 1) then
      offset = "left"
   elseif (taskParameters.offset == 2) then
      offset = "right"
   end

   -- determine heading for the offset based on the direction from the initial
   -- point to the target
   if (offset == "right") then
      offsetHeading = math.rad(90)
   elseif (offset == "left") then
      offsetHeading = math.rad(90) * -1
   end

   if taskParameters.attackWeaponType == BOMB_ATTACK then
   
      -- set up bombingAltitude based on altitude parameter (1 == use current, 
      -- otherwise use max defined above)
      if (taskParameters.altitude == 1) then
         bombingAltitude = this:getLocation3D():getAlt()
         print("altitude was set to use current, will stay at ", bombingAltitude)
      end
      -- set bombRange using a calculation which is similar to the one done in 
      -- DtBombActuator::calculateTargetCircle() with hard-coded values which are
      -- representative of the capabilities of the bombs in the SMS.
      local altitudeFactor = bombingAltitude / 15000;
      if (altitudeFactor > 1.0) then
         altitudeFactor = 1.0
      end   
      bombRange = 28000 * altitudeFactor
         
      print("Starting bombing mission ")
   else
      print("Starting strafing attack")
   end
end

-- convenience function to get the target location by name
function targetLocation()
   return taskParameters.targetName:getLocation3D()
end

-- convenience function to get the target location by name and set its altitude to 0
function targetLocationOnGround()
   local loc = targetLocation()
   loc:setAlt(0)
   return loc
end

function moveToOffset()
   -- if there's no offset specified, just return true to allow tick to 
   -- immediately transition to the next state
   if (offset == "none") then
      print("No offset specified, approching the IP directly")
      return true
   end	

   -- first see if the bomber is already on the correct side of the IP to target
   -- line
   local ip = taskParameters.initialPoint
   local ipToTarget = ip:vectorToLoc3D(targetLocation())
   local ipToTargetBearing = ipToTarget:getBearing()
   local bomberLoc = this:getLocation3D()
   local ipToBomber = ip:vectorToLoc3D(bomberLoc)
   local ipToBomberBearing = ipToBomber:getBearing()
   local headingDiff = ipToTarget:headingDiff(ipToBomber)
   if (offset == "left" and headingDiff < 0) then
      print("Left offset specified, already left of the target line")
      return true
   elseif (offset == "right" and headingDiff > 0) then
      print("Right offset specified, already right of the target line")
      return true
   end
 
   if (moveToOffsetSubtaskId < 0) then
      -- create a vector from the IP towards the offset header, perpendicular
      -- to the IP to target line
      -- note that makeCopy is used here instead of the assignment operator
      -- because offsetVector needs to be a copy of ipToTarget, not a reference
      -- to it
      local offsetVector = ipToTarget:makeCopy()
      offsetVector:setBearingInclRange(ipToTarget:getBearing() + offsetHeading, 
         ipToTarget:getInclination(), ipToTarget:getRange())
      -- create a vector from the bomber location to the IP to target line
      ipToTargetUnitLine = ipToTarget:getUnit()
      bomberToLineVector = ipToBomber:crossVector3D(ipToTargetUnitLine)
      bomberToLineRange = bomberToLineVector:getRange()
      -- now extend it out so that the bomber will cross into offset territory
      offsetVector:setBearingInclRange(offsetVector:getBearing(), 
         offsetVector:getInclination(), bomberToLineRange + 1000)
      -- apply the offset to the current bomber location
      local offsetPoint = bomberLoc:addVector3D(offsetVector)
      offsetPoint:setAlt(bombingAltitude);
      -- issue the move to task
      moveToOffsetSubtaskId = vrf:startSubtask("move-to-location-task", 
         {aiming_point=offsetPoint})
      --offsetWaypoint = vrf:createWaypoint({location=offsetPoint, force=neutral})
      print("Moving to offset point " , offsetPoint:getLat(), ", ",
         offsetPoint:getLon(), ", ", offsetPoint:getAlt(), " subtaskId = ",
         moveToOffsetSubtaskId);

   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(moveToOffsetSubtaskId)) then
      moveToOffsetSubtaskId = -1;
      return true;
   end
   
   return false
end

function approachIP()
   if (approachIPSubtaskId < 0) then
      -- create a point in the IP to target line which comes before the IP so
      -- the bomber can line up with the target
      local ip = taskParameters.initialPoint
      local ipToTarget = ip:vectorToLoc3D(targetLocation())
      ipToTarget:setBearingInclRange(ipToTarget:getBearing() + math.pi, 0, 5000)
      local approachPoint = ip:addVector3D(ipToTarget)
      -- if the user specified an offset, move the approach point out into the
      -- offset territory so the bomber doesn't cross the line when turning
      if (offset ~= "none") then
         local approachPointToTarget = 
            approachPoint:vectorToLoc3D(targetLocation())
         approachPointToTarget:setBearingInclRange(
            approachPointToTarget:getBearing() + offsetHeading, 0, 5000)
            approachPoint = approachPoint:addVector3D(approachPointToTarget)
      end
      approachPoint:setAlt(bombingAltitude);
      approachIPSubtaskId = vrf:startSubtask("move-to-location-task", 
         {aiming_point=approachPoint})
      print("Approaching IP from " , approachPoint:getLat(), ", ",
         approachPoint:getLon(), ", ", approachPoint:getAlt(), " subtaskId = ",
         approachIPSubtaskId);

   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(approachIPSubtaskId)) then
      approachIPSubtaskId = -1;
      return true;
   end
   
   return false
end

-- IP is an abbreviation for initial point (specified by the user)
function moveToIP()
   if (moveToIPSubtaskId < 0) then
      local ipAtBombingAltitude = taskParameters.initialPoint
      ipAtBombingAltitude:setAlt(bombingAltitude)
      moveToIPSubtaskId = vrf:startSubtask("move-to-location-task", 
      {aiming_point=ipAtBombingAltitude})
   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(moveToIPSubtaskId)) then
      moveToIPSubtaskId = -1;
      return true
   end
   
   return false
end

-- LAR is an abbreviation for launch acceptance/acceptibility region, which is
-- defined as the point which is half the bomb's maximum range away from the
-- target.
function moveToLAR()
   -- if the bomber is already at least half the bomb's range away from the 
   -- target just return true to allow tick to immediately release the bomb
   local startLoc = this:getLocation3D()
   startLoc:setAlt(0)
   local startToEnd = startLoc:vectorToLoc3D(targetLocationOnGround())
   local currentRange = startToEnd:getRange()
   if (currentRange < bombRange / 2) then
      print("Already within launch acceptance region.")
      return true
   end
   
   if (moveToLARSubtaskId < 0) then
      -- find and move to the LAR point
      startToEnd:setBearingInclRange(startToEnd:getBearing(), 0, 
         currentRange - (bombRange / 2))
      local larPoint = startLoc:addVector3D(startToEnd)
      larPoint:setAlt(bombingAltitude)
      moveToLARSubtaskId = vrf:startSubtask("move-to-location-task",
		{aiming_point = larPoint})
   end
   -- when the movement task is complete return true to allow tick to 
   -- transition to the next state
   if (vrf:isSubtaskComplete(moveToLARSubtaskId)) then
      moveToLARSubtaskId = -1
      return true
   end
   
   return false
end

function releaseBomb()
   if (releaseBombSubtaskId < 0) then
      local ammoName = string.gsub(taskParameters.bombType, "weapon.*|", "")
      -- If a laser code is specified, set the laser code, and drop a laser guided bomb.
      if (taskParameters.laserCode > 0) then
	 releaseBombSubtaskId = vrf:startSubtask("release-bomb-on-laser-spot",
            {ammunition_resource_name = ammoName, 
            laser_code = taskParameters.laserCode})	 
      else
	 releaseBombSubtaskId = vrf:startSubtask("release-bomb-on-target",
            {ammunition_resource_name = ammoName, 
            entity_name = taskParameters.targetName})
      end            
   end
   if (vrf:isSubtaskComplete(releaseBombSubtaskId)) then
      releaseBombSubtaskId = -1
      return true
   end
   
   return false
end

-- implements the state machine which moves the bomber into the offset region,
-- to an approach point, to the initial point, to the launch acceptance region,
-- and then finally releases the bomb
function tick()
   
   
   if taskParameters.attackWeaponType == GUN_ATTACK then
      if strafeSubtaskId == -1 then
         local ipLocation = taskParameters.initialPoint
         local adjustedIp
         
         local egressSide = 1 -- None
         if offset == "left" then egressSide = 0
         elseif offset == "right" then egressSide = 2
         end
         
         if offset == "none" then
            adjustedIp = ipLocation
         else
            local ipOffset = ipLocation:vectorToLoc3D(targetLocation())
            ipOffset:setBearingInclRange(ipOffset:getBearing() + offsetHeading,
               0, 500)
            adjustedIp = ipLocation:addVector3D(ipOffset)
         end
         strafeSubtaskId = vrf:startSubtask("Strafe_Ground_Target", 
            {targetPoint = taskParameters.targetName,
            initialPointLocation = adjustedIp,
            egressManeuver = egressSide,
            finalEgressHeading = taskParameters.egressHeading,
            abortWithoutTarget = true -- must acquire target to shoot
            })
      else
         if taskDone(strafeSubtaskId, true) then
            vrf:endTask(true)
         end
      end
   else
      if (myState == "movingToOffset") then
         if (moveToOffset()) then
            myState = "approachingIP"
         end
      end  
      
      if (myState == "approachingIP") then
         if (approachIP()) then
            myState = "movingToIP"
         end
      end
      
      if (myState == "movingToIP") then
         if (moveToIP()) then
            myState = "movingToLAR"
         end
      end

      if (myState == "movingToLAR") then
         if (moveToLAR()) then
            myState = "releasingBomb"
         end
      end
      
      if (myState == "releasingBomb") then
         if (releaseBomb()) then
            -- fly at the user specified egress heading (this is the final task
            -- and the bomber will continue flying this heading until it is tasked
            -- to do something else by the user (or plan)
            vrf:startSubtask("fly-heading-task", 
               {heading=taskParameters.egressHeading})
            vrf:endTask(true)
         end
      end
   end
end

function shutdown()
end
