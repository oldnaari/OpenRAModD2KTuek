--[[
   Copyright 2007-2020 The OpenRA Developers (see AUTHORS)
   This file is part of OpenRA, which is free software. It is made
   available to you under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of
   the License, or (at your option) any later version. For more
   information, see COPYING.
]]



FremenReinforcementsStrong =
{
	easy =
	{
		{ "nsfremen", "nsfremen", "light_inf"},
	},

	normal =
	{
		{ "nsfremen", "nsfremen", "nsfremen" },
		{ "nsfremen", "nsfremen", "light_inf" },
		{ "nsfremen", "nsfremen", "light_inf", "light_inf"},
	},

	hard =
	{
		{ "nsfremen", "nsfremen", "nsfremen" },
		{ "nsfremen", "nsfremen", "light_inf" },
		{ "nsfremen", "nsfremen", "nsfremen" , "nsfremen" },
		{ "nsfremen", "nsfremen", "light_inf", "light_inf"},
	}
}


FremenReinforcementsWeak =
{
	easy =
	{
		{ "nsfremen", "light_inf"},
	},

	normal =
	{
		{ "nsfremen", "light_inf"},
	},

	hard =
	{
		{ "nsfremen", "light_inf"},
	}
}


FremenReinforcementsFinal =
{
	easy = {{ "nsfremen", "nsfremen", "light_inf", "trike"},},

	normal = {{ "nsfremen", "nsfremen", "light_inf", "light_inf", "trike"},},

	hard = {{ "nsfremen", "nsfremen", "nsfremen", "light_inf", "light_inf", "light_inf", "trike"},},
}


FremenReinforcements = {
	weak = FremenReinforcementsWeak,
	strong = FremenReinforcementsStrong,
	final = FremenReinforcementsFinal,
}

FremenWaves = {
	easy = {"strong", "strong", "weak", "weak", "final"},
	normal = {"strong", "strong", "strong", "weak", "weak", "weak","final"},
	hard = {"strong", "strong", "strong", "strong", "weak", "weak", "strong", "weak", "weak", "final"}
}

SmugglerReinforcementsOnWave = {
	easy = 4,
	normal = 4,
	hard = 5,
}
 

FremenEntryWaypoints = { FremenEntry.Location }

FremenPathToGatheringPoint = {
	{FremenEntry.Location, FremenMapCenterGatherPoint.Location},
	{FremenEntry.Location, FremenMidpoint1.Location},
	{FremenEntry.Location, FremenMidpoint2.Location}
}


FremenAttackDelay = {
	weak = 	DateTime.Seconds(25),
	strong = DateTime.Seconds(25),
	final = DateTime.Seconds(45),
}

ToHarvest =
{
	easy = 2500,
	normal = 3000,
	hard = 3500
}

SmugglersReinforcements = { "light_inf", "light_inf", "light_inf" }
SmugglersPath = { SmugglersEntry.Location, SmugglersRally.Location }
SmugglerSpeaker = "Adjutant"

Messages =
{
	"Build a concrete foundation before placing your buildings.",
	"Build a Wind Trap for power.",
	"Build a Refinery to collect Spice.",
	"Build a Silo to store additional Spice."
}

Tick = function()
	-- if FremenArrived and fremen.HasNoRequiredUnits() then
	-- 	player.MarkCompletedObjective(KillHarkonnen)
	-- end

	if player.Resources > SpiceToHarvest - 1 then
		player.MarkCompletedObjective(GatherSpice)
	end

	-- player has no Wind Trap
	if (player.PowerProvided <= 20 or player.PowerState ~= "Normal") and DateTime.GameTime % DateTime.Seconds(32) == 0 then
		HasPower = false
		Media.DisplayMessage(Messages[2], SmugglerSpeaker)
	else
		HasPower = true
	end

	-- player has no Refinery and no Silos
	if HasPower and player.ResourceCapacity == 0 and DateTime.GameTime % DateTime.Seconds(32) == 0 then
		Media.DisplayMessage(Messages[3], SmugglerSpeaker)
	end

	if HasPower and player.Resources > player.ResourceCapacity * 0.8 and DateTime.GameTime % DateTime.Seconds(32) == 0 then
		Media.DisplayMessage(Messages[4], SmugglerSpeaker)
	end

	UserInterface.SetMissionText("Harvested resources: " .. player.Resources .. "/" .. SpiceToHarvest, player.Color)
end

WorldLoaded = function()
	player = Player.GetPlayer("Smugglers")
	fremen = Player.GetPlayer("Fremen")

	SpiceToHarvest = ToHarvest[Difficulty]

	InitObjectives(player)
	KillSmugglers = fremen.AddPrimaryObjective("Kill all smuggler units.")
	GatherSpice = player.AddPrimaryObjective("Harvest " .. tostring(SpiceToHarvest) .. " Solaris worth of Spice.")
	-- KillHarkonnen = player.AddSecondaryObjective("Eliminate all Harkonnen units and reinforcements\nin the area.")

	local checkResourceCapacity = function()
		Trigger.AfterDelay(0, function()
			if player.ResourceCapacity < SpiceToHarvest then
				Media.DisplayMessage("We don't have enough silo space to store the required amount of Spice!", SmugglerSpeaker)
				Trigger.AfterDelay(DateTime.Seconds(3), function()
					fremen.MarkCompletedObjective(KillSmugglers)
				end)

				return true
			end
		end)
	end

	Trigger.OnRemovedFromWorld(SmugglersConyard, function()

		-- Mission already failed, no need to check the other conditions as well
		if checkResourceCapacity() then
			return
		end

		local refs = Utils.Where(Map.ActorsInWorld, function(actor) return actor.Type == "refinery" and actor.Owner == player end)
		if #refs == 0 then
			fremen.MarkCompletedObjective(KillSmugglers)
		else
			Trigger.OnAllRemovedFromWorld(refs, function()
				fremen.MarkCompletedObjective(KillSmugglers)
			end)

			local silos = Utils.Where(Map.ActorsInWorld, function(actor) return actor.Type == "silo" and actor.Owner == player end)
			Utils.Do(refs, function(actor) Trigger.OnRemovedFromWorld(actor, checkResourceCapacity) end)
			Utils.Do(silos, function(actor) Trigger.OnRemovedFromWorld(actor, checkResourceCapacity) end)
		end
	end)

	Media.DisplayMessage(Messages[1], "Mentat")
	CurrentWave = 1
	RunWaves()
end


SendReinforcementsSmugglers = function()
	Trigger.AfterDelay(DateTime.Seconds(10), function()
		Media.PlaySpeechNotification(player, "Reinforce")
		Reinforcements.Reinforce(player, SmugglersReinforcements, SmugglersPath)
	end)
end 


SendReinforcementsFremen = function(units)
	inf = Reinforcements.Reinforce(fremen, Utils.Random(units), Utils.Random(FremenPathToGatheringPoint))

	Trigger.AfterDelay(DateTime.Seconds(10), function()
		Utils.Do(inf, function(unit)
			unit.AttackMove(FremenAttack.Location)
			IdleHunt(unit)
		end)
	end)
end

SendReinforcementsFremenFinal = function(units)
	Media.PlaySpeechNotification(player, "EnemyUnitsApproaching")
	inf = Reinforcements.Reinforce(fremen, Utils.Random(units), FremenPathToGatheringPoint[1])

	Trigger.AfterDelay(DateTime.Seconds(15), function()
		Utils.Do(inf, function(unit)
			unit.AttackMove(FremenAttack.Location)
			IdleHunt(unit)
		end)
	end)
end



RunWaves = function()
	local wavetype = FremenWaves[Difficulty][CurrentWave]
	local units = FremenReinforcements[wavetype][Difficulty]

	-- FremenAttackDelay = FremenAttackDelay - (#units * 3 - 3 - WavesLeft) * DateTime.Seconds(1)
	local delay = 0
	if CurrentWave == 1 then 
		delay = DateTime.Seconds(30)
	else
		delay = FremenAttackDelay[wavetype]
	end 
	delay = Utils.RandomInteger(delay - DateTime.Seconds(2), delay)


	if wavetype == "final" then
		Media.DisplayMessage("Hold your defences, commander. A wave with a trike vehicle is approaching", SmugglerSpeaker)
	end

	Trigger.AfterDelay(delay, function()
		SendReinforcementsFremen(units)
		if CurrentWave == SmugglerReinforcementsOnWave[Difficulty] then
			SendReinforcementsSmugglers()
		end

		CurrentWave = CurrentWave + 1
		if wavetype == "final" then
			Media.DisplayMessage("The fremen trike has arrived", SmugglerSpeaker)
			Trigger.AfterDelay(DateTime.Seconds(1), function() FremenArrived = true end)
		else
			RunWaves()
		end
	end)
end


