function createEffectString()
    return negator.getStringValue() .. target.getStringValue() .. ": SIZE(" .. comparator.getStringValue() .. size.getValue() .. ")"
end
