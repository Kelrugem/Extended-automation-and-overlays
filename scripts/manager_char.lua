local getWeaponAttackRollStructures_original
local getWeaponDamageRollStructures_original
function onInit()
    getWeaponAttackRollStructures_original = CharManager.getWeaponAttackRollStructures
    CharManager.getWeaponAttackRollStructures = getWeaponAttackRollStructures_new

    getWeaponDamageRollStructures_original = CharManager.getWeaponDamageRollStructures
    CharManager.getWeaponDamageRollStructures = getWeaponDamageRollStructures_new
end

function getWeaponAttackRollStructures_new(nodeWeapon, nAttack)
    rActor, rAttack = getWeaponAttackRollStructures_original(nodeWeapon, nAttack)
    if not rAttack then
        return rActor, rAttack
    end

    local sProperties = DB.getValue(nodeWeapon, "properties", ""):lower()
    rAttack.tags = StringManager.split(sProperties, ",;", true)

    return rActor, rAttack
end

function getWeaponDamageRollStructures_new(nodeWeapon)
    rActor, rDamage = getWeaponDamageRollStructures_original(nodeWeapon)
    if not rDamage then
        return rActor, rDamage
    end

    local sProperties = DB.getValue(nodeWeapon, "properties", ""):lower()
    rDamage.tags = StringManager.split(sProperties, ",;", true)

    return rActor, rDamage
end
