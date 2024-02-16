function onInit()
    ActionsManager.registerModHandler("skill", skillAdvantage);
end

function skillAdvantage(rSource, rTarget, rRoll, ...)
    if rSource then
        local aSkillFilter = buildSkillFilter(rRoll)
        local aAdvSkill = EffectManager35E.getEffectsByType(rSource, "ADVSKILL", aSkillFilter, rTarget, false, rRoll.tags)
		local aDisSkill = EffectManager35E.getEffectsByType(rSource, "DISSKILL", aSkillFilter, rTarget, false, rRoll.tags)
		local _, nAdvSkill = EffectManager35E.hasEffect(rSource, "ADVSKILL", rTarget, false, false, rRoll.tags)
		local _, nDisSkill = EffectManager35E.hasEffect(rSource, "DISSKILL", rTarget, false, false, rRoll.tags)
		rRoll.adv = #aAdvSkill + nAdvSkill - #aDisSkill + nDisSkill
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
