-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.destination Type: Location3D - Location to navigate to
--  taskParameters.obstacleQuery Type: String - A constraint expression defining which features of the given type the path will avoid
--  taskParameters.pathQuery Type: String
--  taskParameters.buffer Type: Real Unit: meters - Distance that the path will stay away from the non-traversable feature.
--  taskParameters.displayRoute Type: Bool (on/off) - Display calculated route in GUI


-- amount to increase entity width by
widthFactor = 2;

-- default feature query if not supplied by caller
defaultObstacleQuery = "MAK_OBSTACLE"
defaultPathQuery = "MAK_ROAD"

-- calculate buffer distance
buffer = taskParameters.buffer
if (not buffer or buffer <= 0) then
   local bvol = this:getBoundingVolume()
   local width = bvol:getRight()
   buffer = width*widthFactor
   printDebug("width=" .. width .. ", buffer=" .. buffer)
end

-- feature query to avoid
obstacleQuery = taskParameters.obstacleQuery

-- old name, if it's there this is an old scenario
if (taskParameters.query ~= "") then
   obstacleQuery = taskParameters.query
end

if (not obstacleQuery or obstacleQuery == "") then
   obstacleQuery = defaultObstacleQuery
end

--  paths to follow
pathQuery = taskParameters.pathQuery
if (not pathQuery or pathQuery == "") then
   pathQuery = defaultPathQuery
end

printDebug("pathQuery=" .. pathQuery)
printDebug("obstacleQuery=" .. obstacleQuery)

-- objects we'll manage during this task
route = nil          -- route created from path points
job = nil             -- async job which will create points
routeTask = nil    -- route subtask
stopTask = nil     -- task which stops entity (some entities will keep moving)
lastMessage = ""	-- last printed message from task

-- Called when the task first starts. Never called again.
function init()
   vrf:setTickPeriod(0.5)
   
   -- stop subtask if running so we can delete route
   if (routeTask) then
      vrf:stopSubtask(routeTask)
      routeTask = nil
   end
   
   -- get rid of route
   if (route) then
      vrf:deleteObject(route)
      route = nil
   end
   
   -- test for problems with parameters
   if (not buffer or buffer < 0) then
      printWarn(vrf:trUtf8("Invalid buffer (%1)"):arg(buffer))
      vrf:endTask(false)
      return
   end
   
   -- start async job
   job = vrf:navigateThroughFeatures({
      obstacleQuery=obstacleQuery,
      pathQuery=pathQuery,
      buffer=buffer,
      start=this:getLocation3D(),
      destination=taskParameters.destination})
      
   -- make sure job started correctly
   if (not job) then
      printWarn(vrf:trUtf8("Could not start async job"))
      vrf:endTask(false)
      return
   end
   
   printDebug("Navigation: Initializing")
end


-- Called each tick while this task is active.
function tick()
   if (job) then
   
      -- check job
      local points,index,message = job:getObject()
   
      -- print out any messages from the algorithm
      if (message and message ~= "" and message ~= lastMessage) then
         printDebug("Navigation: " .. message)
      end
      lastMessage = message
   
      -- if job isn't done then just print message
      if (index == 0) then    
         if (not stopTask or not vrf:isSubtaskRunning(stopTask)) then
            if (this:getSpeed() > 0) then
               stopTask = vrf:startSubtask("stop-moving", {})
            end
         end
     
         return
      end
   
      -- job is done
      job = nil
    
      -- check to see if we have a valid path
      if (#points < 2) then
         if (message) then
            printWarn(vrf:trUtf8("Could not compute path - %1"):arg(message))
         else
            printWarn(vrf:trUtf8("Invalid path computed"))
         end
            
         vrf:endTask(false)
         return
      end
      
      printVerbose("Path length: " .. #points)
         
      -- create the route to follow
      route = vrf:createRoute({
         object_name=this:getName() .. " Path Plan Route",
         locations=points,
         publish=taskParameters.displayRoute})
       
      -- make sure route is okay
      if (not route or not route:isValid()) then
         printWarn(vrf:trUtf8("Cound not create route"))
         vrf:endTask(false)
         return
      end
      
      -- cancel the stopping task if it's still going on
      if (stopTask and vrf:isSubtaskRunning(stopTask)) then
         vrf:stopSubtask(stopTask)
         stopTask = nil
      end
       
      -- issue subtask
      routeTask = vrf:startSubtask("move-along", {
         route=route:getName(),
         start_at_closest_point=true})
      
      return
   end
   
   -- monitor subtask and end when it's done
   if (routeTask and not vrf:isSubtaskRunning(routeTask)) then
      vrf:endTask(vrf:subtaskResult(routeTask))
      return
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
   -- remove route if it exists
   if (route ~= nil) then
      vrf:deleteObject(route)
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
