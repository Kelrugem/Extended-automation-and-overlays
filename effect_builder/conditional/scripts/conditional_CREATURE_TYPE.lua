function createEffectString()
    return negator.getStringValue() .. target.getStringValue() .. ": TYPE(" .. creature_type.getValue() .. ")"
end
