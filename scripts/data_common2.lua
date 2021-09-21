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
	table.insert(DataCommon.dmgtypes, "resistbypass");
	table.insert(DataCommon.specialdmgtypes, "resistbypass");
	table.insert(DataCommon.dmgtypes, "drbypass");
	table.insert(DataCommon.specialdmgtypes, "drbypass");
	table.insert(DataCommon.energytypes, "drbypass");
	table.insert(DataCommon.dmgtypes, "bypass");
	table.insert(DataCommon.specialdmgtypes, "bypass");
	table.insert(DataCommon.energytypes, "bypass");
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
	
	if not DataCommon.isPFRPG() then
		table.insert(tnodex, "grappled");
	end
end