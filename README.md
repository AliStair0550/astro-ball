# Astro Ball

Du er en komet. Foran dig ligger felter af mineraler, is og energi i et gammelt
asteroidebælte. Din bane er spærret.

Designdokumentet ligger i [CLAUDE.md](CLAUDE.md).

## Status

Punkt 1, 2, 3, 5 og 6 i byggerækkefølgen er bygget: bold, paddle og
containment-felt, alle ti klodstyper fra Bæltet, level-loader med
validering, og level 1 til 3 spilbare fra start til clear.

Ikke bygget endnu: lyd, den rigtige typografi (Unbounded og Space
Grotesk), touch-styring, level 4 til 12 og de resterende power-ups.
HUD'en er provisorisk og tegnes med motorens egen skrift, indtil punkt 7.

- **Motor:** Godot 4.7 (standard, ikke .NET)
- **Viewport:** 390 x 844 logisk, iPhone portræt, `canvas_items` med aspect `keep`
- **Styring:** musens x. Klik sender bolden afsted, og skyder med laser. Touch kommer i fase 4.
- **F1** debug-overlay · **F2** næste level · **F3** genstart level

### Fysik

Bolden er en `CharacterBody2D` med egen kollision. Ingen `RigidBody`, ingen
`move_and_slide`. Hver fysik-tick sveeper en cirkel mod linjesegmenter
(rammens tre inderflader og paddlens tre yderflader), og refleksionen regnes
manuelt, så farten holdes konstant.

- Start 320 px/s, fast timestep på 60 Hz
- Paddle-refleksion: yderste kant 25 grader fra vandret, midte 80 grader,
  lineært imellem
- Sweet spot: de midterste 8 px giver 88 grader og 10 % fart, der aftager
  over 2 sekunder
- Aldrig under 20 grader fra vandret, heller ikke efter vægrefleksioner

### Klodser

Alle ti typer fra afsnit 3 er bygget med fuld anatomi: toplinje, base,
indre tekstur, kernelys og bundlinje, plus tre skadestadier.

| Tegn | Type | Slag | Adfærd |
|---|---|---|---|
| `V` | Volt | 1 | 15 % chance for power-up |
| `I` | Ice | 1 | 10 % chance, diagonal frost |
| `P` | Pulse | 1 | dobbelt point, pulserende kernelys |
| `F` | Flare | 1 | 20 % chance, gnist-tekstur |
| `H` | Hærdet | 3 | triple point, viser revner og manglende stykker |
| `S` | Sten | ∞ | reflekterer, tæller ikke mod clear |
| `E` | Sprængklods | 1 | tager de 8 naboer i spiral, 40 ms hver |
| `G` | Glas | 1 | bolden går igennem, 12 skår |
| `X` | Gnist | 1 | garanteret power-up, roterende hvid kant |
| `?` | Skjult | 1 | 5 % silhuet, viser sig når en nabo smadres |

### Struktur

```
project.godot
scenes/game.tscn          hovedscene
scripts/game.gd           dirigent: levels, score, liv, kombo, power-up-virkning
scripts/arena.gd          containment-feltet, ramme, emittere, Ember-linje
scripts/ball.gd           kometen, swept circle-kollision, komethaler
scripts/paddle.gd         deflektorskjoldet, bredder, sweet spots, laser
scripts/brick.gd          én klods: anatomi, skadestadier, signatur
scripts/brick_grid.gd     gridet, broad phase-kollision, kæder, level clear
scripts/level_loader.gd   JSON ind, validering efter afsnit 11
scripts/powerup.gd        kapslen, kataloget, ikonerne
scripts/powerup_manager.gd spawn-regler og aktive virkninger
scripts/effects.gd        splinter, score-tal, shockwaves, kombo
scripts/background.gd     stjernefelt, planet, asteroider, parallax, reaktioner
scripts/game_feel.gd      screen shake, hitstop, squash
scripts/hud.gd            provisorisk HUD
levels/01_afgang.json     level 1, 47 klodser
levels/02_kapslen.json    level 2, 68 klodser plus 2 Sten
levels/03_kaeden.json     level 3, 53 klodser
```

### Leveldata

Hvert level er en JSON-fil, der valideres ved indlæsning: præcis 13 tegn
pr. række, maks 12 rækker, ingen Sten i nederste række, mindst 20
smadrelige klodser, og power-up-procenter der summerer til 100. En fejl
her bliver til underlig opførsel midt i et spil, hvis den ikke fanges.

### Kør

```
godot --path . 
```

Eller åbn mappen i Godot 4.7 og tryk F5.
