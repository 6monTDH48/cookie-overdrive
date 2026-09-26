--[==[
============================================================================================
  COOKIE OVERDRIVE : ENVOYER LES IMAGES SUR ROBLOX (une seule fois, environ 5 minutes)
============================================================================================

  Pourquoi ?
    Le jeu contient toutes ses images (cookies, icônes, fonds...) sous forme de code, dans
    ReplicatedStorage > Shared > ImageData. Le jeu les « dessine » au lancement : ça marche,
    mais c'est plus lourd. Ce script envoie chaque image sur ton compte Roblox, une par une,
    puis note leurs numéros (ids) dans ReplicatedStorage > Shared > AssetIds. Ensuite le jeu
    utilise directement les images Roblox : plus rapide et plus fiable pour les joueurs.

  Comment faire :
    1. Ouvre CookieOverdrive.rbxlx dans Roblox Studio et vérifie que tu es connecté(e).
       Conseil : publie le jeu une première fois (Fichier > Publier sur Roblox) pour que
       les images appartiennent au même propriétaire que le jeu (ton compte ou ton groupe).
    2. Menu Affichage (View) > clique sur « Barre de commande » (Command Bar).
       Une barre de saisie apparaît en bas de l'écran.
    3. Ouvre ce fichier (UploadImages.lua) avec le Bloc-notes, fais Ctrl+A puis Ctrl+C
       pour tout copier.
    4. Clique dans la barre de commande, colle (Ctrl+V) puis appuie sur Entrée.
    5. Ouvre la fenêtre Sortie (Affichage > Sortie / Output) : tu vois l'envoi image par
       image, puis un résumé. Ne ferme pas Studio pendant l'envoi.
    6. À la fin : Fichier > Publier sur Roblox (sinon les numéros ne sont pas enregistrés).

  Bon à savoir :
    - Tu peux relancer le script sans risque : les images déjà envoyées sont sautées.
      Si certaines ont échoué (limite d'envoi de Roblox), attends quelques minutes et relance.
    - Les nouvelles images passent par la modération de Roblox : elles peuvent rester
      invisibles quelques minutes. C'est normal.
    - À la fin, le contenu de AssetIds est aussi affiché dans la Sortie : si un développeur
      travaille sur le projet, envoie-lui ce texte (fichier roblox/src/shared/AssetIds.lua).
    - Si tu n'envoies PAS les images, le jeu les dessine lui-même avec « EditableImage ».
      Dans ce cas active, dans Accueil > Paramètres du jeu > Sécurité, l'option qui autorise
      les API de maillage / d'image (« Allow Mesh / Image APIs », le nom peut varier), sinon
      les images n'apparaîtront pas en ligne.
    - Option VIDER_IMAGEDATA (juste en dessous) : mets true pour alléger le jeu une fois que
      TOUT est envoyé (les images intégrées sont alors remplacées par leur seule taille).

  (Pour les développeurs : script à exécuter avec la sécurité « plugin » de la barre de
  commande. Il n'utilise aucun commentaire de ligne pour rester valide même si les retours
  à la ligne sont perdus au collage.)
============================================================================================
]==]

local VIDER_IMAGEDATA = false

local function main()
	local RS = game:GetService("ReplicatedStorage")
	local AssetService = game:GetService("AssetService")
	local Shared = RS:FindFirstChild("Shared")
	local ImageData = Shared and Shared:FindFirstChild("ImageData")
	local IndexModule = ImageData and ImageData:FindFirstChild("_index")
	local IdsModule = Shared and Shared:FindFirstChild("AssetIds")
	local InflateModule = Shared and Shared:FindFirstChild("Inflate")
	if not (ImageData and IndexModule and IdsModule and InflateModule) then
		warn("[Images] ReplicatedStorage > Shared > ImageData / _index / AssetIds / Inflate introuvable. As-tu ouvert le bon fichier CookieOverdrive.rbxlx ?")
		return
	end
	local Inflate = require(InflateModule)

	local function setSource(ms, text)
		pcall(function()
			local editorService: any = game:GetService("ScriptEditorService")
			editorService:UpdateSourceAsync(ms, function()
				return text
			end)
		end)
		if ms.Source ~= text then
			ms.Source = text
		end
	end

	local index = {}
	local keys = {}
	for key, name in string.gmatch(IndexModule.Source, '%[%s*"(.-)"%s*%]%s*=%s*"(.-)"') do
		index[key] = name
		table.insert(keys, key)
	end
	table.sort(keys)
	local ids = {}
	for key, id in string.gmatch(IdsModule.Source, '%[%s*"(.-)"%s*%]%s*=%s*(%d+)') do
		ids[key] = tonumber(id)
	end
	if #keys == 0 then
		warn("[Images] ImageData._index est vide : rien à envoyer.")
		return
	end

	local function idsSource()
		local all = {}
		for _, key in keys do
			all[key] = ids[key] or 0
		end
		for key, id in ids do
			if id ~= 0 then
				all[key] = id
			end
		end
		local sorted = {}
		for key in all do
			table.insert(sorted, key)
		end
		table.sort(sorted)
		local lines = {
			"-- AssetIds : ids des images envoyées sur Roblox (clé -> id). 0 = pas encore envoyée : l'image",
			"-- est alors décodée depuis ReplicatedStorage.Shared.ImageData au lancement (EditableImage).",
			"-- Rempli automatiquement par roblox/tools/UploadImages.lua (à coller dans la barre de commande",
			"-- de Roblox Studio). pack_assets.py régénère la liste des clés et garde les ids non nuls.",
			"return {",
		}
		for _, key in sorted do
			table.insert(lines, string.format('\t["%s"] = %d,', key, all[key]))
		end
		table.insert(lines, "}")
		return table.concat(lines, "\n") .. "\n"
	end

	local function readModule(key)
		local ms = ImageData:FindFirstChild(index[key])
		if not ms then
			return nil, "module " .. tostring(index[key]) .. " introuvable"
		end
		local src = ms.Source
		local k, w, h, z = string.match(src, 'key = "(.-)", w = (%d+), h = (%d+), z = "([%w%+/=]*)"')
		if not k then
			local ok, m = pcall(require, ms)
			if ok and type(m) == "table" then
				k, w, h, z = m.key, m.w, m.h, m.z
			end
		end
		if not k or not z or z == "" then
			return nil, "données d'image absentes"
		end
		return { ms = ms, w = tonumber(w), h = tonumber(h), z = z }
	end

	local params = { Name = "", Description = "" }
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		params.CreatorType = Enum.AssetCreatorType.Group
		params.CreatorId = game.CreatorId
		print("[Images] Le jeu appartient à un groupe : les images seront envoyées dans le groupe " .. game.CreatorId)
	end

	local todo = 0
	for _, key in keys do
		if (ids[key] or 0) == 0 then
			todo += 1
		end
	end
	print(string.format("[Images] %d images au total, %d déjà envoyées, %d à envoyer.", #keys, #keys - todo, todo))

	local done, failed, n = 0, {}, 0
	local stopAll = false
	for _, key in keys do
		if stopAll then
			break
		end
		if (ids[key] or 0) == 0 then
			n += 1
			local label = string.format("[Images] [%d/%d] %s", n, todo, key)
			local m, err = readModule(key)
			local editable = nil
			if m then
				local ok, res = pcall(function()
					local rgba = Inflate.base64Zlib(m.z, { size = m.w * m.h * 4 })
					local e = AssetService:CreateEditableImage({ Size = Vector2.new(m.w, m.h) })
					e:WritePixelsBuffer(Vector2.zero, Vector2.new(m.w, m.h), rgba)
					return e
				end)
				if ok and res then
					editable = res
				else
					err = "création de l'image impossible : " .. tostring(res)
				end
			end
			if editable then
				local assetId, lastErr = nil, nil
				for attempt = 1, 4 do
					params.Name = "CookieOverdrive " .. index[key]
					params.Description = "Cookie Overdrive : " .. key
					local ok, result, id = pcall(function()
						return AssetService:CreateAssetAsync(editable, Enum.AssetType.Image, params)
					end)
					if ok and result == Enum.CreateAssetResult.Success and tonumber(id) and tonumber(id) > 0 then
						assetId = tonumber(id)
						break
					end
					lastErr = tostring(result)
					if ok and result == Enum.CreateAssetResult.PermissionDenied then
						stopAll = true
						break
					end
					if attempt < 4 then
						local waitS = ({ 3, 15, 45 })[attempt]
						print(string.format("%s : échec (%s), nouvel essai dans %d s...", label, lastErr, waitS))
						task.wait(waitS)
					end
				end
				pcall(function()
					editable:Destroy()
				end)
				if assetId then
					ids[key] = assetId
					done += 1
					setSource(IdsModule, idsSource())
					print(string.format("%s -> rbxassetid://%d  OK", label, assetId))
				else
					err = "envoi refusé : " .. tostring(lastErr)
				end
			end
			if (ids[key] or 0) == 0 then
				table.insert(failed, key)
				warn(string.format("%s : ÉCHEC (%s)", label, tostring(err)))
			end
			task.wait(0.2)
		end
	end

	setSource(IdsModule, idsSource())
	print("[Images] ------------------------------------------------------------")
	print(string.format("[Images] Terminé : %d envoyées maintenant, %d déjà envoyées avant, %d en échec.", done, #keys - todo, #failed))
	if stopAll then
		warn("[Images] Roblox a refusé l'envoi (PermissionDenied). Vérifie que tu es connecté(e) dans Studio et que tu as le droit de créer des objets pour ce jeu / ce groupe, puis relance.")
	end
	if #failed > 0 then
		warn("[Images] Images en échec : " .. table.concat(failed, ", "))
		warn("[Images] Attends quelques minutes puis relance le script : seules les images manquantes seront envoyées.")
	end

	if VIDER_IMAGEDATA then
		if #failed == 0 and not stopAll then
			local emptied = 0
			for _, key in keys do
				local ms = ImageData:FindFirstChild(index[key])
				local m = ms and readModule(key)
				if m and (ids[key] or 0) ~= 0 then
					setSource(ms, string.format('return { key = "%s", w = %d, h = %d, z = "" }\n', key, m.w, m.h))
					emptied += 1
				end
			end
			print(string.format("[Images] VIDER_IMAGEDATA : %d images intégrées remplacées par leur taille (jeu allégé).", emptied))
		else
			warn("[Images] VIDER_IMAGEDATA ignoré : toutes les images ne sont pas encore envoyées.")
		end
	end

	print("[Images] Contenu de ReplicatedStorage.Shared.AssetIds (à copier dans roblox/src/shared/AssetIds.lua si besoin) :")
	print(idsSource())
	print("[Images] N'oublie pas : Fichier > Publier sur Roblox pour enregistrer.")
end

local ok, err = pcall(main)
if not ok then
	warn("[Images] Erreur : " .. tostring(err))
end
