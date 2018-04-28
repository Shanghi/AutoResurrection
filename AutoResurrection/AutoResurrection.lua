AutoResurrectionSave = nil -- saved settings set up in ADDON_LOADED
local autoResurrectOnce = false -- always accept the next resurrection if true - not a saved setting

----------------------------------------------------------------------------------------------------
-- Decide if resurrecting is appropriate, and do so if it is
-- off = 0, always = 1, nocombat = 2
----------------------------------------------------------------------------------------------------
local function TryResurrection(soulstone)
	if not autoResurrectOnce then
		-- figure out where they are and get the setting for that location
		local setting
		if UnitInBattleground("player") then
			setting = AutoResurrectionSave.battleground
		elseif IsActiveBattlefieldArena() then
			setting = AutoResurrectionSave.arena
		elseif IsInInstance() then
			setting = AutoResurrectionSave.instance
		else
			setting = AutoResurrectionSave.world
		end
		if setting ~= 1 and setting ~= 2 then
			return
		end

		-- if needed, check if anyone in the group/raid is in combat first
		if setting == 2 then
			if UnitInRaid("player") then
				for i=1,40 do
					if UnitAffectingCombat("raid" .. i) or UnitAffectingCombat("raidpet" .. i) then
						return
					end
				end
			elseif UnitInParty("player") then
				for i=1,4 do
					if UnitAffectingCombat("party" .. i) or UnitAffectingCombat("partypet" .. i) then
						return
					end
				end
			end
		end
	end

	if soulstone then
		UseSoulstone()
	else
		AcceptResurrect()
	end
end

----------------------------------------------------------------------------------------------------
-- Handle events
----------------------------------------------------------------------------------------------------
local eventFrame = CreateFrame("frame")

local function AutoResurrection_OnEvent(self, event, addonName)
	if event == "PLAYER_DEAD" then
		TryResurrection(true) -- on death, try to use your own resurrection if possible
	elseif event == "RESURRECT_REQUEST" then
		TryResurrection(false)
	elseif event == "PLAYER_UNGHOST" then
		autoResurrectOnce = false
	elseif event == "PLAYER_ALIVE" then
		if not UnitIsGhost("player") then
			autoResurrectOnce = false
		end
		-- the popups won't automatically close when using AcceptResurrect(), so close them now
		StaticPopup_Hide("RESURRECT")
		StaticPopup_Hide("RESURRECT_NO_TIMER")
		StaticPopup_Hide("RESURRECT_NO_SICKNESS")
		StaticPopup_Hide("DEATH")
	elseif event == "ADDON_LOADED" and addonName == "AutoResurrection" then
		eventFrame:UnregisterEvent(event)
		if AutoResurrectionSave              == nil then AutoResurrectionSave              = {} end
		if AutoResurrectionSave.arena        == nil then AutoResurrectionSave.arena        = 0 end
		if AutoResurrectionSave.battleground == nil then AutoResurrectionSave.battleground = 0 end
		if AutoResurrectionSave.instance     == nil then AutoResurrectionSave.instance     = 0 end
		if AutoResurrectionSave.world        == nil then AutoResurrectionSave.world        = 0 end
	end
end

eventFrame:SetScript("OnEvent", AutoResurrection_OnEvent)
eventFrame:RegisterEvent("RESURRECT_REQUEST") -- to know when someone is resurrecting you
eventFrame:RegisterEvent("PLAYER_DEAD")       -- to know when to use a soulstone
eventFrame:RegisterEvent("PLAYER_ALIVE")      -- to be able to hide the resurrection window
eventFrame:RegisterEvent("PLAYER_UNGHOST")    -- to cancel auto-resurrecting once
eventFrame:RegisterEvent("ADDON_LOADED")      -- temporary - to set up variables

----------------------------------------------------------------------------------------------------
-- slash command
----------------------------------------------------------------------------------------------------
_G.SLASH_AUTORES1 = "/autoresurrect"
_G.SLASH_AUTORES2 = "/autores"
function SlashCmdList.AUTORES(input)
	input = input and input:lower() or ""

	local command, value = input:match("(%w+)%s*(.*)")
	command = command or input -- single command without a value

	local location -- text to describe the location set so that it fits in a sentence
	local setting  -- the setting for the location

	if command == "once" then
		autoResurrectOnce = not autoResurrectOnce
		DEFAULT_CHAT_FRAME:AddMessage("You have " .. (autoResurrectOnce and "enabled" or "canceled") .. " auto-resurrecting once.")
		return
	end

	-- get a setting first to make sure it's valid
	if value == "always" then
		setting = 1
	elseif value == "off" then
		setting = 0
	elseif value == "nocombat" then
		setting = 2
	end

	-- now find location to use the setting on if it was valid
	if setting then
		if command == "all" then
			location = "all locations"
			AutoResurrectionSave.arena = setting
			AutoResurrectionSave.battleground = setting
			AutoResurrectionSave.instance = setting
			AutoResurrectionSave.world = setting
		elseif command == "arena" then
			location = "the arena"
			AutoResurrectionSave.arena = setting
		elseif command == "battleground" then
			location = "battlegrounds"
			AutoResurrectionSave.battleground = setting
		elseif command == "instance" then
			location = "instances"
			AutoResurrectionSave.instance = setting
		elseif command == "world" then
			location = "the world"
			AutoResurrectionSave.world = setting
		end
	end

	if setting and location then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("Automatically resurrecting in %s has been %s.", location,
			(setting == 1 and "enabled always" or (setting == 2 and "enabled when no group/raid members are in combat" or "disabled"))
		))
	else
		-- bad or no command, so show the syntax and current settings
		local data = AutoResurrectionSave
		DEFAULT_CHAT_FRAME:AddMessage("AutoResurrection commands:", 1, 1, 0)
		DEFAULT_CHAT_FRAME:AddMessage("/autores once")
		DEFAULT_CHAT_FRAME:AddMessage("/autores all <setting>")
		DEFAULT_CHAT_FRAME:AddMessage("/autores arena <setting>")
		DEFAULT_CHAT_FRAME:AddMessage("/autores battleground <setting>")
		DEFAULT_CHAT_FRAME:AddMessage("/autores instance <setting>")
		DEFAULT_CHAT_FRAME:AddMessage("/autores world <setting>")
		DEFAULT_CHAT_FRAME:AddMessage("<setting> can be: always, nocombat, off")
		DEFAULT_CHAT_FRAME:AddMessage(" ")
		DEFAULT_CHAT_FRAME:AddMessage(string.format("Current: Arena:[%s] Battleground:[%s] Instance:[%s] World:[%s]",
			(data.arena == 1 and "always" or (data.arena == 2 and "nocombat" or "off")),
			(data.battleground == 1 and "always" or (data.battleground == 2 and "nocombat" or "off")),
			(data.instance == 1 and "always" or (data.instance == 2 and "nocombat" or "off")),
			(data.world == 1 and "always" or (data.world == 2 and "nocombat" or "off"))
		))
		if autoResurrectOnce then
			DEFAULT_CHAT_FRAME:AddMessage('You will accept the next resurrection. Use "/autores once" to cancel.', 0, 1, 0)
		end
	end
end
