isEffectBuilderLoaded = false

local kelBundles = {
    {
        labelres ="editor_advantage",
        value = "editor_advantage"
    }
}

local function checkEffectBuilderLoaded()
    local extensions = {}
    for k, v in pairs(Extension.getExtensions()) do extensions[v] = k end
    return extensions["FG-Effect-Builder"] and extensions["FG-Effect-Builder-Plugin-35E-PFRPG"]
end

function onInit()
    isEffectBuilderLoaded = checkEffectBuilderLoaded()

    if isEffectBuilderLoaded then
        EditorLoader.loadEditors("editorBundles", kelBundles)
    end
end

