# Cookie Overdrive

- **site/index.html** : le jeu complet (un seul fichier). Double-clique pour jouer, ou glisse le dossier `site` sur https://app.netlify.com/drop pour le mettre en ligne.
- **source/** : le code source (JS, CSS, HTML, illustrations vectorielles).
  - Rebâtir le jeu : `cd source && python3 build.py` → `dist/cookie-overdrive.html`
  - Tester en local : `cd source && python3 -m http.server 8765` puis http://localhost:8765/src/index.html
- Version publiée (Claude) : https://claude.ai/artifact/4agagBRftC4k6945GtAaTK
- Serveur Hetzner prévu : 95.217.189.145 → https://95-217-189-145.sslip.io (Caddy) — clé SSH pas encore installée.
