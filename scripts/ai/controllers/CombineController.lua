--- For now only handles possible silage additives, if needed.
--- TODO: Straw swath handling should be moved here.
---@class CombineController : ImplementController
CombineController = CpObject(ImplementController)
function CombineController:init(vehicle, combine)
    ImplementController.init(self, vehicle, combine)
    self.combineSpec = combine.spec_combine
    self.settings = vehicle:getCpSettings()
    self.beaconLightsActive = false
    self.hasPipe = SpecializationUtil.hasSpecialization(Pipe, combine.specializations)
end

function CombineController:update()
	if self.settings.useAdditiveFillUnit:getValue() then 
		--- If the silage additive is empty, then stop the driver.
        local additives = self.combineSpec.additives
        if additives.available then 
            if self.implement:getFillUnitFillLevelPercentage(additives.fillUnitIndex) <= 0 then 
				self:debug("Stopped Cp, as the additive fill unit is empty.")
                self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
            end
        end
    end
end

function CombineController:getDriveData()
    local maxSpeed = nil 
    maxSpeed = self:updateThreshingDuringRain()
    self:updateBeaconLightsAndFullMessage()
    return nil, nil, nil, maxSpeed
end

function CombineController:getFillLevel()
    return self.implement:getFillUnitFillLevel(self.combineSpec.fillUnitIndex)
end

function CombineController:getFillLevelPercentage()
    return 100 * self.implement:getFillUnitFillLevel(self.combineSpec.fillUnitIndex) /
            self.implement:getFillUnitCapacity(self.combineSpec.fillUnitIndex)
end

function CombineController:getCapacity()
    return self.implement:getFillUnitCapacity(self.combineSpec.fillUnitIndex)
end

function CombineController:getFillUnitIndex()
    return self.combineSpec.fillUnitIndex
end

-------------------------------------------------------------
--- Combine 
-------------------------------------------------------------

function CombineController:updateThreshingDuringRain()
    local maxSpeed = nil 
    if self.implement:getIsThreshingDuringRain() and g_Courseplay.globalSettings.stopThreshingDuringRain:getValue() then 
        maxSpeed = 0
        self:setInfoText(InfoTextManager.WAITING_FOR_RAIN_TO_FINISH)
    else 
        self:clearInfoText(InfoTextManager.WAITING_FOR_RAIN_TO_FINISH)
    end
    return maxSpeed
end

function CombineController:updateBeaconLightsAndFullMessage()
    if self.hasPipe then
        --- Updates the beacon lights and the blinking hotspot.
        local dischargeNode = self.implement:getCurrentDischargeNode()
        if dischargeNode ~= nil then
            local fillLevel = self.implement:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
            local capacity = self.implement:getFillUnitCapacity(dischargeNode.fillUnitIndex)
            if fillLevel ~= nil and fillLevel ~= math.huge then
                if fillLevel > 0.8 * capacity then
                    if not self.beaconLightsActive then
                        self.vehicle:setAIMapHotspotBlinking(true)
                        self.vehicle:setBeaconLightsVisibility(true)
                        self.beaconLightsActive = true
                    end
                else
                    if self.beaconLightsActive then
                        self.vehicle:setAIMapHotspotBlinking(false)
                        self.vehicle:setBeaconLightsVisibility(false)
                        self.beaconLightsActive = false
                    end
                end
            end
        end
    end
end


function CombineController:updateStrawSwath(isOnHeadland)
    local strawMode = self.settings.strawSwath:getValue()
    if self.combineSpec.isSwathActive then
        if strawMode == CpVehicleSettings.STRAW_SWATH_OFF or isOnHeadland and strawMode == CpVehicleSettings.STRAW_SWATH_ONLY_CENTER then
            self:setStrawSwath(false)
            self:debug('straw swath should be off!')
        end
    else
        if strawMode ~= CpVehicleSettings.STRAW_SWATH_OFF then
            if isOnHeadland and strawMode == CpVehicleSettings.STRAW_SWATH_ONLY_CENTER then
                return
            end
            self:debug('straw swath should be on!')
            self:setStrawSwath(true)
        end
    end
end

function CombineController:setStrawSwath(enable)
    local strawSwathCanBeEnabled = false
    local fruitType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(self.implement:getFillUnitFillType(self:getFillUnitIndex()))
    if fruitType ~= nil and fruitType ~= FruitType.UNKNOWN then
        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitType)
        if fruitDesc.hasWindrow then
            strawSwathCanBeEnabled = true
        end
        self.implement:setIsSwathActive(enable and strawSwathCanBeEnabled)
    end
end

--- Is the combine currently dropping straw swath?
function CombineController:isDroppingStrawSwath()
    return self.combineSpec.strawPSenabled
end

function CombineController:isPotatoOrSugarBeetHarvester()
    for i, fillUnit in ipairs(self.implement:getFillUnits()) do
        if self.implement:getFillUnitSupportsFillType(i, FillType.POTATO) or
                self.implement:getFillUnitSupportsFillType(i, FillType.SUGARBEET) then
            self:debug('This is a potato or sugar beet harvester.')
            return true
        end
    end
    return false
end

