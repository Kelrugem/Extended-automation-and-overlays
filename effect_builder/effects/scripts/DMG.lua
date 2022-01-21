function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ": " .. StringManager.convertDiceToString(effect_dice.getDice(), effect_modifier.getValue())
    local descriptors = {}
    if not damage_type.isEmpty() then
        table.insert(descriptors, damage_type.getValue())
    end
    if not effect_bonus_type.isEmpty() then
        table.insert(descriptors, effect_bonus_type.getValue())
    end
    local effectRange = effect_range.getStringValue()
    if effectRange ~= "" then
        table.insert(descriptors, effectRange)
    end
    if effect_accuracy.getValue() > 0 then
        table.insert(descriptors, "accuracy")
    end

    if next(descriptors) then
        effectString = effectString .. " " .. table.concat(descriptors, ",")
    end

    return effectString
end
