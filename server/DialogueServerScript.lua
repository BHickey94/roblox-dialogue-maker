-- Roblox services
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

-- Get dialogue settings
local SETTINGS = require(script.Settings);

-- Make sure that we have a connection with the remote functions/events
local RemoteConnections = ReplicatedStorage:WaitForChild("DialogueMakerRemoteConnections", 3);
assert(RemoteConnections, "[Dialogue Maker] The DialogueMakerRemoteConnections folder couldn't be found in the ReplicatedStorage.");

local DialogueLocations = {};
local DialogueLocationsFolder = script.DialogueLocations;

-- Keep an array of dialogue variables
local DialogueVariables = {};

-- Add every dialogue that's in the folder to the dialogue array
for _, value in ipairs(DialogueLocationsFolder:GetChildren()) do
	if value.Value:FindFirstChild("DialogueContainer") then
		table.insert(DialogueLocations, value.Value);
	end;	
end;

RemoteConnections.GetNPCDialogue.OnServerInvoke = function(player)
	return DialogueLocations;
end;

RemoteConnections.GetDefaultTheme.OnServerInvoke = function(player)
	return SETTINGS.DEFAULT_THEME;
end;

RemoteConnections.GetAllThemes.OnServerInvoke = function(player)

	local ThemeFolder = script:FindFirstChild("Themes");
	if ThemeFolder then
		local Themes = {};

		for _, theme in ipairs(ThemeFolder:GetChildren()) do
			Themes[theme.Name] = theme:Clone();
		end;

		return Themes;
	end;

end;

RemoteConnections.PlayerPassesCondition.OnServerInvoke = function(player,npc,priority)

	-- Ensure security
	if not npc:IsA("Model") or not priority:IsA("Folder") then
		warn("[Dialogue Maker] "..player.Name.." failed a security check");
		error("[Dialogue Maker] Invalid parameters given to check if "..player.Name.." passes a condition");
	end;

	-- Search for condition
	local Condition;
	for _, condition in ipairs(script.Conditions:GetChildren()) do

		if condition.NPC.Value == npc and condition.Priority.Value == priority then
			Condition = condition;
			break;
		end;

	end;

	-- Check if there is no condition or the condition passed
	if not Condition or require(Condition)(player) then
		return true;
	else
		return false;
	end;

end;

local ActionCache = {};
RemoteConnections.ExecuteAction.OnServerInvoke = function(player, npc, priority, beforeOrAfter)

	-- Ensure security
	if not npc:IsA("Model") or not priority:IsA("Folder") or typeof(beforeOrAfter) ~= "string" then
		warn("[Dialogue Maker] "..player.Name.." failed a security check");
		error("[Dialogue Maker] Invalid parameters given to check if "..player.Name.." passes a condition");
	end;

	-- Search for action
	local Action;
	if ActionCache[npc] and ActionCache[npc][beforeOrAfter][priority] then
		Action = ActionCache[npc][beforeOrAfter][priority];
	elseif not ActionCache[npc] then
		ActionCache[npc] = {
			Before = {};
			After = {};
		};
	end;

	if not Action then
		local ActionScripts = script.Actions:FindFirstChild(beforeOrAfter):GetChildren();
		for _, action in ipairs(ActionScripts) do
			if action.NPC.Value == npc and action.Priority.Value == priority then
				Action = action;
				break;
			end;
		end;

		if not Action then
			return;
		end;

		-- Add the player to the action
		Action = require(Action);

		local Old = getfenv(Action.Execute);
		local MTable = setmetatable({
			Player = player
		},{
			__index = function(t,i)
				if Old[i] then
					return Old[i];
				end;
			end;
		});
		setfenv(Action.Variables, MTable);
		setfenv(Action.Execute, MTable);

		-- Check if there are any variables the user wants us to overwrite
		for variable, value in pairs(Action.Variables()) do

			if not DialogueVariables[player] then
				DialogueVariables[player] = {};
			end;

			if not DialogueVariables[player][npc] then
				DialogueVariables[player][npc] = {};
			end

			DialogueVariables[player][npc][variable] = value;

		end;


		ActionCache[npc][beforeOrAfter][priority] = Action;

		-- Check if the action is synchronous
		if Action.Synchronous then
			Action.Execute();
		else
			coroutine.wrap(Action.Execute)();
		end;

	end;

end;

RemoteConnections.GetVariable.OnServerInvoke = function(player,npc,variable)

	-- Ensure security
	if not npc:IsA("Model") or typeof(variable) ~= "string" then
		warn("[Dialogue Maker] "..player.Name.." failed a security check");
		error("[Dialogue Maker] Invalid parameters given to check if "..player.Name.." passes a condition");
	end;

	if not DialogueVariables[player] then
		DialogueVariables[player] = {};
	end;

	if not DialogueVariables[player][npc] then
		DialogueVariables[player][npc] = {
			PlayerName = player.Name;
		};
	end;

	-- Check the current variables
	if not DialogueVariables[player][npc][variable] then

		-- Check for default variables
		for _, variablesScript in ipairs(script.DefaultVariables:GetChildren()) do
			if variablesScript.NPC.Value == npc then
				local DefaultVariablesScript = require(variablesScript);
				for defaultVariable, value in pairs(DefaultVariablesScript) do
					DialogueVariables[player][npc][defaultVariable] = value;
				end;
				break;
			end;
		end;

	end;

	if DialogueVariables[player][npc][variable] then
		return DialogueVariables[player][npc][variable];
	end;

end;

RemoteConnections.GetMinimumDistanceFromCharacter.OnServerInvoke = function()
	return SETTINGS.MIN_DISTANCE_FROM_CHARACTER;
end;

RemoteConnections.GetKeybinds.OnServerInvoke = function()
	return {
		KEYBINDS_ENABLED = SETTINGS.KEYBINDS_ENABLED;
		DEFAULT_CHAT_TRIGGER_KEY = SETTINGS.DEFAULT_CHAT_TRIGGER_KEY;
		DEFAULT_CHAT_TRIGGER_KEY_GAMEPAD = SETTINGS.DEFAULT_CHAT_TRIGGER_KEY_GAMEPAD;
		DEFAULT_CHAT_CONTINUE_KEY = SETTINGS.DEFAULT_CHAT_CONTINUE_KEY;
		DEFAULT_CHAT_CONTINUE_KEY_GAMEPAD = SETTINGS.DEFAULT_CHAT_CONTINUE_KEY_GAMEPAD;
	}
end;

RemoteConnections.GetDefaultClickSound.OnServerInvoke = function()
	return SETTINGS.DEFAULT_CLICK_SOUND;
end;