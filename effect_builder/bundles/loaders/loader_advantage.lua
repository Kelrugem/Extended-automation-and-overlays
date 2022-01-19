function onInit()
    if LoaderExtendedAutomation.isEffectBuilderLoaded then
        EditorLoader.loadEditors("advantageEditors",
        {
            {
                labelres ="initiative",
                value = "ADVINIT"
            },
            {
                labelres ="atk",
                value = "ADVATK"
            },
            {
                labelres ="save",
                value = "ADVSAV"
            }
        })
    end
end
