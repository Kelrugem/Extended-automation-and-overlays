local modSkill

function onInit()
    modSkill = ActionSkill.modSkill
    ActionSkill.modSkill = modSkillAdvantage
end

function modSkillAdvantage(rSource, rTarget, rRoll, ...)
    modSkill(rSource, rTarget, rRoll, ...)
    Debug.chat(rSource, rTarget, rRoll)
    
    if rSource then
        local aSkillFilter = buildSkillFilter(rRoll)
        local aADVSAV = EffectManager35E.getEffectsByType(rSource, "ADVSKILL", aSkillFilter, rTarget, false, rRoll.tags)
        local aDISSAV = EffectManager35E.getEffectsByType(rSource, "DISSKILL", aSkillFilter, rTarget, false, rRoll.tags)
        Debug.chat(aADVSAV, aDISSAV)
        rRoll.adv = #aADVSAV - #aDISSAV
    end
end

function buildSkillFilter(rRoll)
    -- Determine skill used
    local sSkillLower = ""
    local sSkill = string.match(rRoll.sDesc, "%[SKILL%] ([^[]+)")
    if sSkill then
        sSkillLower = string.lower(StringManager.trim(sSkill))
    end

    -- Determine ability used with this skill
    local sActionStat = nil
    local sModStat = string.match(rRoll.sDesc, "%[MOD:(%w+)%]")
    if sModStat then
        sActionStat = DataCommon.ability_stol[sModStat]
    else
        for k, v in pairs(DataCommon.skilldata) do
            if string.lower(k) == sSkillLower then
                sActionStat = v.stat
            end
        end
    end

    -- Build effect filter for this skill
    local aSkillFilter = {}
    if sActionStat then
        table.insert(aSkillFilter, sActionStat)
    end
    local aSkillNameFilter = {}
    local aSkillWordsLower = StringManager.parseWords(sSkillLower)
    if #aSkillWordsLower > 0 then
        if #aSkillWordsLower == 1 then
            table.insert(aSkillFilter, aSkillWordsLower[1])
        else
            table.insert(aSkillFilter, table.concat(aSkillWordsLower, " "))
            if aSkillWordsLower[1] == "knowledge" or aSkillWordsLower[1] == "perform" or aSkillWordsLower[1] == "craft" then
                table.insert(aSkillFilter, aSkillWordsLower[1])
            end
        end
    end
    return aSkillFilter
end
