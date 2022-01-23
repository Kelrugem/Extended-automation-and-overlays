function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ": " .. effect_modifier.getValue()
    if not effect_bonus_type.isEmpty() then
        effectString = effectString .. " " .. effect_bonus_type.getValue()
    end
    return effectString
end
