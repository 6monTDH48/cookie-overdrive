# COOKIE OVERDRIVE — technical contract

Hyperactive, RGB-everything, Roblox-simulator-flavoured cookie clicker. All UI text is **French**
(casual Gen-Z tone: "W", "no cap", "aura", "ratio", emojis welcome). Single dark neon world (no light theme).
Zero external JS libraries. Everything ends up inlined into ONE html file by `build.sh`, so:

* every JS file is an IIFE: `(function(){ 'use strict'; ... })();` — no globals except `window.CO`.
* no `import`/`export`, no fetch of other files, no external assets. Emojis are fine (drawn with fillText).
* no `alert/confirm/prompt` (they are disabled in the final viewer).

## Files

```
src/index.html        shell markup + inline <style> (owner: lead)
src/css/base.css      tokens + shared components (.btn, .stroke-text, .rgb-border)  (lead)
src/js/data.js        ALL game data (buildings, upgrades→visual keys, skins, themes, pets…)  (lead)
src/js/core.js        engine: state, economy, events, audio, save  (lead)
src/js/stage.js       full-screen canvas renderer: background, cookie, all visual layers, FX  (agent A)
src/js/ui.js          DOM: HUD, tabs, shop, pets, options, minigame overlay host  (lead)
src/js/mg-ninja.js    minigame Cookie Ninja          (agent B)
src/js/mg-flappy.js   minigame Flappy Cookie         (agent B)
src/js/mg-rhythm.js   minigame Crunch Rythme         (agent C)
src/js/mg-slots.js    minigame Casino Crumble        (agent C)
src/dev/stub-core.js  fake core with the same public API, for harness pages
```

Load order in the final page: `data.js → core.js → stage.js → mg-*.js → ui.js → boot`.
While developing, harness pages load `data.js → dev/stub-core.js → <your file>`.

Dev server: `http://localhost:8765/` serves the workspace root, so a harness at
`src/dev/stage-harness.html` is at `http://localhost:8765/src/dev/stage-harness.html`.

## Look & feel tokens (css/base.css)

Colors: `--bg #0b0620`, `--panel rgba(22,11,52,.78)`, `--ink #fff6fe`, `--muted #b3a6dd`, `--stroke #1a0b33`
(dark outline), `--hot #ff2bd6`, `--cyan #1ff4ff`, `--lime #b6ff3b`, `--gold #ffc93c`, `--red #ff4d6d`,
`--violet #8a5cff`, `--green #2bdc6a`.  RGB: everything that cycles hue uses **`CO.hue(offset)`** so the whole
screen shifts in sync (a "wave" = different offsets).

Fonts (Google Fonts, already linked by index.html): display **'Lilita One'** (chunky, outlined white text with
dark stroke = Roblox vibe), body **'Fredoka'**, numbers/labels **'Chakra Petch'**. In canvas:
`ctx.font = '700 32px "Lilita One", "Arial Rounded MT Bold", sans-serif'`. For the Roblox outline in canvas:
`ctx.lineJoin='round'; ctx.lineWidth=size*0.18; ctx.strokeStyle='#1a0b33'; ctx.strokeText(..); ctx.fillText(..)`.

Shared DOM classes: `.btn` (chunky 3D) + color modifiers `.green .pink .gold .cyan .red .dark`, sizes `.big .small`;
`.stroke-text` (outlined display text). Minigame DOM (start/end screens) should use them.

## Global `CO` API (implemented by core.js; faked by dev/stub-core.js)

### Events
`CO.on(ev, fn) → unsubscribe`, `CO.off(ev, fn)`, `CO.emit(ev, payload)`

| event | payload |
|---|---|
| `click` | `{x, y, amount, crit, combo, mult}` — x,y = CSS px in viewport (cookie center if keyboard) |
| `golden:spawn` / `golden:expire` | `{g}` |
| `golden:click` | `{g, kind, label, color}` (`color` may be `'rgb'`) |
| `buy` | `{kind:'building'|'upgrade'|'skin'|'theme', id, n}` |
| `visuals` | `{vis, added:[keys]}` — CO.vis changed; `added` = keys that just appeared/levelled (play an "equip" pop animation) |
| `skin` / `theme` | `{id}` |
| `fever:start` / `fever:end` | `{}` |
| `buff:start` / `buff:end` | `{buff}` |
| `boss:spawn` / `boss:defeat` / `boss:escape` | `{boss}` |
| `boss:hit` | `{dmg, crit, boss}` |
| `pets` | `{}` equipped pets changed |
| `pet:hatch` | `{pet}` |
| `achievement` | `{a}` |
| `rebirth` | `{stars}` |
| `settings` | `{settings}` |
| `beat` | `{n}` every quarter note (music or virtual 120 bpm clock) |
| `minigame:open` / `minigame:close` | `{id}` (stage should drop to a cheap/paused render while open) |
| `layout` | `{}` the #play rect may have changed |

### Read-only live values
* `CO.state` — save data: `cookies, totalBaked, allTimeBaked, clicks, gems, rebirths, stars, buildings{id:n},
  upgrades{id:true}, skin, skinsOwned, theme, themesOwned, pets[{uid,id,lvl}], equipped[uid], mg{id:{best,plays}},
  stats{golden,crits,maxCombo,fevers,bossKills,eggs,quests}, flags, settings`.
* `CO.settings` (=== CO.state.settings): `sfx 0..1, music 0..1, musicOn, rgbSpeed 0..3 (1 default),
  particles 0|1|2 (low/med/ultra, default 2), shake bool, trail bool, reducedMotion bool,
  numFormat 'short'|'sci'|'long', showFps bool, uiHue 'rgb'|0..360, clickSound`.
* `CO.vis` — `{visualKey: level}` for every owned visual (keys in `CO.data.visuals`). Missing key = off.
* `CO.combo` — `{count, mult, heat}` heat 0..1 (1 ⇒ about to trigger fever).
* `CO.fever` — `{active, until}`.
* `CO.buffs` — `[{id,name,emoji,until,dur}]`.
* `CO.golden.list` — `[{id, x, y, born, life}]` x,y **normalised 0..1 inside the #play rect**.
* `CO.boss` — `null | {id,name,emoji,color,hp,maxHp,born,until}`.
* `CO.now()` seconds (performance clock). `CO.hue(offset=0)` → 0..360 synced RGB hue.
* `CO.bpm`, `CO.beatPhase()` → 0..1 inside current beat.
* `CO.skin()` / `CO.theme()` → current def from data. `CO.petDef(id)`. `CO.equippedPets()` → `[{uid,lvl,def}]`.
* `CO.cpsBase()`, `CO.cpsNow()`, `CO.clickValue()`, `CO.fmt(n)`.

### Actions
* `CO.clickCookie(x, y)` → `{amount, crit}`; emits `click` (and `boss:hit` when a boss is up).
* `CO.clickGolden(id)`.
* `CO.sfx.play(name, {pitch=1, vol=1})` — names: `click crit buy upgrade error golden achievement combo fever
  hatch coin whoosh hit slice miss perfect good jump spin reel win jackpot lose boss levelup tick pop`.
* `CO.audio()` → `{ctx: AudioContext, out: GainNode}` or `null` (out already carries the SFX volume).
* `CO.toast(text, {emoji, color})`.
* `CO.drawCookie(ctx, x, y, r, opts)` → proxies to `CO.stage.drawCookie` (see stage contract).

## Stage contract (`js/stage.js`, sets `CO.stage`)

```js
CO.stage = {
  init(canvas),           // called once by boot with <canvas id="stage">; starts its own rAF loop
  resize(),               // re-read viewport + #play rect
  drawCookie(ctx, x, y, r, opts),   // reusable cookie painter (used by minigames + UI thumbnails)
  isOverCookie(x, y),     // bool, CSS px
};
```

* `<canvas id="stage">` is `position:fixed; inset:0` full viewport behind the DOM UI. DPR = min(devicePixelRatio, 2)
  (1.5 when particles<2). The DOM `#play` element (transparent, `pointer-events:none`) marks the cookie zone:
  read `document.getElementById('play').getBoundingClientRect()` on resize, on `layout`, and every ~500 ms.
  Cookie center: `(rect.left + rect.width/2, rect.top + rect.height*0.56)`,
  radius `R = clamp(min(rect.width, rect.height*0.8) * 0.22, 60, 170)`.
  The top ~22% of #play holds the DOM counter; the bottom ~12% holds DOM text (ticker). Keep the cookie + accessories out of those bands when possible.
* Pointer input lives on the canvas: pointerdown on the cookie → `CO.clickCookie(e.clientX, e.clientY)` (every
  pointer, multi-touch ok); on a golden cookie → `CO.clickGolden(id)` (goldens win over the cookie). `cursor:pointer`
  while hovering either. Cookie reacts: squash & stretch, hover grow, idle breathing/wobble.
* Listens to events for FX: floating `+amount` numbers at the pointer (rainbow, crit = huge + "CRIT!" + shake),
  crumb particles, golden burst + big label text, boss hit flashes, fever start explosion, achievement sparkle, etc.
* Must honour `settings.particles` (budget), `settings.shake`, `settings.trail` (RGB pointer trail),
  `settings.reducedMotion` (no shake/flashes, slow motion, fewer particles), `settings.rgbSpeed` (via CO.hue),
  `settings.showFps` (draw fps small in a corner). Auto-degrade internally if fps < 40 for a few seconds.
* While a minigame is open (`minigame:open` … `minigame:close`) render at most a static frame / very low rate.

`drawCookie(ctx, x, y, r, opts)` — opts `{skin: id (default current), rot: rad, t: seconds (default CO.now()),
accessories: bool (default false) → also draw every **zone:'cookie'** visual from `opts.vis || CO.vis`,
squash: 0..1, look: {x,y} eye target in ctx space, simple: bool (cheap: cached sprite, no accessories)}`.
Always `save()/restore()`. Must be cheap enough for ~150 `simple` calls per frame (cache per-skin sprites).

## Minigame contract (`js/mg-*.js`)

```js
CO.registerMinigame({
  id: 'ninja',                 // one of ninja | flappy | rhythm | slots
  name: 'Cookie Ninja', emoji: '🥷', color: '#ff2bd6',
  tagline: 'Tranche les cookies, évite les brocolis.',   // ≤ 60 chars, shown on the card
  howto: 'Glisse pour trancher…',                         // 1–2 short sentences
  mount(root, api) { /* build DOM/canvas inside root */ return { destroy() { /* remove EVERYTHING */ } }; },
});
```

The UI opens a full-screen overlay (header bar with title + ✕ is provided by the UI), creates an empty
`root` (`position:relative; width/height fill the space; overflow:hidden`) and calls `mount(root, api)`.
Escape / ✕ closes the overlay and calls `destroy()` — which must cancel rAF, timers, window listeners,
audio nodes and remove what it added. Use pointer events (mouse + touch), `touch-action:none` on the
play surface, ResizeObserver on root, DPR-aware canvas. Must work from 360px-wide phones to desktop.

`api`:
```
api.unit()            → cookie reward unit ≈ 1 minute of production (≥ 25)
api.cookies()         → current bank
api.spend(n)          → bool (deducts if affordable)
api.grant({cookies, gems})          → immediate payout (no play counted) — e.g. each slot win
api.end({score, cookies, gems})     → finish a run: grants rewards, counts a play, records best score
                                      → returns {cookies, gems, best, isNewBest}. Call ONCE per run.
api.best()            → best score so far
api.fmt(n)            → formatted number string
api.sfx(name, opts)   → shared SFX (names above)
api.audio()           → {ctx, out} | null for custom synthesis (music for rhythm game)
api.drawCookie(ctx, x, y, r, opts)  → paints the PLAYER'S cookie (current skin; accessories:true adds their
                                      upgrades: sunglasses, crown, glaze…). Use it so games feel linked to the cookie.
api.skin()            → {id, name, style, pal:{base,dark,light,chip,chipHi,rim}}
api.vis()             → {visualKey: level}
api.hue(offset)       → synced RGB hue
api.settings()        → settings (respect reducedMotion, particles, shake)
api.toast(text, opts)
api.close()           → ask the UI to close the overlay
```

Flow inside every minigame: **start screen** (big title, how-to, best score, "JOUER" `.btn.big.green`) →
**countdown 3-2-1-GO** → play → **results screen** (score, "NOUVEAU RECORD !" if so, rewards returned by
`api.end`, buttons "REJOUER" and "QUITTER" → `api.close()`). Juice everything: screen shake, particles, pop-in
text, combo counters, RGB flashes — within `settings()` limits.
