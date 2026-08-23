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
- Midten: En fjern planet i nederste hjørne, ca. 120 px, i dæmpede toner (#1A2030 med en tynd #2A3448 atmosfærelinje). To til tre asteroide-silhuetter (#12121A) driver ekstremt langsomt, 1 px per 2 sekunder, og roterer umærkeligt. Parallax 3 px.
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

### Anatomi af en klods

Hver klods er bygget af fem elementer.

```
┌──────────────────┐  1. Toplinje: 1 px, lysere end basen (+20 % lum)
│ ░░░░░░░░░░░░░░░░ │  2. Base: materialefarven, flad
│ ░░░░░░░░░░░░░░░░ │  3. Indre tekstur: 2 til 3 px grain eller mønster, opacity 0.12
│ ░░░░░░░░░░░░░░░░ │  4. Kernelys: lille lysere felt øverst til venstre, 6x3 px
└──────────────────┘  5. Bundlinje: 1 px, mørkere end basen (-30 % lum)
```

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

Øverst, 44 px høj. Void-baggrund med 1 px linje under i #232330.

Venstre: ASTRO BALL i Unbounded 13 px, Bone, letter-spacing 2. Under: LEVEL 7 i Space Grotesk 9 px, Slate.
Højre: Score i Space Grotesk 14 px, Volt, tabular, mellemrum som tusindtalsseparator. Under: tre prikker for liv. Fulde er Bone, tabte er #444441.
Midt: Kombo-tal fra 3+. Unbounded, Volt, vokser med komboen.

Aktive power-ups som små ikoner under HUD med tidsbjælke. Maks 4.

---

## 9. De første tre levels

Formålet: lære spilleren alt i afsnit 3 til 7 uden en eneste tekstforklaring. Hvert level lærer én ting.

Grid er 13 kolonner, maks 12 rækker. Symboler:

```
.  tom
V  Volt       I  Ice        P  Pulse      F  Flare
H  Hærdet     S  Sten       E  Sprængklods
G  Glas       X  Gnist      ?  Skjult
```

---

### Level 1: Afgang

Lærer: Bolden, paddlen, at vinkel er alt.

```
.............
.VVVVVVVVVVV.
.IIIIIIIIIII.
..FFFFFFFFF..
...PPPPPPP...
....VVVVV....
.....III.....
......X......
```

47 klodser. Forventet tid 45 til 70 sekunder. Ingen Sten, ingen Hærdet.

Hvorfor det virker:
- Den omvendte trekant sender hurtigt bolden op bag muren. Det er øjeblikket, alle husker fra DX-Ball: bolden bouncer i hjørnet og smadrer 10 klodser, mens man ser til.
- Spidsen er en Gnist. Nem at ramme først, garanteret power-up, tvunget til Bred i level 1. Succes inden for 5 sekunder.
- Farverne skifter pr. række, så grid og pointsystem læres visuelt.

Power-up-tabel: Bred 40 %, Multi 30 %, Langsom 20 %, Liv 10 %. Ingen dårlige.

Visuelt øjeblik: Ved sidste klods lyser rammen op, og hele stjernefeltet blitzer i ét frame. Stilhed i 1 sekund. Så clear-lyden. Spillerens første bekræftelse af, at rummet ser dig.

---

### Level 2: Kapslen

Lærer: Hærdet tager flere slag. Sten kan ikke smadres, men bruges.

```
.S.........S.
.VVVVVVVVVVV.
.VHHHHHHHHHV.
.V.........V.
.V.IIIIIII.V.
.V.I.....I.V.
.V.I.PPP.I.V.
.V.I.....I.V.
.V.IIIIIII.V.
.VVVVVVVVVVV.
```

66 smadrelige klodser plus 2 Sten. Hærdet-rækken kræver 27 slag alene. Forventet tid 90 til 130 sekunder.

Hvorfor det virker:
- En kapsel i en kapsel. Ydre Volt-skal, indre Ice-skal, Pulse-kerne. Tre små sejre i ét level.
- Hærdet-rækken øverst ryger sidst. Spilleren lærer skadestadierne ved at se dem langsomt.
- De to Sten-kerner i hjørnerne kaster bolden ind mod midten i stedet for at fange den. Sten er aldrig dekoration. De styrer altid bolden.

Power-up-tabel: Bred 25 %, Multi 25 %, Ildkugle 15 %, Laser 15 %, Langsom 10 %, Smal 10 %. Første dårlige, men kun én.

Visuelt øjeblik: Når Pulse-kernen smadres, sender den en større lysbølge end normalt, alle Ice-klodser flimrer, og planeten i baggrunden får et kort lysglimt på atmosfærelinjen.

---

### Level 3: Kæden

Lærer: Sprængklodser smadrer naboer. Glas lader bolden gå igennem.

```
.............
.HHHHHHHHHHH.
.H....E....H.
.HHHHHHHHHHH.
.............
.GGEGG.GGEGG.
..PPPPPPPPP..
...E..E..E...
....VVVVV....
......?......
```

52 smadrelige plus 5 Sprængklodser. Forventet tid 60 til 100 sekunder, kan gøres på 30 med de rigtige slag.

Hvorfor det virker:
- De tre Sprængklodser nederst ligger lige over paddlen. Kædereaktionen ses inden for 10 sekunder.
- Glas-rækken lader bolden passere. Første gang føles det som en fejl. Anden gang forstår man, at det er vejen op bag Hærdet-kapslen.
- Hærdet-kassen øverst har én Sprængklods i midten. Det eneste, der rydder de 24 Hærdet hurtigt. Den, der opdager det, føler sig klog.
- Den skjulte klods i bunden viser sig, når en Volt over den ryger. Lille overraskelse.

Power-up-tabel: Multi 30 %, Ildkugle 20 %, Zap 15 %, Bred 15 %, Hurtig 10 %, Smal 10 %.

Visuelt øjeblik: Sprængklodsen i Hærdet-kassen tager alle 8 naboer i spiral med 40 ms forsinkelse hver. Screen shake 6 px. Stjernerne omkring blinker Ember. Det er spillets første wow og skal sidde perfekt.

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

Valideringsregler:
- Præcis 13 tegn pr. række.
- Maks 12 rækker.
- Ingen Sten i nederste række.
- Mindst 20 smadrelige klodser.
- Power-up-procenter summerer til 100.

---

## 12. Lyd og rumfølelse

- Alle lyde har en kort, mørk rumklang, som om feltet er et stort kammer. Det er den billigste vej til at føle sig inde i rummet i stedet for foran en skærm. DX-Balls lyde var tørre. Vores er i et rum.
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
