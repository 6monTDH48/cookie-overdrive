# Cookie Overdrive — version Roblox 🍪

Portage complet du jeu en Luau : économie serveur, cookie géant 3D, 15 bâtiments,
37 améliorations (chacune ajoute un effet visuel sur le cookie), cookies dorés, combo et
Fièvre RGB, boss, pets et œufs, skins, thèmes, quêtes, succès, rebirth, cadeau gratuit,
gains hors-ligne, classement mondial et les 4 mini-jeux (Ninja, Flappy, Rythme, Casino).

## Publier en 5 minutes

1. Installe **Roblox Studio** (https://create.roblox.com) et connecte-toi.
2. Ouvre `CookieOverdrive.rbxlx` (double-clic, ou Fichier → Ouvrir dans Studio).
3. Clique sur **Play** pour tester.
4. Fais **Fichier → Publier sur Roblox**, donne un nom (ex. « Cookie Overdrive 🍪 RGB Simulator »),
   ajoute une icône et une description, puis valide.
5. Dans **Paramètres du jeu → Sécurité**, coche **Enable Studio Access to API Services** pour que
   les sauvegardes fonctionnent aussi en test. Ensuite, passe le jeu en **Public** dans le Creator Hub.

## 💰 Gagner des Robux

Le jeu contient déjà toute la logique d'achat. Il te reste à créer les produits et à coller leurs IDs :

1. Va sur https://create.roblox.com → ton expérience → **Monétisation**.
2. Crée les **Passes** (achat unique) :

   | Clé | Nom | Prix conseillé |
   |---|---|---|
   | DoubleCookies | Cookies ×2 | 199 R$ |
   | AutoClicker | Auto-Clicker | 149 R$ |
   | VIP | VIP (+2 pets, gemmes ×1,5, skin, tag) | 299 R$ |
   | LuckyEggs | Œufs Chanceux | 249 R$ |
   | GoldenMagnet | Aimant Doré | 129 R$ |
   | SkinPack | Pack Skins Exclusifs | 99 R$ |

3. Crée les **Developer Products** (rachetables) :

   | Clé | Nom | Prix conseillé |
   |---|---|---|
   | Gems100 / Gems550 / Gems1500 | Packs de gemmes | 49 / 199 / 449 R$ |
   | Cookies1h / Cookies12h | Production instantanée | 39 / 149 R$ |
   | Boost3x | Boost ×3 pendant 15 min | 79 R$ |
   | Fever | Fièvre RGB instantanée | 25 R$ |

4. Copie chaque ID dans `ReplicatedStorage > Shared > Monetization` (ou `src/shared/Monetization.lua`),
   à la place des `id = 0`. Les prix affichés en jeu se modifient au même endroit.
5. Republie. Tant qu'un ID vaut 0, le bouton affiche « Bientôt ».

Autres revenus automatiques : active les **paiements Premium** (Premium Payouts) : Roblox te paie
selon le temps passé dans ton jeu par les abonnés Premium, sans rien coder.

Le serveur valide chaque achat (`ProcessReceipt`), sauvegarde avant de confirmer et ne crédite jamais
deux fois le même reçu. Les probabilités des œufs sont affichées en jeu, comme Roblox l'exige
pour les objets aléatoires achetables. Le casino se joue uniquement avec des cookies du jeu.

## Structure (projet Rojo)

```
default.project.json         arbre Rojo
src/shared/GameData.lua      toutes les données (bâtiments, améliorations, pets…)
src/shared/Econ.lua          formules d'économie partagées
src/shared/Monetization.lua  Game Passes & Developer Products  ← IDs à remplir
src/server/Main.server.lua   serveur : état, sauvegarde DataStore, achats, boss, anti-triche
src/server/World.lua         arène néon + classement mondial
src/client/Main.client.lua   lien réseau, clic sur le cookie 3D
src/client/CookieModel.lua   cookie géant 3D + effets des améliorations + pets
src/client/UI.lua            HUD, onglets, boutique
src/client/Minigames.lua     les 4 mini-jeux
```

Après une modification du code : `rojo build default.project.json -o CookieOverdrive.rbxlx`,
ou `rojo serve` avec le plugin Rojo pour synchroniser Studio en direct.
