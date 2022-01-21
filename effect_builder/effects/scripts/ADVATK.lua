function createEffectString()
    local effectString = direction.getStringValue() .. advantage.getStringValue() .. "ATK"
    local descriptors = {}
    local effectRange = effect_range.getStringValue()
    if effectRange ~= "" then
        table.insert(descriptors, effectRange)
    end
    if effect_opportunity.getValue() > 0 then
        table.insert(descriptors, "opportunity")
    end

    if next(descriptors) then
        effectString = effectString .. ": " .. table.concat(descriptors, ",")
    end
    return effectString
end
