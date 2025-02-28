local getWeaponAttackRollStructures_original
function onInit()
    getWeaponAttackRollStructures_original = CharManager.getWeaponAttackRollStructures
    CharManager.getWeaponAttackRollStructures = getWeaponAttackRollStructures_new
end

function getWeaponAttackRollStructures_new(nodeWeapon, nAttack)
    rActor, rAttack = getWeaponAttackRollStructures_original(nodeWeapon, nAttack)
    if not rAttack then
        return rActor, rAttack
    end

    local sProperties = DB.getValue(nodeWeapon, "properties", ""):lower()
    rAttack.tags = StringManager.split(sProperties, ",", true)

    return rActor, rAttack
end
