# Astro Ball

Du er en komet. Foran dig ligger felter af mineraler, is og energi i et gammelt
asteroidebælte. Din bane er spærret.

Designdokumentet ligger i [CLAUDE.md](CLAUDE.md).

## Status

Punkt 1, 2, 3, 5 og 6 i byggerækkefølgen er bygget, og HUD'en fra punkt 7
er trukket frem: bold, paddle og containment-felt, alle ti klodstyper fra
Bæltet, level-loader med validering, level 1 til 3 spilbare fra start til
clear, og et brandet instrumentpanel i toppen med Unbounded og Space
Grotesk.

Ikke bygget endnu: lyd, touch-styring, level 4 til 12 og de power-ups,
som level 1 til 3 ikke kalder på.

### Afvigelser fra designdokumentet

Alle tre er bevidste og lette at rulle tilbage.

| Hvad | Dokumentet | Her | Hvorfor |
|---|---|---|---|
| HUD-højde og navn | 44 px, ASTRO BALL i Bone 13 px | 140 px, Pulse-lilla 28 px | Skærmen er dobbelt så høj som bred. Et højere panel skubber klodserne ned i rækkevidde i stedet for at efterlade en halv skærm dødt rum, og navnet bærer brandet. |
| Boldens grundfart | 320 px/s | 360, 360, 380 pr. level | Dokumentets forventede leveltider (45 til 70 sekunder for level 1) kan ikke nås på et 698 px højt felt ved 320 px/s. Farten står i hver levelfil og kan ændres uden at røre kode. |
| Langsom i level 1 til 3 | Level 1 og 2 havde den | Fjernet | En bremse er en straf, når banen er let. Langsom hører til, når det bliver svært. Ildkugle, Laser og Multi fylder pladsen. |

- **Motor:** Godot 4.7 (standard, ikke .NET)
- **Viewport:** 390 x 844 logisk, iPhone portræt, `canvas_items` med aspect `keep`
- **Styring:** musens x. Klik sender bolden afsted, og skyder med laser. Touch kommer i fase 4.
- **F1** debug-overlay · **F2** næste level · **F3** genstart level

### Rummet

Baggrunden er tre parallax-lag, alt tegnet proceduralt. Planeten er en
kugle og ikke en cirkel: terminatoren løber ned mod højre, fordi solen
står oppe til venstre, samme lysretning som klodsernes kernelys. Den
ligger halvt uden for feltets venstre kant, over paddlens bane og under
klodserne.

Paddlen er et stykke isenkram: afrundede hjørner, bevel foroven og
forneden, glansbånd, kolde metalsegmenter mod Bone-endestykker, og et
sweet spot med egen glød og et lys, der vandrer gennem feltet.

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
- Farten stiger 4 procent per 10 klodser og stopper ved 520 px/s

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
scripts/hud.gd            instrumentpanelet i toppen
levels/01_afgang.json     level 1, 47 klodser
levels/02_kapslen.json    level 2, 68 klodser plus 2 Sten
levels/03_kaeden.json     level 3, 53 klodser
assets/fonts/             Unbounded og Space Grotesk, begge under OFL
tests/                    regressionssuite, køres med tests/run.sh
```

### Test

```
./tests/run.sh
```

Tre suiter, alle headless:

| Suite | Hvad den dækker |
|---|---|
| `mechanics` | gridet, klodserne, level-validering, power-up-reglerne, boldens sweep |
| `lifecycle` | liv, game over, level-progression, fartstigning, score |
| `play` | autopilot spiller alle tre levels igennem og tjekker invarianter hver frame |

`tests/shots.tscn` er ikke en test, men et værktøj: det sætter spillet i
bestemte tilstande og gemmer PNG'er til `user://`, så det visuelle kan
efterses uden at spille efter øjeblikket.

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
