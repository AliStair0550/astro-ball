# ASTRO BALL
## Designdokument v2. Rum-tema, visuelt system, spilmekanik og de første tre levels

Erstatter v1 (Splint). Mekanik, klodsanatomi, power-ups og levelgrids er uændrede. Verden, baggrunde, ramme og de visuelle øjeblikke er skrevet om til rummet.

---

## 0. Princippet

DX-Ball 2 var aldrig minimalistisk. Det var rigt. Klodser med kant og lys, baggrunde der levede, 30 power-ups med hver sin ikon, partikler overalt. Det er den følelse, vi skal ramme.

Reglen for Astro Ball: **Alt, der er synligt, har en funktion. Alt, der har en funktion, er synligt.**

Det giver os lov til at være maksimalistiske i udtrykket uden at blive rodede.

---

## 1. Verdenen

Du er en komet. Foran dig ligger felter af mineraler, is og energi, aflejret i et gammelt asteroidebælte. Din bane er spærret. Du bryder igennem, felt for felt, zone for zone, indad mod centrum af systemet.

Paddlen er dit fartøjs deflektorskjold, set nedefra. Spilfeltet er et containment-felt, fartøjet projicerer rundt om mineralfeltet, så intet undslipper, mens du arbejder. Det forklarer rammen, den åbne bund og hvorfor alt lyser, når det rammes.

Fiktionen fortælles aldrig med tekst. Den fortælles med baggrund, lyd og navne.

### Zoner

| Zone | Navn | Materiale i klodserne | Baggrund | Lydpalet | Levels |
|---|---|---|---|---|---|
| 1 | Bæltet | Malm og klippe med metalkerner | Stjernefelt, fjern planet, drivende asteroider | Tørre klik med mørk rumklang | 1 til 12 |
| 2 | Isringen | Is og krystal | Ringplan set indefra, lysbrydning | Klirren, høje toner | 13 til 24 |
| 3 | Solvinden | Glødende, forbrændt materiale | Korona, varmeflimmer, protuberansbuer | Dybe slag, sus | 25 til 36 |
| 4 | Tågen | Gas kondenseret til faste felter | Violet stjernetåge, dybde, skjulte former | Dæmpet, drone | 37 til 48 |
| 5 | Hullet | Sort materiale med lysårer | Accretionsskive, alt trækker mod midten | Subbas, stilhed | 49 til 60 |

Version 1 bygger Bæltet, 12 levels. De første tre er beskrevet i afsnit 9.

---

## 2. Lagene i billedet

Hver skærm består af seks lag. Alle seks er altid til stede. Det er summen, der giver rigdommen.

```
Lag 6  HUD            Score, liv, kombo, level. Sidder over alt.
Lag 5  Effekter       Partikler, shockwaves, lysglimt, score-tal.
Lag 4  Aktører        Bold, paddle, power-up-kapsler, lasere.
Lag 3  Klodser        Grid af klodser med materiale og skade.
Lag 2  Ramme          Containment-feltet. Lyser op ved kontakt.
Lag 1  Baggrund       Tre parallax-lag, langsom bevægelse, reagerer på spil.
```

### Lag 1: Baggrund (Bæltet)

Tre lag med forskellig parallax, når paddlen flytter sig. Forskydning 2 til 8 px, dybde uden at det bliver en effekt.

- Bagerst: Stjernefelt. 80 til 120 stjerner i tre størrelser (1, 2, 3 px) på #07070C. De mindste flimrer svagt og asynkront, aldrig mere end 2 ad gangen. Et stjerneskud krydser hjørnet af skærmen hvert 40. til 70. sekund. Ingen parallax.
- Midten: To til fire asteroide-silhuetter (#12121A) driver ekstremt langsomt, 1 px per 2 sekunder, og roterer umærkeligt. Parallax 3 px. (Rettet under bygning: den fjerne planet er fjernet, se afsnit 21.)
- Forrest: Fint støv og småsten, 6 til 10 mørke fragmenter (#1C1C26), der flytter 8 px med paddlen. Det er laget, der giver følelsen af at være i feltet, ikke foran det.

Reaktioner. Det er dem, der gør rummet levende:

- Hver klods, der smadres, får de nærmeste 5 til 8 stjerner til at blinke op i klodsens farve i 300 ms, opacity 0.15. Rummet svarer.
- Ved kombo 5+ stiger stjerneskuds-frekvensen til hvert 8. sekund. Ved kombo 10+ driver asteroiderne mærkbart hurtigere.
- Ved tab af liv dimmer stjernefeltet til 50 procent i 800 ms, og planeten mister sin atmosfærelinje et øjeblik.
- Ved level clear tændes alle stjerner 100 procent i ét frame, som en blitz.

### Lag 2: Rammen (containment-feltet)

Spilfeltet er 13 kolonner bredt. Rammen er 6 px, #232330, med en indre energilinje på 1 px i #3A3A50, der langsomt pulserer (4 sekunders cyklus, knapt synligt). Når bolden rammer, lyser et 40 px segment op i Volt i 120 ms med en lille bølge, der løber 20 px til hver side. Feltet er energi, ikke metal.

I hvert af de to øverste hjørner sidder en lille emitter, 8x8 px, der ser ud til at generere feltet. Ren dekoration med funktion: de blinker kort, hver gang feltet rammes, så spilleren ubevidst forstår, at rammen er projiceret.

Bunden er åben. Det er kanten af feltet, og under den er der frit fald. En tynd Ember-linje ligger der og blinker, når bolden er 100 px fra at passere. 150 ms til at redde den.

---

## 3. Klodser

Klodserne er 16 px høje og 24 px brede i logisk grid (skaleres til skærm). Afstand 2 px. Tætte, massive mure, som DX-Ball havde.

### Anatomi af en klods, version 2

Version 1 var flad: en lys toplinje, en mørk bundlinje, ellers ingenting.
Den holdt ikke på en telefon. Version 2 er en flise, som DX-Ball 2's var.

```
┌──────────────────┐  1. Base: materialefarven ved 86 % lum
│▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀│  2. Affasning: 2 px, lys top (145 %) og venstre (125 %),
│▌ ▁▁▁▁▁▁▁▁▁     ▐│     mørk højre (60 %) og bund (50 %), tegnet som
│▌               ▐│     geringede trapezer, så hjørnerne mødes som fliser
│▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄│  3. Glans: afrundet lysstribe øverst til venstre,
└──────────────────┘     55 % bredde, hvid ved 0.5, plus en svagere ved 0.25
```

4. Kernelys og indre tekstur er uændrede og ligger oven på basen.

Geringen er hele pointen: fire rektangler lagt oven på hinanden krydser i
hjørnerne og læses som en billedramme. Fire trapezer, der hver smalner
45 grader i begge ender, mødes langs diagonalen, og en mur af dem ser ud
som fliser.

Skadestadierne følger med: revnerne skærer nu gennem affasningen og ud
over kanten, og stadie 2 tager hjørnerne af, så geringen stopper før
kanten. Sten har ingen glans og en flad affasning (40 procent af løftet,
70 procent af skyggen), så den stadig ser død ud ved siden af elleve
klodser, der er oplyst. Sprængklodsen har fortsat sin mørke kerne med
Flare-glød indefra, nu liggende på v2-overfladen.

Kernelyset er nu fiktionens lys: den fjerne sol rammer feltet oppefra og til venstre. Samme lysretning i alle fem zoner. Det er den slags konsistens, ingen bemærker, men alle mærker.

### Skadestadier

| Stadie | Udseende |
|---|---|
| Fuld | Som beskrevet ovenfor |
| Ramt 1 gang | To revner fra kanten, 1 px, mørke. Kernelyset slukker. |
| Ramt 2 gange | Revner krydser midten. Tre små stykker mangler i kanten. Klodsen flimrer 1 gang per sekund. |
| Smadret | Splintrer i 5 til 8 stykker. Se afsnit 6. |

### Klodstyper i Bæltet

| Type | Farve | Slag | Adfærd | Visuel signatur |
|---|---|---|---|---|
| Volt | #D6FF3D | 1 | Standard. 15 % chance for power-up. | Energirig malm. Mest almindelige. |
| Ice | #4DD8FF | 1 | Standard. 10 % chance for power-up. | Svag diagonal frost-tekstur. |
| Pulse | #B57BFF | 1 | Standard. Giver dobbelt point. | Kernelyset pulserer langsomt. |
| Flare | #FF9F1C | 1 | Standard. 20 % chance for power-up. | Varm, lille gnist-tekstur. |
| Hærdet | #888780 | 3 | Viser skade. Giver triple point. | Mørk klippe med metalnitter i hjørnerne. |
| Sten | #F2EFE6 | Uknuselig | Reflekterer. Tæller ikke i level-clear. | Asteroidekerne. Mat, intet kernelys, ingen toplinje. Ser død ud. |
| Sprængklods | #FF4D2E | 1 | Eksploderer og smadrer de 8 naboer. Kædereaktion. | Ustabil malm. Mørk kerne, der gløder, når bolden er tæt på. |
| Glas | #4DD8FF ved 40 % | 1 | Bolden går igennem og fortsætter. Klodsen smadres alligevel. | Ren is. Halvgennemsigtig, man ser stjernerne igennem. Splintrer i 12 stykker. |
| Gnist | #D6FF3D med hvid kant | 1 | Garanteret power-up. | Hvid kant, der roterer rundt om klodsen. |
| Skjult | Usynlig | 1 | Viser sig, når en naboklods smadres. | Svag silhouet, 5 % opacity, flimrer hvert 4. sekund. |

Senere zoner tilføjer: Regenererende (Isringen), Kæde (Solvinden), Bevægelig (Tågen), Magnet (Hullet).

---

## 4. Bolden

Du er kometen. Diameter 8 px logisk. Hvid kerne (#F2EFE6) med 2 px Volt-kant.

Halen er komethalen og spillets vigtigste detalje. 6 positioner fra de sidste 6 frames, cirkler med faldende størrelse og opacity. Halen skifter efter tilstand:

| Tilstand | Kerne | Hale | Ekstra |
|---|---|---|---|
| Normal | Bone | Volt, 6 led | Ingen |
| Ildkugle | Ember | Ember til Flare, 10 led | Gnister drypper ned |
| Langsom | Bone | Ice, 4 led, tykkere | Svag frostring |
| Hurtig | Bone | Volt, 12 led, tynd | Streg i stedet for cirkler |
| Zap | Volt | Hvid, 3 led | Lille lyn ved hvert ramt |

Hastighed starter på 320 px/s og stiger 4 procent per 10 klodser, maks 520 px/s. Vinkel ud fra paddle: 25 grader i kanten til 80 grader i midten. Aldrig under 20 grader.

---

## 5. Paddlen

Deflektorskjoldet. Standard 88 px bred, 10 px høj. Tre synlige segmenter: to endestykker i Bone og et midterstykke med et 8 px Volt-felt. Midterfeltet er sweet spot: lige op og 10 procent ekstra fart.

Paddlen reagerer:
- Squash til 90 procent højde ved ramt, 80 ms, tilbage med lille overshoot.
- Endestykkerne lyser op i 100 ms, når bolden rammer dem.
- Ved hurtig bevægelse trækker den et svagt spor, 2 frames, og forreste støvlag i baggrunden følger med.

Tilstande:

| Tilstand | Bredde | Udseende |
|---|---|---|
| Normal | 88 | Tre segmenter |
| Bred | 132 | Fem segmenter, to sweet spots |
| Smal | 56 | Ét segment, ingen sweet spot |
| Laser | 88 | To Ember-rør på endestykkerne. Tap skyder. |
| Magnet | 88 | Ice-glød langs toppen. Bolden klæber. Tap slipper. |
| Skjold | 88 | En Volt-linje i bunden af feltet, ét slag. |

---

## 6. Effekter

Hvert event har en fast effektpakke. Ingen effekt varer over 400 ms.

| Event | Effekt |
|---|---|
| Bold rammer klods | Klodsen lyser hvid i 1 frame. 5 til 8 splinter i klodsens farve, flyver 40 til 90 px, roterer, falder med tyngde, forsvinder efter 350 ms. Score-tal popper op i Bone, flyver 20 px op, fader. Nærmeste stjerner blinker i klodsens farve. |
| Hærdet tager skade | 3 gnister, ingen splinter. Kort metallisk klik. Klodsen ryster 2 px. |
| Sprængklods | Hvid flash 2 frames over 3x3 felt. Shockwave-ring til 80 px. Screen shake 6 px, 120 ms. Naboer splintrer med 40 ms forsinkelse hver, så kæden ses. |
| Glas | 12 tynde skår, meget lette, svæver længere, som is i vakuum. Høj klirren. |
| Bold rammer paddle | Squash. 2 gnister op fra kontaktpunktet. Dybt klik. |
| Bold rammer ramme | Feltsegment lyser med sidebølge. Emitterne blinker. Tørt klik. |
| Power-up opsamlet | Kapslen imploderer til paddlen. Paddle blinker i kapslens farve. Ikon vises 600 ms over paddlen. |
| Kombo 5, 10, 20 | Tallet vises stort midt på skærmen i Unbounded, 100 ms skalering, fader. Stjerneskud oftere. |
| Mistet bold | Kometen splintrer i 20 stykker ved feltkanten og suges nedad. Ember-linjen blinker 3 gange. Stjernerne dimmer. Alt pauser 400 ms. |
| Level clear | Alle Sten-kerner eksploderer i rækkefølge. Rammen lyser hele vejen rundt, stjerneblitz, score tæller op. |

Partikler er altid firkantede eller rektangulære, aldrig runde. Samme sprog som klodserne.

---

## 7. Power-ups

Kapsler er 20x12 px, falder med 140 px/s. Afrundet rektangel i kapslens farve, hvidt roterende ikon, 6 px glød. Gode har lys kant. Dårlige har mørk kant og zigzag. Version 1 har 18.

### Gode (lys kant)

| Navn | Farve | Ikon | Effekt | Varighed |
|---|---|---|---|---|
| Bred | Volt | To pile ud | Paddle 132 px | 20 s |
| Multi | Pulse | Tre prikker | Bolden deler sig i 3 | Permanent |
| Ildkugle | Ember | Flamme | Bolden går igennem alt | 12 s |
| Laser | Ember | To streger op | Tap skyder 2 stråler | 15 s |
| Magnet | Ice | Magnet | Bolden klæber, tap slipper | 20 s |
| Langsom | Ice | Skildpadde-silhouet | Hastighed 70 % | 15 s |
| Skjold | Volt | Linje | Én gratis redning i bunden | Til brugt |
| Liv | Bone | Hjerte-silhouet | Plus ét liv | Permanent |
| Zap | Volt | Lyn | Smadrer klodser ved siden af den ramte | 10 s |
| Splint | Flare | Stjerne | Alle klodser med 1 slag tilbage smadres | Øjeblikkelig |

### Dårlige (mørk kant, zigzag)

| Navn | Farve | Ikon | Effekt | Varighed |
|---|---|---|---|---|
| Smal | Slate | To pile ind | Paddle 56 px | 20 s |
| Hurtig | Slate | To pile op | Hastighed 140 % | 15 s |
| Blind | Slate | Lukket øje | Klodser bliver usynlige, kun kanter | 10 s |
| Omvendt | Slate | Dobbeltpil | Styring spejles | 8 s |
| Tung | Slate | Anker | Paddle træg, 60 % følgehastighed | 12 s |
| Død | Ember, sort kant | Kranie-silhouet | Mister bolden | Øjeblikkelig |

### Neutrale (grå kant)

| Navn | Farve | Ikon | Effekt |
|---|---|---|---|
| Byt | Pulse | Roterende pile | Alle klodser skifter farve og type |
| Lotteri | Flare | Spørgsmålstegn | Tilfældig god eller dårlig |

Spawn-regler:
- Maks 2 kapsler på skærmen.
- Aldrig Død i de første 5 levels.
- Aldrig to dårlige i træk.
- Efter tab af liv er næste power-up garanteret god.

---

## 8. HUD

Øverst, 196 px høj. Grafit-panel med en Pulse-linje under. (Rettet under bygning fra 44 px, se afsnit 21.)

Venstre: ASTRO BALL i Unbounded 900, 28 px, Pulse-lilla med mørk forskydning. Under: UNIVERSE 1 · LEVEL 7 · LIFTOFF i Space Grotesk 9 px, Slate.
Højre: Score i Space Grotesk 700, 32 px, Volt, tabular, mellemrum som tusindtalsseparator. Under: tre små kometer for liv. Fulde er Bone, tabte er #444441.
Midt: Kombo-tal fra 3+. Unbounded, Volt, vokser med komboen.

Aktive power-ups i en dock med fire faste pladser nederst i panelet, hver med ikon, navn og tidsbjælke. Tomme pladser tegnes svagt.

---

## 9. De første tre levels

**Forældet. Griddene i dette afsnit er ikke dem, spillet bruger.** De
rigtige ligger i `levels/level_01.json` til `level_03.json`, og de er
gengivet herunder. Afsnittet er beholdt, fordi begrundelserne for hvorfor
hvert level virker stadig gælder. Det, der ændrede sig under bygningen:
sprængklodser kom ind fra level 1, Hærdet gik ud af alle tre og venter på
level 6, og level 3 blev tegnet om til en vinge, så silhuet-reglen i
afsnit 20 også gælder den. Se afsnit 21.

Formålet: lære spilleren alt i afsnit 3 til 7 uden en eneste tekstforklaring. Hvert level lærer én ting.

**Griddene herunder er de aktuelle**, hentet fra `levels/*.json` efter
mosaik-passet. Grid er 13 kolonner, maks 12 rækker. Symboler:

```
.  tom
V  Volt       I  Ice        P  Pulse      F  Flare
H  Hærdet     S  Sten       E  Sprængklods
              (H bruges først fra level 6, se afsnit 21)
G  Glas       X  Gnist      ?  Skjult
```

---

### De tolv vægge, som de er nu

Hentet fra `levels/*.json`. Begrundelserne for hvorfor de tre første
virker står under dem.

### Level 1: Liftoff

```
.............
......V......
.....VIV.....
.....VIV.....
....FVIVF....
....FVEVF....
...FFVEVFF...
...FF.E.FF...
......F......
```

### Level 2: The Capsule

```
.S.........S.
.IIIIIIIIIII.
.IVVVVVVVVVI.
.IV.......VI.
.IV.FFFFF.VI.
.IV.EEEEE.VI.
.IV.FFFFF.VI.
.IV.......VI.
.IVVVVVVVVVI.
.IIEEEEEEEII.
```

### Level 3: The Chain

```
.............
..FFF...FFF..
.FI.IF.FI.IF.
.F.GEEEEEG.F.
.FI.IF.FI.IF.
..FFF...FFF..
.GGGGGGGGGGG.
..VVIPPPIVV..
```

### Level 4: The Constellation

```
.............
.FF..........
..IFF........
...VIFF......
.....VIFF....
..VVVVVIFFVV.
..V?VEEEEV?V.
..VI?PPPP?IV.
..VVVVVVVVVV.
...I?VFFV?I..
```

### Level 5: The Hold

```
.............
....IIIII....
...IV...VI...
...IV...VI...
.FFFFFFFFFFF.
.FFVVEEEVVFF.
.FFVPPPPPVFF.
.FFVVXPXVVFF.
.FFFFFFFFFFF.
```

### Level 6: The Anvil

```
.............
..HHHHHHHHHH.
..HHHHHHHH...
.....HEEH....
.....H..H....
...FFFFFFF...
..FFIIVIIFF..
```

### Level 7: Off Axis

```
.............
......FFFFFF.
.....FFIIIIF.
....FIIPPIF..
...VIIPPIF...
..VVEEPPIF...
...VVEEPPIF..
....VVIIPPIF.
.....VVIIPPF.
......VVIIF..
```

### Level 8: The Labyrinth

```
.............
.FFFFFFFFFFF.
.F.........S.
.F.IIIIIII.F.
.F.I.....I.F.
.F.I.PPS.I.F.
.F.IEEEEEI.F.
.F.IIIIIII.F.
.F.........F.
.FFFFFFFFVVF.
```

### Level 9: The Fuse

```
.............
.EEEEEEEEEEE.
.EFIVPPPVIFE.
.EFIVPPPVIFE.
.EEEEEEEEEEE.
.............
..FIVVPVVIF..
..FIIIPIIIF..
..FFFFPFFFF..
```

### Level 10: The Pane

```
.GGGGGEGGGGG.
.GVVIGEGIVVG.
.GVIPGEGPIVG.
.GGGGGEGGGGG.
......E......
.GGGGGEGGGGG.
.GVIPGEGPIVG.
.GVVIGEGIVVG.
.GGGGGEGGGGG.
```

### Level 11: Blackout

```
.............
....VVVVV....
..VVIIIIIVV..
.VIIFFFFFIIV.
.VIFFEEEFFIV.
.VIIFFFFFIIV.
..VVIIIIIVV..
....VVVVV....
```

### Level 12: The Core

```
SVVVVVVVVVVVS
VHHVVVVVVVHHV
VVIIIIEIIIIVV
.VHIPPEPPIHV.
.VVIPFEFPIVV.
.VVIPEGEPIVV.
.VVIPFEFPIVV.
.VHIPPEPPIHV.
.VVIIIEIIIVV.
.VHHVVVVVHHV.
.VVVVVVVVVVV.
.X?X?X?X?X?X.
```

### Hvorfor de tre første virker

- **Liftoff.** Den omvendte trekant sender bolden op bag muren, og
  spidsen er en klynge på fem med to Gnister i: succes inden for fem
  sekunder, og ingen enlig klods at jage til sidst. Kæden i Ice-rækken
  tager 45 procent af feltet i ét slag.
- **The Capsule.** En kapsel i en kapsel: ydre skal, indre skal, kerne.
  Tre små sejre i én bane. De to Sten-kerner i hjørnerne kaster bolden
  ind mod midten i stedet for at fange den.
- **The Chain.** Sprængklodserne ligger på vingeknoglen, så ét slag løber
  ud gennem hele vingen. Glas-rækken føles som en fejl første gang og som
  vejen op bag vingespidserne anden gang.

---

## 10. Progression efter level 3

| Level | Nyt element | Kommentar |
|---|---|---|
| 4 | Skjulte klodser i mønster | En konstellation dukker op |
| 5 | Magnet og Laser som fokus | Gnist giver kun disse to |
| 6 | Første rene Hærdet-level | Tålmodighed |
| 7 | Asymmetrisk layout | Bryder forventningen om symmetri |
| 8 | Sten-labyrint | Bolden skal finde vej mellem asteroidekerner |
| 9 | Sprængkæde hele vejen rundt | Ét slag rydder 60 % |
| 10 | Glas-lag over alt | Bolden går igennem hele første lag |
| 11 | Blind som fast tilstand | Klodserne er usynlige fra start |
| 12 | Bæltets kerne | Alle typer, 140 klodser, zone-finale |

---

## 11. Leveldata

Hvert level er en JSON-fil. Claude Code kan generere og validere dem.

```json
{
  "id": 3,
  "name": "Kæden",
  "zone": "baeltet",
  "grid": [
    ".............",
    ".HHHHHHHHHHH.",
    ".H....E....H.",
    ".HHHHHHHHHHH.",
    ".............",
    ".GGEGG.GGEGG.",
    "..PPPPPPPPP..",
    "...E..E..E...",
    "....VVVVV....",
    "......?......"
  ],
  "ballSpeed": 320,
  "powerups": {
    "multi": 30, "fireball": 20, "zap": 15,
    "wide": 15, "fast": 10, "narrow": 10
  },
  "forcedFirstPowerup": null,
  "parTime": 80
}
```

Valgfrie felter ud over dem ovenfor:

```json
"sparkPowerups": ["magnet", "laser"],
"blind": true
```

`sparkPowerups` er Gnist-klodsens korte liste. Den garanterede power-up
trækkes kun herfra, så en bane kan lære spilleren præcis to ting (level
5). Uden feltet trækker Gnist fra banens almindelige tabel.

`blind` gør feltet blindt fra første frame (level 11). Det er ikke en
power-up, der løber ud: når Blind-kapslen udløber, er banen stadig blind,
fordi det er den bane.

Valideringsregler:
- Præcis 13 tegn pr. række.
- Maks 12 rækker.
- Ingen Sten i nederste række.
- Mindst 20 smadrelige klodser.
- Power-up-procenter summerer til 100.

---

## 12. Lyd og rumfølelse

- Lydbanken er syntetiseret af tools/make_audio.py og lagt i repoet som WAV. Alle lyde har en kort, mørk rumklang, lagt på af en bus ("Space", wet 0.15), som om feltet er et stort kammer. Det er den billigste vej til at føle sig inde i rummet i stedet for foran en skærm. DX-Balls lyde var tørre. Vores er i et rum.
- Under spil ingen musik, kun en dyb, næsten uhørlig drone, der stiger en anelse i intensitet med komboen.
- Klods-klik stiger i tonehøjde med komboen. Nulstilles ved paddle-ramt.
- Valgfri CRT-tilstand i indstillinger (scanlines, vignette, 1 px fringing), slået fra som standard. Nostalgi som tilvalg, moderne som standard.

---

## 13. Byggerækkefølge

1. Bold, paddle, ramme, kollision med korrekt vinkel. Ingen klodser. Skal føles rigtigt i hånden først.
2. Volt-klods med fuld anatomi og splinter-effekt. Én klods. Smadr den 200 gange, til det føles godt.
3. Level-loader, level 1 komplet med Gnist og Bred.
4. Touch-styring, test på iPhone.
5. Hærdet med skadestadier. Level 2.
6. Sprængklods, Glas, Skjult. Level 3.
7. HUD, baggrund med alle reaktioner, lyd.
8. Resten af power-ups.

Hvis punkt 1 og 2 ikke føles rigtige, er intet af det andet værd at bygge.


14. Sprog og tekster

Alt spilvendt tekst er engelsk. Kode, kommentarer og filnavne er engelsk. Designdokumentet forbliver dansk.

Tone i al spiltekst: kort, tør, teknisk, som telemetri fra et fartøj. Aldrig udråbstegn. "Ball lost", ikke "Oh no!". "Field cleared", ikke "Level complete!".

Officielle engelske navne:

Design (dansk)	I spillet
Bæltet	The Drift
Isringen	The Ice Rings
Solvinden	The Solar Wind
Tågen	The Nebula
Hullet	The Core
Afgang (level 1)	Liftoff
Kapslen (level 2)	The Capsule
Kæden (level 3)	The Chain
Zone (teknisk begreb)	Universe (i spillet)

Spillervendt omtales zonerne altid som universer: "Universe 1: The Drift". I kode, leveldata og designdokument hedder de fortsat zoner, og zone-slug'en i leveldata forbliver "baeltet". Navneændringer rører aldrig koden, kun strings-filen.

Alle strenge samles i én fil (strings-resource) fra fase 3, selv om der kun er engelsk. Ingen hardcodede tekster i scripts eller scener.

Score vises med mellemrum som tusindtalsseparator: 24 380.

15. Progression og retention

Stjerner pr. level. 1 til 3 stjerner: (1) gennemført, (2) gennemført under parTime, (3) gennemført uden at miste bolden. Stjernerne er uafhængige, man kan få nr. 3 uden nr. 2. Bedste resultat gemmes pr. level. Zone-adgang kan kræve et minimum af stjerner fra forrige zone.

Konstellationskortet. Level-select er et stjernekort, ikke en liste. Hvert level er en stjerne. Gennemførte levels tændes. Når en zone er fuldført, tegnes linjerne mellem stjernerne, og zonen bliver en konstellation. Bygges i fase 7.

Daily Orbit (efter lancering). Ét dagligt level genereret fra en dato-seed, ens for alle spillere, eget Game Center-leaderboard. Streak-tæller med kosmetiske belønninger. Aldrig straf for at misse en dag.

Gyldne splinter (efter lancering). Sjældent fald fra en smadret klods, skal fanges med paddlen. Samlingen vises på konstellationskortet. Ingen gameplay-effekt.

Sværhedsgrad. Én. Kurven ligger i leveldesignet (progressionstabellen i afsnit 10) og i boldens fartstigning. Ingen sværhedsvalg i menuen.

Den stille hjælper. Fejler spilleren samme level 3 gange i træk, hæves andelen af gode power-ups i det level med 15 procentpoint. Usynligt for spilleren, nulstilles ved gennemførelse. Altid slået fra i Daily Orbit, hvor alle skal have identiske vilkår. Bygges i fase 3 sammen med level-loaderen. Plan B, hvis lanceringsdata viser tidligt frafald pga. sværhed: en Drift-tilstand (langsommere bold, bredere paddle, ingen dårlige power-ups) som opdatering.

Multiplayer: bevidst udeladt i version 1.

16. Død og fortsættelse

Mistet bold, liv tilbage:

Effekt som afsnit 6: kometen splintrer, 400 ms frys, stjernerne dimmer.
Alle aktive power-ups slettes. Klodser og score står urørt.
Ny bold spawner klæbet til paddlen. Spilleren affyrer selv. Ingen nedtælling.
Næste power-up er garanteret god (regel fra afsnit 7).

Alle liv tabt: SIGNAL LOST-skærmen.

Sort baggrund, stjernefeltet dæmpet til 20 %.
Opgørelse i telemetri-stil: bricks cleared, best combo, time.
Ghost-linje med rekord: "Best: 24 380".
To valg:
RE-ENTRY: ét ekstra liv, fortsæt præcis hvor spillet stod. Gratis-version: mod rewarded-reklame. Betalt version: gratis, én gang pr. level.
RESTART FIELD: levelet forfra med 3 liv. Level-score nulstilles.
Stjerner, zone-progression og gyldne splinter mistes aldrig ved død.
Der findes ikke game over til hovedmenu, energi-systemer eller ventetid.
17. Indstillinger

Hele listen. Der tilføjes ikke flere uden beslutning:

Sound (til/fra)
Music (til/fra)
Haptics (til/fra)
CRT Mode (til/fra, fra som standard: scanlines, vignette, 1 px fringing)
Left-handed UI (spejler knapper på skærme, ikke gameplay)
Reset Progress (med bekræftelse)
18. Optage-tilstand

Skjult udvikler-feature, aldrig synlig for spillere. Aktiveres med en debug-genvej.

HUD kan slås fra.
Scenarier kan trigges direkte: fyldt mur, kædereaktion, multiball, level clear.
Formål: klip til TikTok/Reels/LinkedIn under hele udviklingen.
Bygges billigt oven på feel_test-scenen fra fase 2.
19. Monetisering (scope-beslutning)

Model: gratis download med hele The Drift (12 levels).

Interstitial-reklame kun mellem levels, efter hvert 3. level. Aldrig midt i spil.
Rewarded video: frivillig, giver ekstra liv (Re-entry) eller garanteret god power-up.
Én IAP: "Astro Ball Complete", 39 til 49 kr. Fjerner alle reklamer, åbner alle zoner, gør Re-entry gratis (1 pr. level).
Ingen møntøkonomi, ingen energi, ingen gameplay-køb. Eventuelle senere småkøb er udelukkende kosmetiske (komethaler, CRT-temaer).

Struktur: Universe 1 (The Drift) er gratis. Universe 2 til 5 åbnes med købet. Plan B, hvis spillet får stor trækkraft: prissætning pr. univers eller bundles. Zonerne er separate i leveldata, så skiftet er en App Store Connect-ændring, ikke en kodeændring. Beslutningen om plan B kræver data fra lanceringen, den tages ikke på forhånd.

Implementeres først efter fase 8. Intet reklame-SDK i projektet før da.

20. Silhuet-reglen, Giant og lodret placering

Silhuet-reglen. Hvert levels grid skal danne en silhuet, der kan navngives med ét ord (pilespids, kapsel, vinge, spiral). Levelnavnet må gerne pege på silhuetten. Levels designes silhuet først, mekanik derefter. Level 1 (pilespids) og 2 (kapsel) opfylder reglen. Level 3 justeres før fase 6, så silhuetten bliver tydelig uden at miste kæde-lektionen. Reglen gælder alle fremtidige levels.

Ny power-up: Giant (tilføjes tabellen over gode i afsnit 7):

Navn	Farve	Ikon	Effekt	Varighed
Giant	Bone	Stor cirkel	Bold 200 % diameter, halen vokser med, smadrer en klods med flere slag i ét	15 s

Giant og Ildkugle kan ikke være aktive samtidig; senest opsamlede vinder.

Hvad Giant er til i The Drift. Der er ingen Hærdet i level 1 til 3, så
evnen til at smadre en flerslags-klods i ét slag betyder først noget fra
level 6. Tidligt er Giant en anden ting: en dobbelt så stor bold rammer
flere klodser pr. tur, er sværere at misse med, og gør en tæt mur til et
brag i stedet for et arbejde. Den er værd at fange i alle tre baner, af
den grund og ikke af Hærdet-grunden.

Giant lader bolden gå igennem Glas som enhver anden bold. Gennemgangen er
Glassets egen regel, ikke en power-ups.

Lodret placering af muren (bundanker). Skærmen er 390x844 logisk. Reglerne:

Murens nederste række ligger med underkant på murlinjen: 57 % nede af spilfeltet (under HUD). Rækker vokser opad fra linjen. (Rettet under bygning: bundankeret alene efterlod en lav mur med mere dødt rum over sig end under. Se afsnit 21, "Murens placering".)
Minimum 100 px himmel mellem HUD og øverste række, garanteret af maks 12 rækker.
Faldzonen fra murlinje til paddle er ca. 300 px, svarende til ca. 1 sekunds reaktionstid ved starthastighed.
Leveldata får valgfrit felt "gridAnchor" (px-offset fra standardlinjen, positiv = længere ned). Standard er 0.
Implementeres i level-loaderen i fase 3. Finjusteres i fase


---

21. Beslutninger truffet under bygningen

Alt herunder afviger fra et tidligere afsnit i dette dokument. Hver
afvigelse er truffet efter at have spillet spillet, og hver af dem står
ved magt, indtil den omgøres bevidst.

Layout og tempo

- HUD'en er 196 px, ikke 44 (afsnit 8). Skærmen er dobbelt så høj som
  bred. Panelet er der, hvor det døde rum skal hen: hver pixel det
  tager, er en pixel muren ikke skal svæve over. Det bar først 140 px,
  men da murens placering blev vendt om, overtog panelet resten.
  196 er tallet, alle steder.
- Boldens grundfart står i hver levelfil: 360, 360, 380 (afsnit 4 siger
  320). Dokumentets egne forventede leveltider kan ikke nås på et 698 px
  højt felt ved 320 px/s. Farten er data, ikke kode.
- Fartstigningen fra afsnit 4 er implementeret: 4 procent per 10 klodser
  med loft ved 520 px/s.

Baggrund

- Den fjerne planet er fjernet fra Lag 2 (afsnit 2). Den lå, hvor
  paddlen arbejder, og læste som en cirkel frem for en verden.
  Baggrunden er stjerner, støv og asteroider, og hvert level får sin
  egen anelse af temperatur gennem stjernefarven og et fjernt lysvask.

Power-ups

- Langsom er ude af level 1 til 3 (afsnit 9). En bremse er en straf, når
  banen er let. Den hører til, når det bliver svært.
- Liv er tilbage i level 1. Den røg ud sammen med Langsom, men et ekstra
  liv er ikke en straf.
- Giant er i alle tre levels. Ikke på grund af Hærdet, som ikke findes i
  dem, men fordi en dobbelt så stor bold rammer flere klodser pr. tur og
  er sværere at misse med. Hærdet-evnen sover til level 6.

Skærme og tekst

- SIGNAL LOST har både RE-ENTRY og RESTART FIELD, som afsnit 16
  foreskriver. Betalingsporten på RE-ENTRY hører til efter fase 8, så
  den er gratis og kan bruges én gang pr. bane.
- Zone-sluggen i leveldata er "baeltet", spilleren læser
  "Universe 1: The Drift" (afsnit 14). Alle spillervendte strenge ligger
  i scripts/strings.gd.

Struktur

- Klodsen er data, ikke en scene. brick.gd holder anatomi og
  skadestadier, og brick_grid.gd tegner hele gridet i ét _draw. 140
  klodser bliver ikke til 140 noder.
- Power-up-systemet hedder powerup_manager.gd. Et andet navn ville koste
  redigeringer i scene, spil, tests og README uden at ændre noget.
- Score: 100 point for en standardklods, 200 for Pulse, 300 for Hærdet,
  ganget med en kombo-multiplikator på x1, x2 ved kombo 5, x3 ved 10 og
  x4 ved 20. Dokumentet siger "dobbelt" og "triple", men aldrig hvad
  grundtallet er.

Test

- tests/run.sh kører fem suiter og level-validatoren headless, og fejler
  også, hvis en suite råber op i konsollen uden at fejle et tjek.

Murens placering, som den faktisk blev

Bundankeret alene løste ikke problemet, det flyttede det. En mur på syv
rækker endte med 274 px himmel over sig og 300 px under. Halvdelen af
den tomme skærm lå der, hvor der aldrig sker noget.

Reglen som den er nu:

- HUD'en er 196 px og bruges aktivt: brand, univers, level, score, liv,
  stjerner, rekord og power-up-dock. Hver pixel den tager er en pixel,
  muren ikke skal svæve over.
- Himlen mellem HUD og øverste klodsrække er fast på 120 px. Nok til at
  komme op bag muren, ikke mere.
- Murlinjen på 57 % er nu et værn, ikke reglen: en mur, der er dyb nok
  til at nå forbi den, trækkes op i stedet.
- Slacken lander under muren, mellem klodserne og paddlen. Det er den
  halvdel af skærmen, spilleren rent faktisk kigger på.

Resultatet for de tre første levels: himmel 120 til 138 px mod 238 til
274 før, faldzone 344 til 380 px.

Klodser i de første baner

Sprængklodser hører til fra level 1, ikke fra level 3. Kædereaktionen er
den mest belønnende ting i spillet, og den skal opdages, mens man stadig
er ved at blive fanget. Level 1 har tre, level 2 én, level 3 fire.

Hærdet er ude af level 1 til 3. Man skal fanges af at smadre klodser,
før de bliver svære at smadre. Den kommer tilbage i level 6, som
progressionstabellen i afsnit 10 siger.

Silhuetterne: level 1 er en pilespids, level 2 en kapsel, level 3 en
vinge. Alle tre kan navngives med ét ord, som afsnit 20 kræver.

Kapslerne

34x22 px, ikke 20x12, og med power-uppens navn under sig. På en telefon
skal en kapsel kunne læses tværs over feltet, ikke først når den er
fanget.

Klodserne, målt

Sprængklodserne ligger nu ved siden af hinanden i stedet for spredt.
Det er forskellen på en pæn effekt og et øjeblik: en kæde skal løbe.
Målt med den bedste placering i hver bane:

- Level 1, kæden i Ice-rækken: 21 af 47 klodser i ét slag, 45 procent.
  Den ligger højt oppe, så den er belønningen for at arbejde sig op
  forbi spidsen.
- Level 2, kæden i bunden af den ydre skal plus én i kernen: 14 af 68,
  21 procent. Kapslen modstår store kæder af natur, fordi den er tynde
  skaller med luft imellem. Det er dens karakter, ikke en mangel.
- Level 3, fem sprængklodser i vingeknoglen: 18 af 48, 38 procent. Ét
  slag løber hele spændvidden. Banens navn, tegnet.

Tallene står i tests/phase3.gd, så en omtegning ikke kan gøre en bane
tam uden at nogen opdager det.

De negative power-ups

Blind, Omvendt og Tung fra afsnit 7 er bygget. Sammen med Smal og
Hurtig giver det fem forskellige straffe, og de tager hver sin ting:
hvad du kan se, hvilken vej du mener, og hvor hurtigt skjoldet svarer.
Død bliver ude, som afsnit 7 kræver i de første fem levels.

Andelen af dårlige stiger gennem de tre baner: 8, 24 og 25 procent.
Level 1 har én, mod afsnit 9's "ingen dårlige". Man skal møde
kategorien og lære den mørke kant og zigzagen at kende, før level 2
bruger den imod en.

Stjernerne skal ses tjent

Stjernerne blev regnet ud og gemt, men spilleren så dem aldrig lande.
De vises nu på FIELD CLEARED, én ad gangen med en halv sekunds
mellemrum, med en tone hver. En stjerne man allerede havde, sidder
stille i grå. At få tre på én gang og få det at vide i ét frame er ikke
den samme følelse som at se den tredje lande.

---

## De sidste power-ups, og hvorfor de opfører sig sådan

Afsnit 7's atten er bygget nu. Seks af dem havde aldrig været til at
fange. Det, dokumentet ikke kunne vide på forhånd, står her.

**Neutral er ikke dårlig.** Byt og Lotteri har grå kant, og spawn-reglen
"aldrig to dårlige i træk" gælder dem ikke. Reglen forbyder to straffe i
træk, ikke en straf efterfulgt af en chance. Den gamle kode spurgte "er
den god", og svarede nej for en neutral, så en bane med kun en straf og
en neutral kunne slet ikke give noget efter en straf.

**Lotteri er en indpakning, ikke en effekt.** Den bliver til en af banens
egne drops. En bane kan derfor aldrig uddele noget, den ikke i forvejen
indeholder, og Død kan ikke snige sig ind i de første fem levels ad
bagvejen.

**Magnet husker, hvor den greb.** Bolden bliver liggende, hvor den ramte,
ikke på midten. En magnet, man ikke kan sigte med, er en pauseknap.

**Skjoldet bruges kun på den sidste bold.** Med tre bolde i luften ville
det ellers gå til en reserve, spilleren ikke havde brug for at redde. Til
gengæld griber det Død. Kapslen er stadig ikke spildt, den brænder dit
skjold, og at se skjoldet æde et kranie er øjeblikket værd.

**Byt roterer kun de fire almindelige typer.** Volt bliver Ice, Ice
bliver Pulse, og så videre rundt. Point og drop-chancer flytter sig under
fødderne på spilleren, hvilket er, hvad en neutral skal gøre. Feltets
form flytter sig ikke, hvilket er, hvad der holder den fair. At lave en
Volt om til en Sprængklods ville være en gave; at lave den om til Hærdet
ville være en dom.

**Splint løber fra venstre mod højre**, 22 ms mellem hver. Et felt, der
bare tømmes, ser ud som en fejl. En bølge, der krydser skærmen, ser ud
som noget, man gjorde.

### Loftet over farten

Afsnit 4 sætter rampen til maks 520 px/s. Hurtig ganger 140 procent
ovenpå, og sweet spot ti procent mere: 800 px/s, to skærmbredder i
sekundet. Det er ikke en straf, det er en henrettelse. Der er nu et
absolut loft på 650. Hurtig bider stadig, og tidligt i en bane får den
sine fulde 140 procent. Autopiloten fandt fejlen: den kørte hele zonen
igennem og råbte op om 771 px/s i level 9.

---

## The Drift, alle tolv felter

Grids ligger i `levels/*.json` og er sandheden. Afsnit 10's plan holdt,
med tre afvigelser, der blev målt frem:

| Level | Navn | Klodser | Det, banen er | Afvigelse |
|---|---|---|---|---|
| 4 | The Constellation | 62 | Orion tegnet i skjulte klodser. Konstellationen dukker op, mens feltet forsvinder | |
| 5 | The Hold | 43 | Et gitter med lodrette kanaler. Gnist giver kun Magnet og Laser | |
| 6 | The Anvil | 35 | En ambolt af Hærdet med tre sprængklodser låst inde i den | Ikke ren Hærdet: 84 slag alene tog 213 sekunder på autopiloten. Foden er Volt, så banen åbner hurtigt |
| 7 | Off Axis | 48 | Et diagonalt bånd. Ingen symmetri overhovedet | |
| 8 | The Labyrinth | 42 | Sten i lag, der kaster bolden på tværs | |
| 9 | The Fuse | 71 | En ramme af sprængklodser. Ét slag tager 62 procent | Afsnit 10 lovede 60 |
| 10 | The Pane | 64 | To lag glas over det hele. Første skud går igennem begge | |
| 11 | Blackout | 49 | En diamant, blind fra første frame | |
| 12 | The Core | 136 | Alle ti klodstyper i ringe om en kerne | 136, ikke 140: kolonne 0 og 12 holdes åbne i de nederste rækker, så banerne op bag muren består |

Straffenes andel stiger hele zonen igennem: 8, 24, 25, 25, 26, 28, 30,
32, 34, 34, 36, 38 procent. Det er den eneste sværhedskurve, spilleren
ikke kan se, og den er testet, så den ikke kan falde ved et uheld.

Død dukker først op i level 9, ikke i 6, hvor reglen ville tillade den.
Tre felter mellem "reglen tillader det" og "det sker" er forskellen på en
straf og et baghold.

Par-tiderne er sat fra autopiloten gange halvanden. Autopiloten misser
aldrig bolden, så et menneske, der spiller rent, rammer stjernen, og et
menneske, der roder, gør ikke.

---

## Konstellationskortet, som det blev

Afsnit 15 lover et stjernekort i stedet for en liste, og at linjerne
tegnes, når zonen er fuldført. Det står. Resten blev besluttet undervejs.

**Figuren er en komet.** Halen løber fra nederste venstre hjørne, hvor
man begyndte, op mod højre, og ender i et hoved af tre stjerner med en
kerne indeni. Kernen er level 12, The Core. Man er selv kometen, og
kortet er den flyvning, man har lavet.

**Banen dobler aldrig tilbage.** Rækkefølgen skal kunne læses som en vej,
og en vej, der krydser sig selv, er et rod. Ingen linje går tættere på en
tredje stjerne end en tommelfinger er bred, og ingen to stjerner er
tættere på hinanden end 52 px. Begge dele står i testene, fordi et kort,
man kan komme til at trykke forkert på, er værre end en liste.

**En bane åbner, når den før den er klaret.** Ikke stjernekrav inden for
zonen. Adgang mellem zoner kan stadig koste stjerner, som afsnit 15
siger, men det hører til, når der er en zone to.

**Ikke-nåede baner tegnes stadig.** Svagt, men synligt. Et kort, der
stopper, hvor spilleren stoppede, ser ud som om der ikke er mere.

**Titlen siger CONTINUE, når der er noget at fortsætte**, og PLAY ellers.
Knappen går til den første bane, der stadig står. Kortet dukker først op
på titlen, når der er ét felt at se på. Første gang er der ingen menu
mellem PLAY og level 1.

**Zonen ender på kortet.** Før løb level 12 rundt til level 1, hvilket
ikke sagde noget. Nu åbnes kortet med tom himmel, og konstellationen
tegner sig selv, én linje ad gangen, med en tone til hver.

---

## Pause, som dokumentet ikke har

Afsnit 16 beskriver, hvad der sker, når man dør, og afsnit 17 lukker
listen over indstillinger. Ingen af dem nævner en pause, og indtil nu var
den eneste vej ud af en bane at tabe tre liv med vilje. På en telefon er
det ikke en regel, det er en fælde: der kommer et opkald, eller man har
valgt den forkerte bane.

Skærmen hedder HOLDING, ikke PAUSED. Telemetri, som afsnit 14 kræver.

- **Knappen bor i panelet.** Dock-rækken har fire pladser og ender nu i en
  kontrol. Feltet er der, hvor man spiller; panelet er der, hvor tallene
  bor, og en knap hører til hos tallene. Rækkevidden er 46 px og vokser
  opad, aldrig ned i feltet.
- **Panelet er ikke feltet.** Et tryk, der begynder over murlinjen,
  styrer ikke og affyrer ikke bolden. Det var en fejl i sig selv: en
  tommelfinger på vej mod pauseknappen sendte bolden af sted.
- **Skærmen dækker ikke banen.** Gardinet er lettere end indstillingernes,
  og feltet står bagved. Til gengæld har oplysningerne deres eget mørke
  felt, for lille tekst oven på klodser er tekst, man skal arbejde for.
- **RESUME er den første knap.** En pause er ikke en menu, man mente at
  åbne. Derefter RESTART FIELD, STAR CHART og SETTINGS.
- **Indstillinger fra en pause vender tilbage til pausen**, ikke til
  titlen. Ellers har pausen spist ens spil.
- **Mister appen fokus, holder banen.** Et opkald, en notifikation, en
  swipe. Bolden falder ikke, mens man er et andet sted.

---

## Vejen ind

Motorens egen opstartsskærm er et gråt kort med Godot-logoet på, og den
sad mellem hjemmeskærmen og spillet. Nu er den malet i spillets egen
void, uden billede, og iOS' launch screen har samme farve. Fra man
trykker på ikonet til stjernefeltet er der én ubrudt mørk flade.

Titlen kommer den anden vej end de andre skærme: gardinet starter massivt
og letter til sin normale vægt, i stedet for at fange himlen på fuld
styrke og dæmpe den. Navnet venter de første 220 ms, for der er intet at
se gennem en massiv skærm.

Indstillingerne står i `project.godot` og `export_presets.cfg`, som
Godot-editoren skriver over fra sin hukommelse, når den lukker. Derfor
tjekker både testene og `deploy.sh` dem: et logo, der stille kom tilbage,
ville først vise sig på en telefon.

**Og det gjorde det.** `boot_splash/show_image=false` slukker kun motorens
egen opstartsskærm. iOS' launch screen er et storyboard, eksportøren
genererer, og den lægger et `imageView` ind i det med
`storyboard/custom_image@2x`. Er feltet tomt, betyder det ikke "intet
billede", det betyder "brug motorens eget" — Godot-robotten, i fuld
størrelse, før spillet overhovedet starter. Feltet peger nu på et
gennemsigtigt 8x8-billede, `assets/icons/launch_blank.png`, så
storyboardet kun er sin egen baggrundsfarve. Både testen og `deploy.sh`
kræver det.

## Testene spiste den gemte progression

Suiterne deler `user://` med spillet. phase3 nulstiller, stjernekortet
nulstiller, og autopiloten gennemfører tolv baner hver eneste kørsel. Én
kørsel, og det, spilleren havde på maskinen, var væk. Ikke et crash, ikke
et fejlet tjek: bare en gemt fil, der stille blev til testdata.

`tests/save_guard.gd` lægger filen til side, kører suiten på en tom
gemmefil, og lægger den tilbage bagefter. Suiten er samtidig blevet
deterministisk: en maskine, hvor nogen har spillet, giver nu samme
resultat som en frisk.

---

## Ordforrådet, skrevet om efter at have spillet det

Afsnit 14 gav hver ting sit eget ord: zoner blev universer, baner blev
fields, døden blev SIGNAL LOST, og et ekstra liv blev RE-ENTRY. Fem
begreber, spilleren skulle lære, før noget gav mening. Det blev prøvet på
en telefon, og det virkede ikke.

Reglen nu: **ét ord pr. ting, og helst et, spilleren har i forvejen.**

| Før | Nu |
|---|---|
| FIELD | LEVEL, overalt |
| SIGNAL LOST | GAME OVER |
| RE-ENTRY | CONTINUE |
| RESTART FIELD | RESTART LEVEL |
| HOLDING | PAUSED |
| STAR CHART | SELECT LEVEL |
| UNCHARTED | LOCKED |
| FIELD CLEARED | LEVEL CLEARED |

Universerne bliver. Spilleren bad selv om dem ved navn, og de er det
eneste sted, hvor et eget ord bærer noget: fem verdener, hvoraf én er
åben. En test går grædende, hvis ordet "FIELD" eller "RE-ENTRY" nogensinde
kommer tilbage i en spillervendt streng.

## Vejen ind i et level

Titlen stiller ét spørgsmål: **START GAME** eller **SETTINGS**. Ikke
hvilket level, ikke hvilket univers, ikke om man vil se et kort.

START GAME viser de fem universer som felter med navn og status. The
Drift er åben og har en lysende ryg og en pil; de fire andre står med
COMING SOON, så man kan se, hvor spillet er på vej hen. Et univers åbner
sin egen levelliste, og et level starter.

Tre skærme, ét spørgsmål hver. Stjernekortet er ikke længere noget, man
skal opdage fra titlen: det er, hvad der ligger inde i et univers.

## HUD'en siger stedet, ikke arkivnummeret

Under logoet stod der "UNIVERSE 1 · LEVEL 7 · OFF AXIS". Der står nu
"THE DRIFT · LEVEL 7". Man ved, hvor man er, ved navnet på stedet, ikke
ved dets nummer, og banens eget navn hører til på skærmen, der
introducerer det, ikke på en linje man læser hundrede gange.

Til højre stod tre firkanter for liv og tre diamanter for stjerner, i to
forskellige former, uden at noget sagde hvilken var hvad. Nu er der én
række: tre diamanter for liv, fyldte mens de er der, hule når de er
brugt. Stjernerne hører til på de skærme, der uddeler dem.

## Rammen på alle de sider, den har

Loftet blev tegnet hele tiden, men panelet ovenover har næsten samme
farve, så det forsvandt i det: skinner ned ad begge sider og tilsyneladende
ingenting foroven. En linje af void giver det en kant at stå på.

Bunden er stadig åben, som afsnit 2 kræver, men den har fået to fødder,
én i hvert hjørne. Åbningen imellem dem er vejen ud, og nu ligner den
noget, der er tegnet med vilje.

---

## Fire ting fra en telefon

**Pauseskærmen bar for meget.** Den gentog level og score fra panelet to
tommer ovenover og tilbød indstillinger. Nu står der ét ord og tre veje:
RESUME, RESTART LEVEL, SELECT LEVEL. Et hold-felt er ikke der, hvor nogen
går hen for at skifte haptik. Ordet har fået et blødt bånd under sig, for
feltet skal blive stående bagved, og et hvidt ord på en mur af klodser er
et ord, man skal lede efter.

**Et holdt level bliver holdt.** Kapslerne blev ved med at falde bag
skærmen, blev grebet af en paddle, ingen styrede, og klokken løb på alt,
der var aktivt. Rettelsen skulle laves to gange: `set_process(false)` på
manageren gør ingenting ved kapslerne, fordi de er dens børn med deres
eget `_process`. `process_mode = DISABLED` arves, det gør en slukket
`_process` ikke. Testen fangede den forkerte rettelse.

**Paddlen er rykket op.** Feltets bund er 778 i stedet for 800, så
skjoldet ligger 713 og der er 126 px tommelfinger under det. Faldzonen
bliver 22 px kortere, hvilket er den pris, en hånd, der holder telefonen,
altid kommer til at koste.

**Alle tolv baner har en kæde nu.** Fire af dem havde ingen sprængklods
overhovedet: The Constellation, The Hold, The Labyrinth og The Pane. En
mur, der kommer ned én klods ad gangen, er ikke et øjeblik. Gulvet er en
femtedel af banen i ét slag, og det står i testene:

| Level | Kæde | | Level | Kæde |
|---|---|---|---|---|
| Liftoff | 45 % | | The Anvil | 37 % |
| The Capsule | 21 % | | Off Axis | 31 % |
| The Chain | 38 % | | The Labyrinth | 52 % |
| The Constellation | 31 % | | The Fuse | 62 % |
| The Hold | 35 % | | The Pane | 42 % |
| Blackout | 31 % | | The Core | 21 % |

The Fuse er stadig den, kæden hører til: ingen anden bane må overhale
den, og det er også en test. The Constellation blev tegnet om undervejs,
så båndene rører hinanden: en kæde kan ikke springe over en tom række,
og konstellationen er nu det, der bliver stående, i stedet for et lag
for sig.

---

## To tryk, og den forkerte knap

Begge dele var i den byggede app. Hver knap skulle trykkes to gange, og
efter en tur i indstillingerne åbnede START GAME indstillingerne igen.

Samme årsag: trykket handlede på `_hover`, som regnes ud én gang pr.
frame ud fra musens position. På en telefon er der ingen mus, før en
finger allerede er landet et sted. Første tryk fandt `_hover` = -1 og
gjorde ingenting; andet tryk virkede. Og på vej tilbage fra
indstillingerne stod `_hover` stadig på den knap, der havde været under
det sidste tryk — som på titlen er der, hvor SETTINGS ligger.

Trykket handler nu på, hvor fingeren landede. `_hover` er kun lys, og
den følger kun musen, indtil en finger har bevist, at der ikke er nogen.
To tests trykker på koordinater uden nogensinde at røre en mus.

## Universerne er steder, ikke rækker

Efter PLAY møder man fem himmellegemer i stedet for fem etiketter: et
bælte af sten, der driver rundt om en mørk kerne; en verden med et
ringplan; en korona med en protuberans stående ud fra sig; en violet sky
med tre stjerner fanget indeni; og et hul med en skive af lys, der falder
i. Alle fem er tegnet i kode (`scripts/cosmos.gd`), fordi alternativet er
fem billedfiler, ingen kan rette.

Linjen ned gennem dem er vejen indad, som afsnit 1 beskriver. De fire
lukkede står med 30 procent lys: man skal kunne se, hvor spillet er på
vej hen.

Levellisten har fået universets egen farve bag sig, og ruten tegnes, som
den flyves: en linje mellem to levels, når begge er klaret. Selve
konstellationen venter stadig på, at hele universet er ryddet. En bane
taget med alle tre stjerner får et kryds af lys — det er det eneste
mærke på kortet, der siger perfekt.

Navnet `Sky` var optaget af Godot selv, og den slags kollision viser sig
som "Static function not found in base GDScriptNativeClass". Klassen
hedder `Cosmos`.

---

## Kortet, tegnet som et kort

Levellisten var tolv punkter i mørket. Den er nu et kort: en ramme med
hjørnemærker, et svagt gitter at måle på, og ruten stiplet hele vejen op
til The Core, så man kan se, hvor det ender, fra det sted man står.

- **Der står, hvor man begynder.** Den første bane, der stadig står, har
  en pulserende ring og ordet START HERE over sig. Et kort uden noget
  markeret er et kort, man skal regne ud, før man kan spille.
- **Målet er markeret fra begyndelsen.** Den sidste bane bærer sit navn
  og to ringe. En rute er kun en rute, hvis der er noget for enden.
- **Navnebjælken er en knap.** Der stod "LEVEL 05 · THE HOLD" nederst,
  under tommelfingeren, og der skete ingenting, når man trykkede. En
  etiket, der læses som et valg og ikke er et, er værre end ingen
  etiket. Nu starter den den bane, den nævner, og den har en pil.
- **Planeterne er skruet ned.** Skyerne bag kortet er halvt så stærke,
  og gloriet om en klaret bane er mindre. Kortet skal kunne læses.

Farveovergangene tegnes som en vifte af trekanter fra en oplyst midte
til en gennemsigtig kant. Cirkler stablet med faldende alfa efterlader
synlige ringe, uanset hvor mange man bruger, og en ring ligner en skydeskive,
ikke en sky.

Pauseskærmens tredje knap hedder MAIN MENU og går til titlen. SELECT
LEVEL var et sted at gå hen, ikke en vej ud.

---

## Fase 5, poleringen

**Rammen, målt i pixels.** Panelets sidste gradientbånd startede ved
HUD_HEIGHT og løb et helt bånd forbi den: det malede ti pixels ned i
feltet og dækkede loftet. Derfor så det ud som om der var skinner ned ad
begge sider og ingenting foroven. Bunden er nu en fuld sokkel med en
mund skåret i midten, 150 px bred, i stedet for to fødder i hjørnerne.
Målt med pixelaflæsning, ikke med øjet: `#232330` hele vejen rundt med
lyskant indenfor.

**Boblerne er væk.** Afsnit 2's drivende asteroide-silhuetter læste på en
telefon som luft under et panserglas. Baggrunden er stjerner, støv og et
fjernt lysvask.

**Halerne på banerne.** At stå tilbage og lede efter tre klodser er det
mindst interessante i spillet. To ting: de sidste tre klodser lyser nu,
så de siger hvor de er, og de tre første baner er tegnet om, så de ikke
ender i en enlig klods. Level 1 sluttede før i en enkelt Gnist på
spidsen, level 3 i en enkelt skjult klods. Level 1 er 43 klodser mod 47
og slutter i en klynge på fem med to Gnister i. Level 2 er 64 mod 68 og
har ingen enkeltklods-søjler mere.

**Ceremonien har en rækkefølge.** Den står som en tabel i screens.gd:
udlæsningen 0,10, første stjerne 0,55, en hver 0,34 derefter, scoren
færdig 1,05, vejen videre 2,10, slut 2,35. Et tryk før slutningen kører
den til ende; et tryk efter går videre. Der findes ingen tilstand
imellem de to, og det er dét, der forhindrer en hurtig finger i at
opfinde en.

**Lyd.** Neutrale kapsler har fået deres egen tone, der hverken er en
gave eller en straf. Stjernerne har tre toner, en pr. stjerne, stigende.
Level clear er et motiv i stedet for en akkord. Dronen dykker ved tab og
kommer tilbage over halvandet sekund i stedet for at blive slukket.

**Haptik.** Et tik pr. stjerne, to knok ved level clear, ét langt buzz
ved game over. Alt gennem `pulse()`, som spørger til indstillingen
først.

**Ingen allokering pr. frame.** Ceremoniens rækketabel er en konstant, og
par-teksten bygges én gang, når skærmen åbnes. Kortets stiplede linjer
tegnes direkte i stedet for at bygge en liste pr. segment. Autopiloten
måler statisk hukommelse fra første bane til sidste og fejler, hvis den
vokser.

**Optagetilstand, afsnit 18.** F5 slår den til og skjuler panelet. 1
bygger muren op igen, 2 udløser den største kæde på feltet, 3 giver tre
bolde, 4 lader banen falde. Hele blokken ligger bag
`OS.is_debug_build()`, så den ikke findes i et release-build.

En note til næste gang: `var halo := brick.color()` kan ikke udlede sin
type, fordi `color()` ikke erklærer en. Parse-fejlen fik test-scenen til
at hænge i ti minutter med nul procent CPU og ingen output overhovedet.
Symptomet på en parse-fejl er tavshed, ikke en fejlbesked.

---

## Fire ting kapslerne lovede og ikke gjorde

Alle nitten power-ups fandtes. Fire detaljer i afsnit 5 og 7 var tekst
uden kode bag.

**Zap havde intet lyn.** Naboklodserne røg, men der var ingenting at se.
Der går nu et lyn fra den ramte klods til hver nabo den tager: fire
segmenter, rystet af den lige linje, væk på 180 ms, med et loft på tolv
ad gangen så en bold gennem en mur ikke kan lade listen vokse.

**De dårlige kapsler faldt lige ned.** Zigzagget var tegnet på kanten af
kapslen i stedet for at være dens bane. Nu svinger de 26 px til hver side
på vej ned, og de holdes inde i feltet, for en kapsel der svinger ud over
kanten er en, paddlen aldrig kan nå. Den mørke kant siger hvad det er;
banen giver dig et sted at være i stedet.

**Byt blinkede i ét frame.** Hele muren skiftede farve på én gang, hvilket
læses som en fejl. Blinket løber nu hen over muren fra venstre.

**Lotteri afslørede sig med det samme.** En møntkast, man får svaret på
øjeblikkeligt, er ikke et møntkast, det er et drop. Kapslen holder nu
vejret i 550 ms med et spørgsmålstegn over paddlen, der blinker hurtigere
og lysere, indtil den siger hvad den trak.

Og en note til, som kostede tid to gange på én dag:
`Godot --headless --check-only --script res://fil.gd` finder syntaksfejl
på sekunder. Uden den er symptomet på en parse-fejl, at test-scenen
hænger uden output.

---

## Ét tryk er ét tryk

MAIN MENU fra en holdt bane gik til titlen og videre ind i
indstillingerne, og BACK derfra sprang tilbage i dem igen. Årsagen var
ikke knapperne: iOS sender berøringen, og Godots musemulering sender et
*andet* tryk samme sted. Det første tryk handlede, skærmen lagde sig om,
og det andet landede på den knap, der nu var flyttet ind under fingeren.
På titlen er det SETTINGS.

`pointing/emulate_mouse_from_touch=false`. Berøring og mus håndteres
begge eksplicit; ingen af dem har brug for, at motoren opfinder den
anden. Og som ekstra værn: to tryk inden for 150 ms er én finger, ikke to
beslutninger.

## Afbøjningen, målt

Klagen var, at bolden går den forkerte vej. Modellen blev målt over hele
paddlens bredde i stedet for læst: 152 grader yderst til venstre, 88 i
midten, 27 yderst til højre, og fortegnet følger altid den side, man
rammer. Den var rigtig.

Det, der manglede, var **paddlens egen bevægelse**. Griber man mens man
fører skjoldet, bæres bolden nu med i den retning: op til 0,42 lagt til
retningens x-komposant, klampet så et flik aldrig kan flade returen ud
under mindstevinklen. Hvor man rammer bestemmer stadig vinklen; farten
bestemmer resten af sigtet. Det er forskellen på at redde bolden og at
skyde med den.

## Kortet

Rammen med hjørnemærker er væk. En ramme om en himmel er en vinduesramme,
og den sad et par pixels forkert i forhold til alt andet. Gitteret alene
siger "kort" godt nok.

START HERE har fået jord under sig: et mærke med kant, en pil der falder
ned mod stjernen og tilbage, og to ringe der ånder i forskellig takt. Det
er nu det højeste på skærmen, hvilket det skal være.

---

## Finalen

Level 12 er ikke bare den sidste bane. Når hele universet er ryddet,
lukkes kapitlet med et billede.

Feltet går ud. Så tændes de tolv stjerner, én ad gangen i den rækkefølge
de blev fløjet, hver med sin tone og sit tik i hånden. Derefter tegnes
de fjorten linjer imellem dem, og kometen står færdig. Der er ingen tekst
i det overhovedet.

**Det er de samme koordinater, kortet bruger.** Når kortet åbner
bagefter, flytter figuren sig ikke en eneste pixel: billedet, spilleren
lige har set blive tegnet, *er* kortet, de lander på. Det er hele
pointen med at tegne den i banen i stedet for på kortet.

Et tryk kører billedet færdigt, det næste lander på kortet, og gør man
ingenting, går den selv videre to sekunder efter figuren er hel. Samme
regel som ceremonien: der findes ingen tilstand mellem "kør den ud" og
"gå videre".

Har man sprunget en bane over og klarer level 12 alligevel, er der ingen
konstellation at tegne, og man lander på kortet som før. Billedet er
universet, der er færdigt, ikke level 12, der er færdigt.

---

## Fase 9: juice, Game Center, session, TestFlight

**Den sidste klods hænger.** 80 ms i fjerdedels fart, i spillerens egen
tid og ikke i urets, og præcis én gang pr. bane. Den hænger på gridets
`cleared`-signal, som udsendes én gang uanset om en bold tog den sidste
klods eller en kæde gjorde. Derfor virker kæde-tilfældet af sig selv:
signalet kommer på kædens sidste klods, ikke på den, der blev ramt.

**Redningen.** Et greb inden for 30 px af Ember-linjen strækker tiden til
0,6 i 120 ms, sender ti gnister op fra skjoldets kant og har sin egen
lyd. Højst én gang hvert tredje sekund: en bold, der rasler langs bunden,
ville ellers sætte hele spillet i slowmotion.

**Kombo-milepæle.** Ved 10 vokser halen fire led, og en anden stemme
kommer ind under dronen. Ved 20 ånder containment-feltet i takt med den.
Ingen screen shake. Alt går tilbage i ét trin, når komboen brydes — og
testen kræver symmetri, for det er sådan et spil ender med en permanent
lang hale efter én god tur.

**Kapslerne fanges.** De sidste tolv pixels er et greb, ikke en kollision:
kapslen trækkes ind i skjoldet over 40 ms. Effekten udløses, når den
lander, én gang, uanset hvor mange frames turen tager.

**Dronen har en tabel.** `Audio.DRONE_TUNING`, ét blok pr. univers, med
pitch, filterbånd og den anden stemmes stemning og styrke. The Drift står
højt og tyndt med filteret godt åbent, og dens lag ligger en kvint over i
stedet for en oktav under — det er dét, der gør den metallisk frem for
vejragtig. Universerne 2 til 5 kan lyde som sig selv uden at røre andet
end den tabel.

**Session.** `scripts/session.gd` skriver banen ned, når appen går i
baggrunden: bane, mur, score, liv. Kommer man tilbage — også efter appen
er blevet dræbt — ligger banen som den var, med bolden klæbet til
paddlen. Kapsler i luften kastes væk. En kapsel, der har hængt i to dage
og så falder ned over en spiller, der har glemt banen, er ikke en
venlighed. En bane, der slutter, tager sin session med sig, uanset
hvordan den slutter.

**Game Center er en søm, ikke en integration.** Godot 4 har ingen Game
Center — 3.x-modulet kom ikke med over — og den rigtige kræver et
iOS-plugin, der ikke kan bygges, før appen har en post i App Store
Connect. `scripts/game_center.gd` er hele fladen, spillet kalder, med
platformen bagved valgfri: uden plugin er hvert kald en no-op, der
returnerer false. Ti achievements og fjorten leaderboards ligger i
`docs/gamecenter.md` med de id'er, der skal tastes ind.

**TestFlight.** Version 1.0, build 1. `docs/testflight.md` har hele vejen
fra arkiv til ekstern gruppe, og fem spørgsmål, der er værd at stille en
tester — "any feedback?" giver ingenting brugbart tilbage.

En fejl værd at huske: `pulse_pattern` brugte `create_timer` til de
forsinkede knok. En timer, der stadig venter, når træet lukker, er et
objekt, der bliver efterladt, og autopiloten rydder tolv baner pr.
kørsel. Køen ligger i `_process` nu, og hukommelsen hen over zonen faldt
fra 4,8 til 1,4 MB.

---

## Mosaik-reglen (tilføjelse til afsnit 20)

Hver bane bruger mindst tre af de fire etslags-farver i et mønster, der
kan læses på et øjeblik: bånd, spejlinger eller gradienter, der følger
eller modellerer silhuetten. Et enkeltfarvet område må ikke strække sig
over mere end to nabo-rækker.

Ti af tolv baner brød reglen, før den blev skrevet. De er omfarvet, hver
efter sin egen form: bånd på pilespidsen, spejling på vingen, søjler på
gitteret, diagonaler på det skæve bånd, ringe på ambolten og kernen, og
en koncentrisk diamant på Blackout.

**Balancen er urørt.** Antallet af E, H, G, S, X og ? pr. bane er præcis
det samme, og det samme er antallet af klodser i alt, drop-tabellerne og
par-tiderne. Kun fordelingen af V/I/P/F har flyttet sig — og Pulse er
lagt tilbage til nøjagtig samme antal pr. bane som før, fordi Pulse er
dobbelt point og dermed balance og ikke farve. Pulse ligger nu aldrig
yderst i en række: den er en belønning og hører inde i muren.

Validatoren håndhæver de to første regler. Pulses placering står i
testene, hvor hensigten kan skrives ned.

Alle tolv vægge er gengivet i `docs/walls/`, tegnet med optagetilstanden,
så mønstrene kan bedømmes ved siden af hinanden.

## Kæden som trykbølge

En klods, kæden tager, kaster nu sine splinter væk fra eksplosionen med
halvanden gang farten, og den vaskes Flare-orange i 60 ms, før den går.
Forsinkelsen mellem klodserne er uændret. Forskellen er, hvad man læser:
før forsvandt otte klodser i rækkefølge, nu æder noget sig gennem muren.

Feel_test har fået tilstand 4: hver klodstype tegnet to gange, flad til
venstre og affaset til højre, samme farver og samme afstand. Det er den
eneste ærlige måde at vælge mellem to udgaver af den samme flade på — på
en telefon, ikke på en skærm.

---

## Efter endnu en tur på telefonen

**Sprængklodsen lyser.** Den havde en mørk kerne, der først vågnede, når
bolden var tæt på. Men en klods, der tager naboerne med sig, skal kunne
plukkes ud af en fuld mur, *før* man sigter — ellers er informationen
kommet for sent. Den er orange nu, med et kors og fire diagonale gnister
ud fra midten, og den ånder. Kernen bliver hvidglødende, når bolden
nærmer sig, som den altid har gjort.

**De grønne lamper er skruet ned.** Afsnit 2 lod de nærmeste stjerner
svare på hver eneste klods. Med en kæde i gang er det et felt af lamper,
der blinker bag det, spilleren prøver at se på. Himlen svarer nu kun
rammen, hvor det er én hændelse ad gangen.

**Magneten skød den forkerte vej.** Det var ikke afbøjningen: `launch()`
valgte en tilfældig side og ignorerede fuldstændig, hvor bolden lå på
skjoldet. Med magnet er skjoldet et sigte, og et sigte, der ser bort fra,
hvor man har lagt bolden, er ikke et. En holdt bold forlader nu skjoldet
præcis som den ville have gjort, hvis den var hoppet der — samme model,
samme bæring fra paddlens egen bevægelse.

**Fire opstillinger er tegnet om til billeder.** The Constellation er
Karlsvognen, Off Axis er et lyn, The Labyrinth er en spiral med
sten-propper, og The Pane er et vindue med fire ruder og en sprosse af
sprængklodser ned gennem midten. De fire var mønstre; de er former nu.

**Platformen op igen, og hvad det kostede.** Feltets bund er 738. På den
dybeste mur, level 12's tolv rækker, kan himlen og faldzonen ikke begge
betales. Faldzonen vinder: den er løftet fra afsnit 20 — omkring et
sekund at reagere i — og himlen giver sine sidste to pixels. Det står i
`origin_for` som en tredje klemme ved siden af de to, der var der.

---

## Laseren, skyggen og tre billeder mere

**Laseren skyder selv.** Den ville have et tryk, og et tryk er endnu et
job til den hånd, der allerede styrer. Spilleren skal sigte med
skjoldet, ikke betjene det. Kadencen er den samme som før, 220 ms; det
eneste, der er væk, er kravet om at bede om hvert eneste skud. Et tryk
gør nu kun én ting: sender en ventende bold af sted.

**Glansen over skjoldet er væk.** De tre rækker Volt, der lå over
overkanten, læste som en udtværing hen over feltet i stedet for som en
projektion. Kanten, bolden rammer, er tydeligere uden noget svævende
over sig. Skyggen under bliver, for det er den, der forhindrer skjoldet
i at flyde.

**Tre baner mere er blevet billeder**, og de hedder nu det, de ligner:

- **The Chain** er to sammenkoblede led med sprængklodserne i samlingen
  og en glasrække under. Før var den en vinge.
- **The Hold** er en hængelås: bøjle af is, krop af flare, Pulse som
  nøglehul og Gnisterne inde i kroppen, hvor de skal findes.
- **The Anvil** er en ambolt med horn: bred flade foroven, hul talje med
  sprængklodserne i, og en flaret fod.

Sammen med de fire fra sidste pas — Karlsvognen, lynet, spiralen og
vinduet — er syv af tolv baner nu former frem for mønstre. De fem
resterende (pilespidsen, kapslen, ringen, diamanten og kernen) var det
allerede.

---

## Kapslerne skal kendes fra hinanden på en meter

Gode og dårlige havde samme form og adskilte sig på kantens farve. Det er
for lidt på en telefon i bevægelse. Nu er der tre former:

- **Gave:** afrundet kapsel, lys kant, sin egen farve.
- **Straf:** hjørnerne skåret af som en fareplade, mørk kant med zigzag,
  og et rødt skær, der *banker*. Bevægelse er det, der læses hurtigst.
- **Møntkast:** sekskant med grå kant.

Bomb skiftede fra Ember til Flare undervejs: en gave i alarmfarven
ophæver hele signalet.

Fire nye, så der er treogtyve i alt. Hver af dem tager sin egen ting:

| Navn | | |
|---|---|---|
| **Bomb** | god | Den næste klods, bolden rører, springer som en sprængklods. Ét skud, sigtet i hånden — det eneste sted i spillet, hvor spilleren selv placerer en eksplosion |
| **Bonus** | god | 2500 point. Ikke alt skal ændre spillet; noget må bare være værd at fange |
| **Shrink** | dårlig | Bolden er 60 procent. Et mindre mål for skjoldet og en mindre hammer mod muren |
| **Wobble** | dårlig | Udgangsvinklen er op til tolv grader ved siden af. Ikke hurtigere, ikke blind: upålidelig |

Straffenes andel pr. bane er **uændret** — kun hvilke straffe der findes.

## Fire vægge mere, tegnet med farven

Mosaik-passet gav banerne mønstre. Det her giver dem billeder, hvor
farven *er* tegningen og ikke et bånd hen over den:

- **Liftoff** er en raket: Volt-næse, is-vindue, orange finner,
  sprængklodser som motor og en flamme under.
- **The Capsule** er en pille med skal, kappe og en ladning i bunden.
- **Blackout** er et øje — banen, hvor man intet kan se, tegnet som det
  eneste organ, der ser.
- **The Core** har fået sin lodrette lunte tilbage gennem alle ringene.

## Og evnen til at se en fejl på en telefon

`debug/file_logging` er slået til, og appens mappe er tilgængelig fra
Filer. Et crash i en andens hånd efterlod før ingen spor overhovedet;
nu ligger loggen i `user://logs/` og kan hentes fra maskinen. Det burde
have været gjort, første gang spillet forlod min skærm.
