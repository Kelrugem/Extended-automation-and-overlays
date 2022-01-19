-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	super.super.onInit();
	-- KEL Darrenan had here onFactionChanged(); Why?
	onHealthChanged();
end

function onFactionChanged()
	super.super.onFactionChanged();
	updateHealthDisplay();
end

function onHealthChanged()
	local rActor = ActorManager.resolveActor(getDatabaseNode());
	local sColor = ActorHealthManager.getHealthColor(rActor);
	
	wounds.setColor(sColor);
    injury.setColor(sColor);
	status.setColor(sColor);
end

function updateHealthDisplay()
	local sOption;
	if friendfoe.getStringValue() == "friend" then
		sOption = OptionsManager.getOption("SHPC");
	else
		sOption = OptionsManager.getOption("SHNPC");
	end
	
	if sOption == "detailed" then
		hp.setVisible(true);
		hptemp.setVisible(true);
		wounds.setVisible(true);
        injury.setVisible(true);
		status.setVisible(false);
	elseif sOption == "status" then
		hp.setVisible(false);
		hptemp.setVisible(false);
		wounds.setVisible(false);
        injury.setVisible(false);
		status.setVisible(true);
	else
		hp.setVisible(false);
		hptemp.setVisible(false);
		wounds.setVisible(false);
        injury.setVisible(false);
		status.setVisible(false);
	end
end
