UPDATE_INTERVAL              = 10

-- I currently cannot find any means to automatically calculate vehicle battery capacity and battery generation
-- (can't even enumerate RTG's and batteries), so you have to enter these values manually here

BATTERY_CAPACITY             = 309000 -- Battery capacity of your ship
BATTERY_GENERATION           = 6400   -- Battery generation of your ship

-- The level to which we can drain battery before limiting throttle to prevent battery stall.
-- For example, useful for maximizing LAMS power agains first, most dangerous, missile swarms at the beginning of the battle
ACCEPTABLE_BATTERY_FRACTION  = 0.8

ELECTRIC_ENGINE              = 35   -- ID of electric engine component
NEEDED_POWER_OUTPUT_OVERHEAD = 0.005 -- Min needed output addition to end up with small amount of spare power

_currentTick                 = 0
_currentPowerOutput          = 1

function Update(I)
	_currentTick = _currentTick + 1

	if _currentTick == 0 then
		ApplyElectricEngineOutput(I, 1.0)
		return
	end

	if _currentTick % UPDATE_INTERVAL == 0 then
		return
	end

	local batteryFraction         = I:GetEnergyFraction()
	local electricPowerFraction   = I:GetElectricPowerFraction()

	local batteryCapacity         = GetBatteryCapacity(I)
	local batteryGeneration       = GetBatteryGeneration(I)
	local batteryCharge           = batteryCapacity * batteryFraction
	local acceptableBatteryCharge = batteryCapacity * ACCEPTABLE_BATTERY_FRACTION

	-- doesn't seem to be a way to get requested power directly, so we have to calculate it
	local powerNeeded             = (1 - electricPowerFraction) * GetPowerGeneratedForGivenOutputLevel(batteryCapacity, _currentPowerOutput)
	if (electricPowerFraction == 0) then
		powerNeeded = 0x7FFFFFFF -- if for some reason we have no power available, set it to some large number
	end
	local neededOutput = GetMinOutputToSatisfyPowerDemand(batteryCharge, powerNeeded)

	local balancedOutputLevel
	if (batteryCharge > acceptableBatteryCharge) then
		-- No restrictions for battery draw
		balancedOutputLevel = 1
	else
		balancedOutputLevel = GetBalancedOutputLevel(batteryCharge, batteryGeneration)
	end

	local newPowerOutput = math.min(balancedOutputLevel, neededOutput)

	I:ClearLogs();
	I:Log('battery charge ' .. batteryCharge .. ' (' .. batteryFraction .. ')');
	I:Log('optimal output ' .. balancedOutputLevel);
	I:Log('needed electric power ' .. powerNeeded);
	I:Log('needed output level ' .. neededOutput);

	ApplyElectricEngineOutput(I, newPowerOutput)
end

function GetBatteryCapacity(I)
	return BATTERY_CAPACITY
	-- local capacity = 0

	-- for pair in BATTERY_BLOCKS do
	-- for i = 1, I:Component_GetCount(pair.id) do
	-- capacity += I:Component_GetFloatLogic(pair.id, i, BATTERY_LEVEL_LOGIC)
	-- end
	-- end

	-- return capacity
end

function GetBatteryGeneration(I)
	return BATTERY_GENERATION
end

function GetPowerGeneratedForGivenOutputLevel(batteryCapacity, outputLevel)
	return batteryCapacity * outputLevel / 25
end

function GetBalancedOutputLevel(batteryCapacity, batteryGeneration)
	return (math.sqrt((batteryCapacity + 200 * batteryGeneration) / batteryCapacity) - 1) / 2
end

function GetMinOutputToSatisfyPowerDemand(batteryCapacity, powerNeeded)
	return math.min(NEEDED_POWER_OUTPUT_OVERHEAD + 25 * powerNeeded / batteryCapacity, 1)
end

function ApplyElectricEngineOutput(I, outputLevel)
	for i = 0, I:Component_GetCount(ELECTRIC_ENGINE) - 1 do
		I:Component_SetFloatLogic(ELECTRIC_ENGINE, i, outputLevel)
	end

	_currentPowerOutput = outputLevel
end
