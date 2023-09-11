-- A subclass of the combine controller to provide clean separation between Chopper specific functions and combine functions
-- Due to the interrelated nature of choppers and combines we should inherit the combine controller class
-- Chopper Support Added By Pops64 2023
---@class ChopperController : CombineController

ChopperController = CpObject(CombineController)

function ChopperController:init(vehicle, combine)
    CombineController.init(self, vehicle, combine)
end

-------------------------------------------------------------
--- Chopper
-------------------------------------------------------------

function ChopperController:getChopperDischargeDistance()
    local dischargeNode = self.implement:getCurrentDischargeNode()
    if self:isChopper() and dischargeNode and dischargeNode.maxDistance then
        return dischargeNode.maxDistance
    end
end

function ChopperController:isChopper()
    return self:getCapacity() > 10000000
end

function ChopperController:updateChopperFillType()
    --- Not exactly sure what this does, but without this the chopper just won't move.
    --- Copied from AIDriveStrategyCombine:update()
    -- This also exists in Giants AI drive strategy 
    -- no pipe, no discharge node
    local capacity = 0
    local dischargeNode = self.implement:getCurrentDischargeNode()

    if dischargeNode ~= nil then
        capacity = self.implement:getFillUnitCapacity(dischargeNode.fillUnitIndex)
    end

    if capacity == math.huge then
        local rootVehicle = self.implement.rootVehicle

        if rootVehicle.getAIFieldWorkerIsTurning ~= nil and not rootVehicle:getAIFieldWorkerIsTurning() then
            local trailer = NetworkUtil.getObject(self.implement.spec_pipe.nearestObjectInTriggers.objectId)

            if trailer ~= nil then
                local trailerFillUnitIndex = self.implement.spec_pipe.nearestObjectInTriggers.fillUnitIndex
                local fillType = self.implement:getDischargeFillType(dischargeNode)

                if fillType == FillType.UNKNOWN then
                    fillType = trailer:getFillUnitFillType(trailerFillUnitIndex)

                    if fillType == FillType.UNKNOWN then
                        fillType = trailer:getFillUnitFirstSupportedFillType(trailerFillUnitIndex)
                    end

                    self.implement:setForcedFillTypeIndex(fillType)
                else
                    self.implement:setForcedFillTypeIndex(nil)
                end
            end
        end
    end
end

-- Hack to force the chopper to only target CP unload drivers unless there is a human or none CP trailer in range
function ChopperController:updateNearestObjectInTriggers(superFunc, ...)
    local spec = self.spec_pipe
	spec.nearestObjectInTriggers.objectId = nil
	spec.nearestObjectInTriggers.fillUnitIndex = 0
	local minDistance = math.huge
	local dischargeNode = self:getDischargeNodeByIndex(self:getPipeDischargeNodeIndex())
    local chopper = self.getRootVehicle and self:getRootVehicle()

    if not chopper then
        return superFunc(self, ...)
    end
    -- We only want to use our modified version of this function when CP Chopper is driving
    if  not (chopper.getIsCpActive or chopper:getIsCpActive()) then
        return superFunc(self, ...)
    end
        
    local chopperDriver = chopper:getCpDriveStrategy() 

    if not chopperDriver or not chopperDriver.isAAIDriveStrategyChopperCourse then
        return superFunc(self, ...)
    end

	if dischargeNode ~= nil then
        
		local checkNode = Utils.getNoNil(dischargeNode.node, self.components[1].node)

		for object, _ in pairs(spec.objectsInTriggers) do
			local outputFillType = self:getFillUnitLastValidFillType(dischargeNode.fillUnitIndex)
            local unloadVehicle = object.getRootVehicle and object:getRootVehicle()
            
			for fillUnitIndex, _ in ipairs(object.spec_fillUnit.fillUnits) do
				local allowedToFillByPipe = object:getFillUnitSupportsToolType(fillUnitIndex, ToolType.DISCHARGEABLE)
				local supportsFillType = object:getFillUnitSupportsFillType(fillUnitIndex, outputFillType) or outputFillType == FillType.UNKNOWN
				local fillLevel = object:getFillUnitFreeCapacity(fillUnitIndex, outputFillType, self:getOwnerFarmId())

				if allowedToFillByPipe and supportsFillType and fillLevel > 0 then
					local targetPoint = object:getFillUnitAutoAimTargetNode(fillUnitIndex)
					local exactFillRootNode = object:getFillUnitExactFillRootNode(fillUnitIndex)

					if targetPoint == nil then
						targetPoint = exactFillRootNode
					end

					if targetPoint ~= nil then
                        -- We have a target check to see if it is a CP driver, if not default to going to closest in range. Original functionality
                        if unloadVehicle and unloadVehicle.getIsCpActive and unloadVehicle:getIsCpActive() then
                            local strategy = unloadVehicle:getCpDriveStrategy()
                            if  strategy.isAChopperUnloadAIDriver
                                    and chopperDriver:getCurrentUnloader()
                                    and chopperDriver:getCurrentUnloader().vehicle == unloadVehicle then
                                spec.nearestObjectInTriggers.objectId = NetworkUtil.getObjectId(object)
                                spec.nearestObjectInTriggers.fillUnitIndex = fillUnitIndex
                                break
                                    
                            end
                        else
                            local distance = calcDistanceFrom(checkNode, targetPoint)

                            if distance < minDistance then
                                minDistance = distance
                                spec.nearestObjectInTriggers.objectId = NetworkUtil.getObjectId(object)
                                spec.nearestObjectInTriggers.fillUnitIndex = fillUnitIndex

                                break
                            end
                        end
						
					end
				end
			end
		end
	else
		Logging.xmlWarning(self.xmlFile, "Unable to find discharge node index '%d' for pipe", self:getPipeDischargeNodeIndex())
	end
end

Pipe.updateNearestObjectInTriggers = Utils.overwrittenFunction(Pipe.updateNearestObjectInTriggers, ChopperController.updateNearestObjectInTriggers)