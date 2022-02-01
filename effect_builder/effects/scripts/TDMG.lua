function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ": " .. dice_value.getStringValue()
    local descriptors = {}
    local damageType = damage_types.getStringValue()
    if damageType ~= "" then
        table.insert(descriptors, damageType)
    end
    local effectRange = effect_range.getStringValue()
    if effectRange ~= "" then
        table.insert(descriptors, effectRange)
    end

    if next(descriptors) then
        effectString = effectString .. " " .. table.concat(descriptors, ",")
    end

    return effectString
end
