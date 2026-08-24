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

Grid er 13 kolonner, maks 12 rækker. Symboler:

```
.  tom
V  Volt       I  Ice        P  Pulse      F  Flare
H  Hærdet     S  Sten       E  Sprængklods
              (H bruges først fra level 6, se afsnit 21)
G  Glas       X  Gnist      ?  Skjult
```

---

### Level 1: Liftoff (Afgang)

Lærer: Bolden, paddlen, at vinkel er alt. Og kæden, fra første bane.

```
.............
.VVVVVVVVVVV.
.IIIIIIIIIII.
..FFEFFFEFF..
...PPPEPPP...
....VVVVV....
.....III.....
......X......
```

47 klodser, heraf 3 sprængklodser. Silhuet: pilespids. parTime 60
sekunder, boldfart 360 px/s. Ingen Sten, ingen Hærdet.

Hvorfor det virker:
- Den omvendte trekant sender hurtigt bolden op bag muren. Det er øjeblikket, alle husker fra DX-Ball: bolden bouncer i hjørnet og smadrer 10 klodser, mens man ser til.
- Spidsen er en Gnist. Nem at ramme først, garanteret power-up, tvunget til Bred i level 1. Succes inden for 5 sekunder.
- De tre sprængklodser ligger inde i trekanten. Kædereaktionen er det mest belønnende i spillet, og den skal findes mens man stadig er ved at blive fanget, ikke i level 3.
- Farverne skifter pr. række, så grid og pointsystem læres visuelt.

Power-up-tabel: Multi 25 %, Ildkugle 25 %, Bred 15 %, Laser 15 %, Liv 10 %, Giant 10 %. Ingen dårlige. (Rettet under bygning: Langsom er ude af de tre første levels, se afsnit 21.)

Visuelt øjeblik: Ved sidste klods lyser rammen op, og hele stjernefeltet blitzer i ét frame. Stilhed i 1 sekund. Så clear-lyden. Spillerens første bekræftelse af, at rummet ser dig.

---

### Level 2: The Capsule (Kapslen)

Lærer: Sten kan ikke smadres, men bruges.

```
.S.........S.
.VVVVVVVVVVV.
.VFFFFEFFFFV.
.V.........V.
.V.IIIIIII.V.
.V.I.....I.V.
.V.I.PPP.I.V.
.V.I.....I.V.
.V.IIIIIII.V.
.VVVVVVVVVVV.
```

68 smadrelige klodser plus 2 Sten, heraf 1 sprængklods. Silhuet: kapsel.
parTime 110 sekunder, boldfart 360 px/s. Hærdet-rækken er erstattet af
Flare med en sprængklods i midten.

Hvorfor det virker:
- En kapsel i en kapsel. Ydre Volt-skal, indre Ice-skal, Pulse-kerne. Tre små sejre i ét level.
- Flare-rækken øverst ryger sidst, og sprængklodsen i dens midte er belønningen for at nå derop.
- De to Sten-kerner i hjørnerne kaster bolden ind mod midten i stedet for at fange den. Sten er aldrig dekoration. De styrer altid bolden.

Power-up-tabel: Multi 25 %, Ildkugle 20 %, Laser 20 %, Bred 15 %, Giant 10 %, Smal 10 %. Første dårlige, men kun én.

Visuelt øjeblik: Når Pulse-kernen smadres, sender den en større lysbølge end normalt, alle Ice-klodser flimrer, og det fjerne lys i baggrunden får et kort glimt.

---

### Level 3: The Chain (Kæden)

Lærer: Sprængklodser smadrer naboer. Glas lader bolden gå igennem.

```
.............
.VV.......VV.
.VVVV...VVVV.
.VVVVVEVVVVV.
..GGEGGGEGG..
...PPPPPPP...
....PPEPP....
.....VVV.....
......?......
```

48 smadrelige klodser, heraf 4 sprængklodser. Silhuet: vinge. parTime 80
sekunder, boldfart 380 px/s.

Hvorfor det virker:
- Sprængklodserne ligger på vingeknoglen. Ét slag løber ud gennem hele vingen.
- Glas-rækken lader bolden passere. Første gang føles det som en fejl. Anden gang forstår man, at det er vejen op bag vingespidserne.
- Den skjulte klods i bunden viser sig, når en Volt over den ryger. Lille overraskelse.

Power-up-tabel: Multi 20 %, Ildkugle 20 %, Giant 15 %, Laser 15 %, Zap 10 %, Bred 10 %, Hurtig 5 %, Smal 5 %.

Visuelt øjeblik: Sprængklodsen midt i vingen tager alle 8 naboer i spiral med 40 ms forsinkelse hver. Screen shake 6 px. Stjernerne omkring blinker Ember. Det er spillets første wow og skal sidde perfekt.

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
