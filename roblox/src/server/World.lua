-- COOKIE OVERDRIVE — monde partagé
-- Comme sur le site : pas de personnage, pas d'arène. Le décor est construit côté client.
-- Le serveur publie seulement le classement mondial (lu par l'onglet Succès).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local World = {}
local boardValue

function World.init()
	Players.CharacterAutoLoads = false
	boardValue = Instance.new("StringValue")
	boardValue.Name = "Leaderboard"
	boardValue.Value = "[]"
	boardValue.Parent = ReplicatedStorage
end

function World.setLeaderboard(rows)
	if boardValue then boardValue.Value = HttpService:JSONEncode(rows) end
end

function World.onJoin(_player) end

return World
