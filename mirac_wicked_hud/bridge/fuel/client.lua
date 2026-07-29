Hud.Fuel = Hud.Fuel or {}

local warned = false

local function nativeFuel(vehicle)
    return GetVehicleFuelLevel(vehicle)
end

local function stateBagFuel(vehicle)
    local state = Entity(vehicle).state
    return state and state[Config.FuelStateBag] or nil
end

local function exportFuel(vehicle)
    local resource = Config.FuelResource
    local exportName = Config.FuelExport

    if type(resource) ~= 'string' or resource == '' or GetResourceState(resource) ~= 'started' then
        return nil
    end
    if type(exportName) ~= 'string' or exportName == '' then return nil end

    local ok, value = pcall(function()
        local resourceExports = exports[resource]
        local fn = resourceExports and resourceExports[exportName]
        if type(fn) ~= 'function' then return nil end
        return fn(vehicle)
    end)

    return ok and value or nil
end

function Hud.Fuel.get(vehicle)
    if not vehicle or vehicle == 0 then return 0 end

    local value
    if Config.FuelSystem == 'statebag' then
        value = stateBagFuel(vehicle)
    elseif Config.FuelSystem == 'export' then
        value = exportFuel(vehicle)
    elseif Config.FuelSystem == 'custom' then
        -- Implement your custom fuel adapter in this branch.
        value = nil
    else
        value = nativeFuel(vehicle)
    end

    if value == nil then
        value = stateBagFuel(vehicle) or nativeFuel(vehicle)
        if not warned and Config.Client.nuiDebug then
            warned = true
            lib.print.warn(('[%s] Fuel adapter returned no value; native/statebag fallback is active.'):format(Hud.resource))
        end
    end

    return Hud.clamp(value, 0, 100) or 0
end
