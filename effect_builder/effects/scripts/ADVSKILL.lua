function createEffectString()
    local effectString = advantage.getStringValue() .. "SKILL"
    local descriptors = {}
    if not skill.isEmpty() then
        table.insert(descriptors, skill.getValue())
    end
    if not ability.isEmpty() then
        table.insert(descriptors, ability.getValue())
    end

    if next(descriptors) then
        effectString = effectString .. ": " .. table.concat(descriptors, ",")
    end

    return effectString
end
