function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ": " ..  effect_modifier.getValue()
    if not damage_type.isEmpty() then
        effectString = effectString .. " " .. damage_type.getValue()
    end
    return effectString
end
