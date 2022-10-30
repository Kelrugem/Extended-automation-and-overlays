function onInit()
	registerOptions();
end

function registerOptions()
	OptionsManager.registerOption2("FFOS",false, "option_header_overlays", "option_label_FFOS", "option_entry_cycler", 
		{ labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
	OptionsManager.registerOption2("WO",false, "option_header_overlays", "option_label_WO", "option_entry_cycler", 
		{ labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
	OptionsManager.registerOption2("SO",false, "option_header_overlays", "option_label_SO", "option_entry_cycler", 
		{ labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
	OptionsManager.registerOption2("REVERT",false, "option_header_overlays", "option_label_REV", "option_entry_cycler", 
		{ labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
end
