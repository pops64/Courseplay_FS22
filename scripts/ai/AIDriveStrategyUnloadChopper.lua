--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022 Peter Vaiko
Chopper Support added by Pops64

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

--[[

This is child of the combine unloader class.

Some things have to tweaked to make chopper unloaders work

Alot of pocket making functions have been removed or there calling function has been brought here and edited to not call

Unload Drivers make a U Turn when finished in aticipation of handling multiple unload drivers. To get out of the way

Chopper Unload Drivers reverse when the Chopper is turning to avoid being in its way

]]--

--- Strategy to unload choppers 
---@class AIDriveStrategyUnloadChopper : AIDriveStrategyUnloadCombine

AIDriveStrategyUnloadChopper = {}
local AIDriveStrategyUnloadChopper_mt = Class(AIDriveStrategyUnloadChopper, AIDriveStrategyUnloadCombine)

AIDriveStrategyUnloadChopper.myStates = {
    MOVING_AWAY_WITH_TRAILER_FULL = {collisionAvoidanceEnabled = true},
}


AIDriveStrategyUnloadChopper.myTurningForChopperStates = {
    WAITING_FOR_TURNING_CHOPPER = {openCoverAllowed = true},
    TURNING_AROUND_FOR_CHOPPER = {openCoverAllowed = true}
}
AIDriveStrategyUnloadChopper.UNLOAD_TYPES = {
    COMBINE = 1,
    SILO_LOADER = 2,
    CHOPPER = 3
}

-- Developer hack: to check the class of an object one should use the is_a() defined in CpObject.lua.
-- However, when we reload classes on the fly during the development, the is_a() calls in other modules still
-- have the old class definition (for example CombineUnloadManager.lua) of this class and thus, is_a() fails.
-- Therefore, use this instead, this is safe after a reload.
AIDriveStrategyUnloadChopper.isAChopperUnloadAIDriver = true

------------------------------------------------------------------------------------------------------------------------
-- Initilaztion functions
-------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadChopper.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyUnloadChopper_mt
    end
    local self = AIDriveStrategyUnloadCombine.new(customMt)
    self.unloadTargetType = self.UNLOAD_TYPES.CHOPPER
    self.whichUnloader = ''
    self.turningForChopperStates = CpUtil.initStates(self.combineUnloadStates, AIDriveStrategyUnloadChopper.myTurningForChopperStates)
    self.states = CpUtil.initStates(self.states, AIDriveStrategyUnloadChopper.myStates)
    self.combineUnloadStates = CpUtil.copyStates(self.combineUnloadStates, self.turningForChopperStates)
    self.states = CpUtil.copyStates(self.states, self.combineUnloadStates)
    return self
end

function AIDriveStrategyUnloadChopper:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyUnloadChopper:superClass().setAIVehicle(self, vehicle)
    self.proximityController:registerIgnoreObjectCallback(self, AIDriveStrategyUnloadChopper.ignoreChopper)
end

----------------------------------------------------------------------------------------------
-- Main Loop For Chopper Unload Driver
---------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadChopper:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()

    local moveForwards = not self.ppc:isReversing()
    local gx, gz

    ----------------------------------------------------------------
    if not moveForwards then
        local maxSpeed
        gx, gz, maxSpeed = self:getReverseDriveData()
        self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end

    -- make sure if we have a combine we stay registered
    if self.combineToUnload and self.combineToUnload:getIsCpActive() then
        local strategy = self.combineToUnload:getCpDriveStrategy()
        if strategy then
            if strategy.registerUnloader then
                strategy:registerUnloader(self, self.whichUnloader)
            else
                -- combine may have been stopped and restarted, so CP is active again but not yet the combine strategy,
                -- for instance it is now driving to work start, so it can't accept a registration
                self:debug('Lost my combine')
                self:startWaitingForSomethingToDo()
            end
        end
    end

    if self.combineToUnload == nil or not self.combineToUnload:getIsCpActive() then
        if CpUtil.isStateOneOf(self.state, self.combineUnloadStates) then

        end
    end

    if self:hasToWaitForAssignedCombine() then
        --- Safety check to make sure a combine is assigned, when needed.
        self:setMaxSpeed(0)
        self:debugSparse("Combine to unload lost during unload, waiting for something todo.")
        if self:isDriveUnloadNowRequested() then
            self:debug('Drive unload now requested')
            self:startUnloadingTrailers()
        end
    elseif self.state == self.states.INITIAL then
        if not self.startTimer then
            --- Only create one instance of the timer and wait until it finishes.
            self.startTimer = Timer.createOneshot(50, function ()
            --- Pipe measurement seems to be buggy with a few over loaders, like bergman RRW 500,
            --- so a small delay of 50 ms is inserted here before unfolding starts.
            self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
            self.state = self.states.IDLE
            self.startTimer = nil
            end)
        end
        self:setMaxSpeed(0)
    elseif self.state == self.states.IDLE then
        -- nothing to do right now, wait for one of the following:
        -- - combine calls
        -- - user sends us to unload the trailer
        -- - a trailer appears where we can unload our auger wagon if full
        self:setMaxSpeed(0)

        if self:isDriveUnloadNowRequested() then
            self:debug('Drive unload now requested')
            self:startUnloadingTrailers()
        elseif self.checkForTrailerToUnloadTo:get() and self:getAllTrailersFull(self.settings.fullThreshold:getValue()) then
            -- every now and then check if should attempt to unload our trailer/auger wagon
            self.checkForTrailerToUnloadTo:set(false, 10000)
            self:debug('Trailers over %d fill level', self.settings.fullThreshold:getValue())
            self:startUnloadingTrailers()
        end
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        -- just wait for the pathfinder to finish
        self:setMaxSpeed(0)

    elseif self.state == self.states.DRIVING_TO_COMBINE then

        self:driveToCombine()

    elseif self.state == self.states.TURNING_AROUND_FOR_CHOPPER then
        self:driveToCombine()

    elseif self.state == self.states.DRIVING_TO_MOVING_COMBINE then

        self:driveToMovingCombine()

    elseif self.state == self.states.UNLOADING_STOPPED_COMBINE then

        self:unloadStoppedCombine()
    elseif self.state == self.states.WAITING_FOR_MANEUVERING_COMBINE then

        self:waitForManeuveringCombine()

    elseif self.state == self.states.BACKING_UP_FOR_REVERSING_COMBINE then
        -- reversing combine asking us to move
        self:moveOutOfWay()

    elseif self.state == self.states.UNLOADING_MOVING_COMBINE then

        self:unloadMovingCombine(dt)
    
    elseif self.state == self.states.WAITING_FOR_TURNING_CHOPPER then
        -- Check to see if the chopper is still turning
        self:chopperIsManeuvering()

    elseif self.state == self.states.MOVING_AWAY_FROM_OTHER_VEHICLE then
        -- someone is blocking us or we are blocking someone
        self:moveAwayFromOtherVehicle()

    elseif self.state == self.states.MOVING_AWAY_WITH_TRAILER_FULL then
        
        self:setMaxSpeed(self:getFieldSpeed())
        
    elseif self.state == self.states.MOVING_BACK then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        -- drive back until the combine is in front of us
        local _, _, dz = self:getDistanceFromCombine(self.state.properties.vehicle)
        if dz > 0 then
            self:startWaitingForSomethingToDo()
        end

    elseif self.state == self.states.DRIVING_TO_SELF_UNLOAD then
        self:driveToSelfUnload()
    elseif self.state == self.states.WAITING_FOR_AUGER_PIPE_TO_OPEN then
        self:waitForAugerPipeToOpen()
    elseif self.state == self.states.UNLOADING_AUGER_WAGON then
        moveForwards = self:unloadAugerWagon()
    elseif self.state == self.states.MOVING_TO_NEXT_FILL_NODE then
        moveForwards = self:moveToNextFillNode()
    elseif self.state == self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER then
        self:moveAwayFromUnloadTrailer()
    elseif self.state == self.states.DRIVING_BACK_TO_START_POSITION_WHEN_FULL then
        self:setMaxSpeed(self:getFieldSpeed())
        ---------------------------------------------
        --- Unloading on the field
        ---------------------------------------------
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION then
        self:setMaxSpeed(self:getFieldSpeed())
    elseif self.state == self.states.WAITING_UNTIL_FIELD_UNLOAD_IS_ALLOWED then
        self:waitingUntilFieldUnloadIsAllowed()
    elseif self.state == self.states.PREPARE_FOR_FIELD_UNLOAD then
        self:prepareForFieldUnload()
    elseif self.state == self.states.UNLOADING_ON_THE_FIELD then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    elseif self.state == self.states.DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION then
        self:setMaxSpeed(self:getFieldSpeed())
    elseif self.state == self.states.REVERSING_TO_THE_FIELD_UNLOAD_HEAP then
        self:driveToReverseFieldUnloadHeap()
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_PARK_POSITION then
        self:setMaxSpeed(self:getFieldSpeed())
    end

    self:checkProximitySensors(moveForwards)

    self:checkCollisionWarning()
    return gx, gz, moveForwards, self.maxSpeed, 100
end

------------------------------------------------------------------------------------------------------------------------
-- On last waypoint
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadChopper:onLastWaypointPassed()
    self:debug('Last waypoint passed')
    if self.state == self.states.DRIVING_TO_COMBINE then
        if self:isOkToStartUnloadingCombine() then
            -- Right behind the combine, aligned, go for the pipe
            self:startUnloadingCombine()
        else
            self:startWaitingForSomethingToDo()
        end
    elseif self.state == self.states.DRIVING_TO_MOVING_COMBINE then
        self:startCourseFollowingCombine()
    elseif self.state == self.states.BACKING_UP_FOR_REVERSING_COMBINE then
        self:setNewState(self.stateAfterMovedOutOfWay)
        self:startRememberedCourse()
    elseif self.state == self.states.MOVING_AWAY_FROM_OTHER_VEHICLE then
        self:startWaitingForSomethingToDo()
    elseif self.state == self.states.MOVING_AWAY_WITH_TRAILER_FULL then
        self:startUnloadingTrailers()
    elseif self.state == self.states.DRIVING_BACK_TO_START_POSITION_WHEN_FULL then
        self:debug('Inverted goal position reached, so give control back to the job.')
        self.vehicle:getJob():onTrailerFull(self.vehicle, self)
        ---------------------------------------------
        --- Self unload
        ---------------------------------------------
    elseif self.state == self.states.DRIVING_TO_SELF_UNLOAD then
        self:onLastWaypointPassedWhenDrivingToSelfUnload()
    elseif self.state == self.states.MOVING_TO_NEXT_FILL_NODE then
        -- should just for safety
        self:startMovingAwayFromUnloadTrailer()
    elseif self.state == self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER then
        self:onMovedAwayFromUnloadTrailer()
        ---------------------------------------------
        --- Unloading on the field
        ---------------------------------------------
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION then
        self:setNewState(self.states.WAITING_UNTIL_FIELD_UNLOAD_IS_ALLOWED)
    elseif self.state == self.states.UNLOADING_ON_THE_FIELD then
        self:onFieldUnloadingFinished()
    elseif self.state == self.states.DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION then
        self:onReverseFieldUnloadPositionReached()
    elseif self.state == self.states.REVERSING_TO_THE_FIELD_UNLOAD_HEAP then
        self:onReverseFieldUnloadHeapReached()
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_PARK_POSITION then
        self:onFieldUnloadParkPositionReached()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start moving away from Chopper because our trailer is full
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadChopper:startMovingAwayFromChopper(newState, combine)
    -- Create a Node facing the oppistote direction
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(self.vehicle:getAIDirectionNode())
    local goal = CpUtil.createNode("goal", x, z, yRot + math.pi)

    -- Deterime what side the offset should be applied
    local offsetFix = -(self.combineOffset/math.abs(self.combineOffset))
    local offsetX = math.max(math.abs(self.combineOffset * 2), self.turningRadius * 2)
    offsetX = offsetX * offsetFix

    self:debug('Creating chopper drive away course at x=%d z=%d offsetX=%d', x, z, offsetX)
    local path, length = PathfinderUtil.findAnalyticPath(PathfinderUtil.dubinsSolver, self.vehicle.rootNode, 0, goal,
    offsetX, -10, self.turningRadius)
    if path then
        self:debug('I found a Anayltice Path and I am now going to drive it')
        self.driveAwayFromChopperCourse = Course.createFromAnalyticPath(self.vehicle, path, true)
        self.driveAwayFromChopperCourse:extend(AIDriveStrategyUnloadCombine.driveToCombineCourseExtensionLength, dx, dz)
        self:startCourse(self.driveAwayFromChopperCourse, 1)
    else
        self.driveAwayFromChopperCourse = Course.createStraightForwardCourse(self.vehicle, 50)
        self:startCourse(self.driveAwayFromChopperCourse, 1)
    end
    self:setNewState(newState)
    self.state.properties.vehicle = combine
    return
end

------------------------------------------------------------------------------------------------------------------------
-- Unload combine (moving)
-- We are driving on a copy of the combine's course with an offset
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadChopper:startCourseFollowingCombine()
    local startIx
    self.followCourse, startIx = self:setupFollowCourse()
    self.combineOffset = self:getPipeOffset(self.combineToUnload)
    self.followCourse:setOffset(-self.combineOffset, 0)
    -- try to find the waypoint closest to the vehicle, as startIx we got is right beside the combine
    -- which may be far away and if that's our target, PPC will be slow to bring us back on the course
    -- and we may end up between the end of the pipe and the combine
    -- use a higher look ahead as we may be in front of the combine
    local nextFwdIx, found = self.followCourse:getNextFwdWaypointIxFromVehiclePosition(startIx,
            self.vehicle:getAIDirectionNode(), self.combineToUnload:getCpDriveStrategy():getWorkWidth(), 20)
    if found then
        startIx = nextFwdIx
    end
    self:debug('Will follow combine\'s course at waypoint %d, side offset %.1f', startIx, self.followCourse.offsetX)
    self:startCourse(self.followCourse, startIx)
    self:setNewState(self.states.UNLOADING_MOVING_COMBINE)
end

function AIDriveStrategyUnloadChopper:unloadMovingCombine()

    -- ignore combine for the proximity sensor
    -- self:ignoreVehicleProximity(self.combineToUnload, 3000)
    -- make sure the combine won't slow down when seeing us
    -- self.combineToUnload:getCpDriveStrategy():ignoreVehicleProximity(self.vehicle, 3000)

    local combineStrategy = self.combineToUnload:getCpDriveStrategy()

    if self:changeToUnloadWhenTrailerFull() then
        return
    end

    self:driveBesideCombine()

    -- combine stopped in the meanwhile, like for example end of course
    if combineStrategy:willWaitForUnloadToFinish() then
        self:debug('change to unload stopped combine')
        self:setNewState(self.states.UNLOADING_STOPPED_COMBINE)
        return
    end
    -- The chopper row may 
    if combineStrategy:isManeuvering() then
        -- Create a backup course so we stay out of the way of turning Chopper
        local reverseCourse = Course.createStraightReverseCourse(self.vehicle, 100)
        self:startCourse(reverseCourse, 1)
        self:setNewState(self.states.WAITING_FOR_TURNING_CHOPPER)
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Waiting for maneuvering chopper
-----------------------------------------------`-------------------------------------------------------------------------

function AIDriveStrategyUnloadChopper:chopperIsManeuvering()
    if self:changeToUnloadWhenTrailerFull() then
        return
    end
    
    if self.combineToUnload:getCpDriveStrategy():isManeuvering() then
        
        -- Back up until the chopper is in front us so we don't interfer with its turn and make sure we stay behind it
        local _, _, dz = self:getDistanceFromCombine(self.combineToUnload)
        if dz < 0 then
            self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        elseif dz > -3 then
            self:setMaxSpeed(0)
        end
    elseif not self:isBehindAndAlignedToCombine() and not self:isInFrontAndAlignedToMovingCombine() then
        self:debug('Combine has finished turning we need to turn now')
        -- Turn around to meet back up with the combine
        self:pathfinderForUnloadChopperTurn()
    else
        -- The chopper is finsihed turning but didn't turn far resume previous state
        self:startCourseFollowingCombine()
    end
end

function AIDriveStrategyUnloadChopper:pathfinderForUnloadChopperTurn()
    self:debug('Chopper finished turning I need to turn around to')
    local xOffset, zOffset = self:getPipeOffset(self.combineToUnload)
    
    self:startPathfindingToCombine(self.onPathfindingDoneChopperTurn, xOffset, -10)
end

function AIDriveStrategyUnloadChopper:onPathfindingDoneChopperTurn(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, CpUtil.getName(self.combineToUnload)) and self.state == self.states.WAITING_FOR_PATHFINDER then
        local turnAroundForChopper = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        -- add a short straight section to align in case we get there before the combine
        -- pathfinding does not guarantee the last section points into the target direction so we may
        -- end up not parallel to the combine's course when we extend the pathfinder course in the direction of the
        -- last waypoint. Therefore, use the rendezvousWaypoint's direction instead
        -- Update the redezouswaypoint so the exensition course gets addeded
        self.rendezvousWaypoint = self.combineCourse and self.combineCourse:getWaypoint(self.combineCourse:getCurrentWaypointIx())
        local dx = self.rendezvousWaypoint and self.rendezvousWaypoint.dx
        local dz = self.rendezvousWaypoint and self.rendezvousWaypoint.dz
        turnAroundForChopper:extend(AIDriveStrategyUnloadCombine.driveToCombineCourseExtensionLength, dx, dz)
        self:startCourse(turnAroundForChopper, 1)
        self:setNewState(self.states.TURNING_AROUND_FOR_CHOPPER)
        return true
    else
        self:startWaitingForSomethingToDo()
        return false
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Check for full trailer when unloading a combine
---@return boolean true when changed to unload course
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadChopper:changeToUnloadWhenTrailerFull()
    --when trailer is full then go to unload
    if self:isDriveUnloadNowRequested() or self:getAllTrailersFull() then
        if self:isDriveUnloadNowRequested() then
            self:debug('drive now requested, changing to unload course.')
        else
            self:debug('trailer full, changing to unload course.')
        end
        if self.combineToUnload:getCpDriveStrategy():isTurning() or
                self.combineToUnload:getCpDriveStrategy():isAboutToTurn() then
            self:debug('... but we are too close to the end of the row, or combine is turning, moving back before changing to unload course')
        elseif self.combineToUnload and self.combineToUnload:getCpDriveStrategy():isAboutToReturnFromPocket() then
            self:debug('... letting the combine return from the pocket')
        else
            self:debug('... moving back a little in case AD wants to take over')
        end
        self:releaseCombine()
        self:startMovingAwayFromChopper(self.states.MOVING_AWAY_WITH_TRAILER_FULL, self.combineJustUnloaded)
        return true
    end
    return false
end

------------------------------------------------------------------------------------------------------------------------
-- Combine is reversing and we are behind it
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadChopper:requestToBackupForReversingCombine(blockedVehicle)
    if not self.vehicle:getIsCpActive() then
        return
    end
    self:debug('%s wants me to move out of way', blockedVehicle:getName())
    if self.state ~= self.states.BACKING_UP_FOR_REVERSING_COMBINE and
            self.state ~= self.states.MOVING_BACK and
            self.state ~= self.states.MOVING_AWAY_FROM_OTHER_VEHICLE and
            self.state ~= self.states.MOVING_AWAY_WITH_TRAILER_FULL
    then
        -- reverse back a bit, this usually solves the problem
        -- TODO: there may be better strategies depending on the situation
        self:rememberCourse(self.course, self.course:getCurrentWaypointIx())
        self.stateAfterMovedOutOfWay = self.state

        local reverseCourse = Course.createStraightReverseCourse(self.vehicle, self.maxDistanceWhenMovingOutOfWay)
        self:startCourse(reverseCourse, 1)
        self:debug('Moving out of the way for %s', blockedVehicle:getName())
        self:setNewState(self.states.BACKING_UP_FOR_REVERSING_COMBINE)
        self.state.properties.vehicle = blockedVehicle
        -- this state ends when we reach the end of the course or when the combine stops reversing
    else
        self:debug('Already busy moving out of the way')
    end
end

---------------------------------------------------------------------------------------------------------------------
-- Utilites for Chopper Unload Driver
--------------------------------------------------------------------------------------------------------------------

-- We don't care if we hit the chopper when unloading. Was causing issues durning turns
function AIDriveStrategyUnloadChopper:ignoreChopper(object, vehicle, moveForwards, hitTerrain)
    return self.state == self.states.UNLOADING_MOVING_COMBINE and vehicle == self.combineToUnload
end

function AIDriveStrategyUnloadChopper.isActiveCpChopperUnloader(vehicle)
    if vehicle.getIsCpCombineUnloaderActive and vehicle:getIsCpCombineUnloaderActive() then
        local strategy = vehicle:getCpDriveStrategy()
        if strategy then
            local unloadTargetType = strategy:getUnloadTargetType()            
            if unloadTargetType ~= nil then
                return unloadTargetType == AIDriveStrategyUnloadChopper.UNLOAD_TYPES.CHOPPER
            end
        end
    end
    return false
end

-- Adjust offfield pentaly 
function AIDriveStrategyUnloadChopper:getOffFieldPenalty(combineToUnload)
    local offFieldPenalty = AIDriveStrategyUnloadChopper:superClass().getOffFieldPenalty(self, combineToUnload)
    if combineToUnload then
        if combineToUnload:getCpDriveStrategy():hasNoHeadlands() then
            -- when the combine has no headlands, chances are that we have to drive off-field to turn around,
            -- so make the life easier for the pathfinder
            offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty / 5
            self:debug('Combine has no headlands, reducing off-field penalty for pathfinder to %.1f', offFieldPenalty)
        end
    end
    return offFieldPenalty
end

--- Interface function for a combine to call the unloader.
---@param combine table the combine vehicle calling
---@param waypoint Waypoint if given, the combine wants to meet the unloader at this waypoint, otherwise wants the
--- unloader to come to the combine.
---@return boolean true if the unloader has accepted the request
function AIDriveStrategyUnloadChopper:call(combine, waypoint, whichUnloader)
    if waypoint then
        -- combine set up a rendezvous waypoint for us, go there
        local xOffset, zOffset = self:getPipeOffset(combine)
        if self:isPathfindingNeeded(self.vehicle, waypoint, xOffset, zOffset, 25) then
            self.whichUnloader = whichUnloader
            self.rendezvousWaypoint = waypoint
            self.combineToUnload = combine
            self:setNewState(self.states.WAITING_FOR_PATHFINDER)
            -- just in case, as the combine may give us a rendezvous waypoint
            -- where it is full, make sure we are behind the combine
            zOffset = -self:getCombinesMeasuredBackDistance() - 30
            self:debug('call: Start pathfinding to rendezvous waypoint, xOffset = %.1f, zOffset = %.1f', xOffset, zOffset)
            self:startPathfinding(self.rendezvousWaypoint, xOffset, zOffset,
                    CpFieldUtil.getFieldNumUnderVehicle(self.combineToUnload),
                    { self.combineToUnload }, self.onPathfindingDoneToMovingCombine)
            return true
        else
            self:debug('call: Rendezvous waypoint to moving combine too close, wait a bit')
            self:startWaitingForSomethingToDo()
            return false
        end
    else
        -- combine wants us to drive directly to it
        self:debug('call: Combine is waiting for unload, start finding path to combine')
        self.combineToUnload = combine
        local zOffset
        if self.combineToUnload:getCpDriveStrategy():isWaitingForUnloadAfterPulledBack() then
            -- combine pulled back so it's pipe is now out of the fruit. In this case, if the unloader is in front
            -- of the combine, it sometimes finds a path between the combine and the fruit to the pipe, we are trying to
            -- fix it here: the target is behind the combine, not under the pipe. When we get there, we may need another
            -- (short) pathfinding to get under the pipe.
            zOffset = -self:getCombinesMeasuredBackDistance() - 10
        else
            -- allow trailer space to align after sharp turns (noticed it more affects potato/sugarbeet harvesters with
            -- pipes close to vehicle)
            local pipeLength = math.abs(self:getPipeOffset(self.combineToUnload))
            -- allow for more align space for shorter pipes
            zOffset = -self:getCombinesMeasuredBackDistance() - (pipeLength > 6 and 2 or 10)
        end
        self.whichUnloader = whichUnloader
        self:startPathfindingToCombine(self.onPathfindingDoneToCombine, nil, zOffset)
        return true
    end
end

function AIDriveStrategyUnloadChopper:startWaitingForSomethingToDo()
    if self.state ~= self.states.IDLE then
        self:releaseCombine()
        self.whichUnloader = ''
        self.course = Course.createStraightForwardCourse(self.vehicle, 25)
        self:setNewState(self.states.IDLE)
    end
end

function AIDriveStrategyUnloadChopper:releaseCombine()
    self.combineJustUnloaded = nil
    if self.combineToUnload and self.combineToUnload:getIsCpActive() then
        local strategy = self.combineToUnload:getCpDriveStrategy()
        if strategy and strategy.deregisterUnloader then
            strategy:deregisterUnloader(self, self.whichUnloader)
        end
        self.combineJustUnloaded = self.combineToUnload
    end
    self.combineToUnload = nil
end

function AIDriveStrategyUnloadChopper:isUnloaderTurning()
    return CpUtil.isStateOneOf(self.state, self.turningForChopperStates)
end

function AIDriveStrategyUnloadChopper:readyToRecive()
    return self.state == self.states.UNLOADING_MOVING_COMBINE
end


------------------------------------------------------------------------------------------------------------------------
-- Drive to moving combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:driveToMovingCombine()

    self:checkForCombineProximity()

    self:setFieldSpeed()

    self:checkForCombineTurnArea()

    -- stop when too close to a combine not ready to unload (wait until it is done with turning for example)
    if self:isWithinSafeManeuveringDistance(self.combineToUnload) and self.combineToUnload:getCpDriveStrategy():isManeuvering() then
        self:startWaitingForManeuveringCombine()
    elseif self:isOkToStartUnloadingCombine() then
        self:startUnloadingCombine()
    end

    if self.combineToUnload:getCpDriveStrategy():isWaitingForUnload() then
        self:debug('combine is now stopped and waiting for unload, wait for it to call again')
        self:startWaitingForSomethingToDo()
        return
    end

    if self.course:isCloseToLastWaypoint(AIDriveStrategyUnloadCombine.driveToCombineCourseExtensionLength / 2) and
            self.combineToUnload:getCpDriveStrategy():hasRendezvousWith(self.vehicle) then
        if self.combineToUnload:getCpDriveStrategy():isReadyToUnload(true) and self:isBehindAndAlignedToCombine(false, 75) then
            self:startUnloadingCombine()
        else
            self:debugSparse('Combine is late, waiting ...')
            self:setMaxSpeed(0)
        end
        -- stop confirming the rendezvous, allow the combine to time out if it can't get here on time
    else
        -- yes honey, I'm on my way!
        self.combineToUnload:getCpDriveStrategy():reconfirmRendezvous()
    end
end

function AIDriveStrategyUnloadCombine:isBehindAndAlignedToCombine(debugEnabled, maxDistanceBehind)
    local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)
    local pipeOffset = self:getPipeOffset(self.combineToUnload)
    if dz > 0 then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: dz > 0')
        return false
    end
    -- TODO: this does not take the pipe's side into account, and will return true when we are at the
    -- wrong side of the combine. That happens rarely as we
    if not self:isLinedUpWithPipe(dx, pipeOffset, 0.5) then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: dx > 1.5 pipe offset (%.1f > 1.5 * %.1f)', dx, pipeOffset)
        return false
    end
    local d = MathUtil.vector2Length(dx, dz)
    if d > (maxDistanceBehind or 30) then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: too far from combine (%.1f > 30)', d)
        return false
    end
    if not CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(),
            AIDriveStrategyUnloadCombine.maxDirectionDifferenceDeg) then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: direction difference is > %d)',
                AIDriveStrategyUnloadCombine.maxDirectionDifferenceDeg)
        return false
    end
    -- close enough and approximately same direction and behind and not too far to the left or right, about the same
    -- direction
    return true
end