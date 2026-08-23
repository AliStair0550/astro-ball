# Astro Ball

Du er en komet. Foran dig ligger felter af mineraler, is og energi i et gammelt
asteroidebælte. Din bane er spærret.

Designdokumentet ligger i [CLAUDE.md](CLAUDE.md).

## Fase 1: game feel-prototypen

Denne fase indeholder kun bold, paddle og containment-felt. Ingen klodser,
ingen power-ups, ingen lyd, intet liv-system. Punkt 1 i byggerækkefølgen:
det skal føles rigtigt i hånden, før noget andet er værd at bygge.

- **Motor:** Godot 4.7 (standard, ikke .NET)
- **Viewport:** 390 x 844 logisk, iPhone portræt, `canvas_items` med aspect `keep`
- **Styring:** musens x. Klik sender bolden afsted. Touch kommer i fase 4.
- **F1:** debug-overlay med fart, udgangsvinkel og fps

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

### Struktur

```
project.godot
scenes/game.tscn        hovedscene
scripts/arena.gd        containment-feltet, ramme, emittere, ledningsføring
scripts/ball.gd         kometen, swept circle-kollision, komethale
scripts/paddle.gd       deflektorskjoldet, squash, sweet spot
scripts/background.gd   stjernefelt, planet, asteroider, parallax
scripts/game_feel.gd    screen shake, hitstop, squash
levels/                 tom, bruges i fase 3
```

### Kør

```
godot --path . 
```

Eller åbn mappen i Godot 4.7 og tryk F5.
