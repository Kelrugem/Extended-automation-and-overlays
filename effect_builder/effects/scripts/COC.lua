function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ": " .. dice_value.getStringValue()
    if not effect_bonus_type.isEmpty() then
        effectString = effectString .. " " .. effect_bonus_type.getValue()
    end
    return effectString
end
