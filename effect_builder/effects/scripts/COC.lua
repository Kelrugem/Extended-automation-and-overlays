function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ": " .. StringManager.convertDiceToString(effect_dice.getDice(), effect_modifier.getValue())
    if not effect_bonus_type.isEmpty() then
        effectString = effectString .. " " .. effect_bonus_type.getValue()
    end
    return effectString
end
