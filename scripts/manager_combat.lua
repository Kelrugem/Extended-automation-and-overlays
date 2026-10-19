-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local _fnOrigOnNPCPostAdd;
local _fnOrigGetEntryInitRecord;
local _fnOrigNextActor;
local _fnOrigNextRound;

function onInit()
	_fnOrigNextActor = CombatManager.nextActor;
	CombatManager.nextActor = nextActor;
	_fnOrigNextRound = CombatManager.nextRound;
	CombatManager.nextRound = nextRound;
end

function nextActor(bSkipBell, bNoRoundAdvance)
	_fnOrigNextActor(bSkipBell, bNoRoundAdvance);
	TokenManagerKel.clearSaveOverlays();
end
function nextRound(nRounds)
	_fnOrigNextRound(nRounds);
	TokenManagerKel.clearSaveOverlays();
end
