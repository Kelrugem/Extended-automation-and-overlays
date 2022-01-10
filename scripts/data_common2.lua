-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

-- KEL
tnodex = {
	"climbing",
	"running",
	"squeezing",
	"blinded",
	"pinned",
	"stunned",
	"unconscious",
	"paralyzed",
	"petrified",
	"helpless",
	"grantca",
	"flatfooted",
	"flat-footed"
}

iftagcomp = {
	"poison",
	"sleep",
	"paralysis",
	"petrification",
	"charm",
	"sleep",
	"fear",
	"disease",
	"mind-affecting",
	"mindaffecting"
}
-- END
tconstructtraits = {
	"mindaffecting",
	"death",
	"necromancy",
	"paralysis",
	"poison",
	"sleep"	
}
tdragontraits = {
	"sleep",
	"paralysis"
}
telementaltraits = {
	"poison",
	"sleep",
	"paralysis"
}
toozetraits = {
	"poison",
	"sleep",
	"paralysis",
	"polymorph"
}
tplanttraits = {
	"mindaffecting",
	"paralysis",
	"poison",
	"sleep"
}
tundeadtraits = {
	"mindaffecting",
	"death",
	"disease",
	"paralysis",
	"poison",
	"sleep"
}
tvermintraits = {
	"mindaffecting"
}
-- Adding ethereal; need to overwrite full vector for ordering
conditions = {
	"blinded", 
	"climbing",
	"confused",
	"cowering",
	"dazed",
	"dazzled",
	"deafened", 
	"entangled",
	"ethereal",
	"exhausted",
	"fascinated",
	"fatigued",
	"flat-footed",
	"frightened", 
	"grappled", 
	"helpless",
	"incorporeal", 
	"invisible", 
	"kneeling",
	"nauseated",
	"panicked", 
	"paralyzed",
	"petrified",
	"pinned", 
	"prone", 
	"rebuked",
	"running",
	"shaken", 
	"sickened", 
	"sitting",
	"slowed", 
	"squeezing", 
	"stable", 
	"stunned",
	"turned",
	"unconscious"
};

function onInit()
	table.insert(DataCommon.targetableeffectcomps, "DMGS");
	table.insert(DataCommon.targetableeffectcomps, "SR");
	table.insert(DataCommon.targetableeffectcomps, "SIMMUNE");
	table.insert(DataCommon.targetableeffectcomps, "PROT");
	table.insert(DataCommon.dmgtypes, "ghost touch");
	table.insert(DataCommon.dmgtypes, "bleed");
	table.insert(DataCommon.specialdmgtypes, "bleed");
	table.insert(DataCommon.immunetypes, "bleed");
	table.insert(DataCommon.energytypes, "bleed");
	table.insert(DataCommon.dmgtypes, "injury");
	table.insert(DataCommon.specialdmgtypes, "injury");
	table.insert(DataCommon.immunetypes, "injury");
	table.insert(DataCommon.dmgtypes, "immunebypass");
	table.insert(DataCommon.specialdmgtypes, "immunebypass");
	table.insert(DataCommon.dmgtypes, "vorpal");
	table.insert(DataCommon.specialdmgtypes, "vorpal");
	table.insert(DataCommon.dmgtypes, "resistbypass");
	table.insert(DataCommon.specialdmgtypes, "resistbypass");
	table.insert(DataCommon.dmgtypes, "resisthalved");
	table.insert(DataCommon.specialdmgtypes, "resisthalved");
	table.insert(DataCommon.dmgtypes, "drbypass");
	table.insert(DataCommon.specialdmgtypes, "drbypass");
	table.insert(DataCommon.energytypes, "drbypass");
	table.insert(DataCommon.dmgtypes, "bypass");
	table.insert(DataCommon.specialdmgtypes, "bypass");
	table.insert(DataCommon.energytypes, "bypass");
	DataCommon.conditions = conditions;
	-- KEL Removing certain things for IFTAG parsing to avoid additional unneeded effects
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	table.remove(DataCommon.immunetypes, 8);
	-- KEL Modifier buttons
	ModifierManager.addModWindowPresets({ { sCategory = "damage", tPresets = { "DMG_INJURY", "DMG_ACCURACY" } } });
	ModifierManager.addModWindowPresets({ { sCategory = "general", tPresets = { "ADV", "DISADV" } } });
	ModifierManager.addKeyExclusionSets({ { "ADV", "DISADV" } });
	
	if not DataCommon.isPFRPG() then
		table.insert(tnodex, "grappled");
	end
end
