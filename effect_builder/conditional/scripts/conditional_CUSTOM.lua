function createEffectString()
    return negator.getStringValue() .. target.getStringValue() .. ": CUSTOM(" .. condition.getValue() .. ")"
end
