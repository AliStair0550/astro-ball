# Astro Ball

Du er en komet. Foran dig ligger felter af mineraler, is og energi i et gammelt
asteroidebælte. Din bane er spærret.

Designdokumentet ligger i [CLAUDE.md](CLAUDE.md).

## Status

Punkt 1 til 7 i byggerækkefølgen er bygget: bold, paddle og
containment-felt, alle ti klodstyper fra The Drift, level-loader med
validering, level 1 til 3 spilbare fra start til clear, HUD, baggrund
med alle reaktioner, lyd, skærme, stjerner og progression.

Ikke bygget endnu: touch-styring, level 4 til 12, konstellationskortet
og de power-ups, som level 1 til 3 ikke kalder på.

### Murens placering

Bundankeret fra afsnit 20 flyttede problemet i stedet for at løse det:
en mur på syv rækker fik 274 px himmel over sig og 300 px under, og
halvdelen af den tomme skærm lå, hvor der aldrig sker noget.

Reglen nu: en kort, fast himmel under en høj HUD, med murlinjen som
værn for dybe mure.

```
HUD             196 px, brugt aktivt
himmel          120 px fast mellem HUD og øverste klodsrække
murlinje        57 % nede i feltet, et værn en mur aldrig krydser
faldzone        344 til 380 px i de tre første levels
gridAnchor      valgfrit px-offset i leveldata, positivt = længere ned
```

Level-loaderen afviser et anker, der æder himlen eller fører muren
forbi murlinjen.

### Stjerner og progression

Afsnit 15 giver tre stjerner pr. level: gennemført, gennemført under
parTime, gennemført uden at miste bolden. De er uafhængige, så den
tredje kan tjenes uden den anden, og de lægges sammen på tværs af
forsøg i stedet for at blive erstattet. Gemmes i `user://progress.json`.

Den stille hjælper: tre fejl i træk på samme bane flytter 15
procentpoint fra de dårlige power-ups til de gode. Intet på skærmen,
intet i lyden. Nulstilles ved gennemførelse.

### Skærme

Spillet åbner på en titelskærm over det bare stjernefelt. Alt, spilleren
læser, er på engelsk, i den tørre telemetri-tone fra afsnit 14. Kode,
kommentarer og filnavne er også engelske. Kun designdokumentet er dansk.

| Skærm | Indhold |
|---|---|
| Titel | ASTRO BALL, PLAY, SETTINGS, rekord |
| Indstillinger | Sound, Music, Haptics, CRT Mode, Left-handed UI, Reset Progress |
| Level-intro | LEVEL n og banens navn, klik for at begynde |
| Field cleared | FIELD CLEARED og score |
| Signal lost | telemetri-opgørelse, RE-ENTRY og RESTART FIELD |

Afsnit 16 er fulgt til punkt og prikke: der findes ingen vej fra døden
til en hovedmenu. SIGNAL LOST er sort med stjernefeltet på 20 procent,
viser bricks cleared, best combo, time og score, og giver to veje videre.
RE-ENTRY koster ét liv og fortsætter præcis hvor spillet stod, én gang
pr. bane. RESTART FIELD bygger banen op igen med tre liv og nulstiller
banens score.

### Følelsen af at smadre en klods

Punkt 2 i byggerækkefølgen har sin egen scene, `scenes/feel_test.tscn`.
Kør den med F6.

| Tast | Tilstand |
|---|---|
| 1 | én Volt-klods, respawner 500 ms efter den ryger |
| 2 | en mur, 11 bred og 6 rækker |
| 3 | samme mur med bolden fastlåst på 520 px/s |
| R | nulstil tælleren |

Effektpakken pr. klods: hvidt glimt i ét frame, 5 til 8 splinter i tre
toner af klodsens egen farve der flyver væk fra kontaktpunktet, score-tal
der stiger 20 px, de nærmeste stjerner der blinker ved opacity 0.15,
16 ms hitstop og et 45 ms klik der stiger en halvtone pr. kombotrin.
Intet screen shake. Det er reserveret til sprængklodser.

### Lyd

Lydbanken er syntetiseret, ikke optaget. `tools/make_audio.py` genererer
alle 18 lyde uden afhængigheder, så en lyd kan justeres ved at ændre et
tal og køre scriptet igen.

Samplerne er tørre i sig selv. Rumklangen lægges på i en Godot-bus, så
alt sidder i det samme kammer, præcis som afsnit 12 beskriver. Under spil
er der ingen musik, kun en drone, der stiger en anelse med komboen.
Klods-klikket stiger i tonehøjde med komboen og nulstilles ved
paddle-ramt.

### Afvigelser fra designdokumentet

Alle tre er bevidste og lette at rulle tilbage.

| Hvad | Dokumentet | Her | Hvorfor |
|---|---|---|---|
| HUD-højde og navn | 44 px, ASTRO BALL i Bone 13 px | 140 px, Pulse-lilla 28 px | Skærmen er dobbelt så høj som bred. Et højere panel skubber klodserne ned i rækkevidde i stedet for at efterlade en halv skærm dødt rum, og navnet bærer brandet. |
| Boldens grundfart | 320 px/s | 360, 360, 380 pr. level | Dokumentets forventede leveltider (45 til 70 sekunder for level 1) kan ikke nås på et 698 px højt felt ved 320 px/s. Farten står i hver levelfil og kan ændres uden at røre kode. |
| Langsom i level 1 til 3 | Level 1 og 2 havde den | Fjernet | En bremse er en straf, når banen er let. Langsom hører til, når det bliver svært. Ildkugle, Laser og Multi fylder pladsen. |
| Den fjerne planet | Lag 2 havde en planet i nederste hjørne | Fjernet | Den lå, hvor paddlen arbejder, og læste som en cirkel frem for en verden. Baggrunden holder sig til stjerner, støv og et fjernt lysvask, der skifter farve fra bane til bane. |
| Murens højde | Gridet lå hvor det så bedst ud | Bundanker fra afsnit 20 | Samme faldzone i hvert level, uanset rækkeantal. Muren rykkede 172 px ned i level 1. |
| Lydens form | Syntetiseret i kode ved opstart | Syntetiseret af `tools/make_audio.py` og lagt i repoet | Samme idé, ingen uigennemsigtige aktiver: hver WAV kan regenereres fra scriptet. Forskellen er, at spillet ikke bruger et sekund på at regne bølgeformer ud, hver gang det starter på en telefon. |
| Klodsen som node | `scenes/brick.tscn` pr. klods | `brick.gd` er data, gridet tegner dem alle i ét `_draw` | 140 klodser bliver ikke til 140 noder. Anatomi, skadestadier og kollision er uændrede. |

- **Motor:** Godot 4.7 (standard, ikke .NET)
- **Viewport:** 390 x 844 logisk, iPhone portræt, `canvas_items` med aspect `keep`
- **Styring:** touch med relativt træk, mus på skrivebordet. Et tryk under 150 ms og 8 px affyrer bolden og skyder med laser. Et træk gør aldrig nogen af delene.
- **iPhone:** portræt, sikre områder, ProMotion, haptik. Se [docs/ios-build.md](docs/ios-build.md).
- **F1** debug-overlay · **F2** næste level · **F3** genstart level · **ESC** menu

### Rummet

Baggrunden er tre parallax-lag, alt tegnet proceduralt, og den bliver ved
med at være rum: stjerner, støv og et par asteroide-silhuetter. Ingen
genstande, der stjæler opmærksomhed fra klodserne. Hvert level i zonen
får sin egen anelse af temperatur gennem stjernefarven og et fjernt
lysvask nede fra venstre.

Paddlen er et stykke isenkram: afrundede hjørner, en cylinderskygge der
går fra lyst i toppen til mørkt i bunden, en glansstribe højt oppe, kolde
metalsegmenter mod Bone-endestykker, og et sweet spot med egen glød og et
lys, der vandrer gennem feltet.

CRT-tilstanden fra afsnit 12 er en shader over hele billedet: scanlines,
vignette og 1 px farvefranger. Slukket som standard, som dokumentet
foreskriver.

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
scripts/level_state.gd    liv, score, kombo, ure og stjerner
scripts/progress.gd       stjerner, rekord og fejltæller, gemt i user://
scripts/strings.gd        alt spillervendt tekst, afsnit 14
scripts/continue_gate.gd  prisen paa en RE-ENTRY, sømmen en reklame kobles paa
scripts/touch_input.gd    relativt traek, tap mod traek, multitouch
scripts/safe_area.gd      hakket og hjemmeindikatoren i logiske pixels
docs/ios-build.md         fra Godot til din iPhone, trin for trin
scripts/screens.gd        titel, indstillinger, intro, clear, game over
scripts/settings.gd       indstillinger der overlever et genstart
scripts/audio.gd          buser med rumklang, stemmer, drone
scripts/crt.gd            CRT-tilstanden
levels/level_01.json      Liftoff, 47 klodser
levels/level_02.json      The Capsule, 68 klodser plus 2 Sten
levels/level_03.json      The Chain, 53 klodser
assets/fonts/             Unbounded og Space Grotesk, begge under OFL
assets/audio/             18 syntetiserede lyde
assets/shaders/crt.gdshader
tools/make_audio.py       genererer lydbanken
tools/validate_levels.gd  validerer alle levels headless, exit-kode
tests/                    regressionssuite, køres med tests/run.sh
```

### Test

```
./tests/run.sh
```

Tre suiter, alle headless:

| Suite | Hvad den dækker |
|---|---|
| `validate_levels` | alle levelfiler mod afsnit 11 og 20, med exit-kode |
| `mechanics` | gridet, klodserne, level-validering, power-up-reglerne, boldens sweep |
| `brick_feel` | refleksion på alle fire flader og hjørner ved 320 og 520 px/s **og ved begge boldstørrelser**, 20 000 gennemløb uden tunnelering, splinterantal, oprydning inden 400 ms, pitch-loft |
| `phase4` | tap mod traek, accelerationskurven, relativ styring og dens clamping, sikre omraader, haptik-flaget |
| `phase3` | strengfilen, loaderens afvisninger, gridAnchor, level-tilstand, stjerner, persistens, den stille hjælper, power-up-ure, Giant |
| `lifecycle` | liv, SIGNAL LOST, RE-ENTRY, level-progression, fartstigning, score, indstillinger |
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
