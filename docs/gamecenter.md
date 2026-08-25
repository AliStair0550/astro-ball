# Game Center

What has to be typed into App Store Connect, and what the game already
calls. The ids here are the contract between the two: change one and it
has to change in both places.

## The state of it

Godot 4 has no Game Center of its own — the 3.x module did not come
across. `scripts/game_center.gd` is the whole surface the game uses, with
the platform behind it optional. Without a plugin every call is a no-op
that returns `false`, and that is the state on a Mac, in the tests, in a
headless run, and on a phone with Game Center switched off or no signal.

Nothing here blocks play, shows a dialogue, or fails loudly. A player who
has never heard of Game Center cannot tell it is there.

Making it real is one job, and it cannot start until the app has a record
in App Store Connect: build an iOS plugin exposing `authenticate`,
`post_score` and `award_achievement` as an `Engine` singleton named
`GameCenter`, and the seam picks it up on its own.

## Leaderboards

| Id | Name | What it holds |
|---|---|---|
| `astroball.stars.total` | Total stars | 0 to 36 across The Drift. Sent on every level clear. |
| `astroball.level.01` … `.12` | Level 01 … 12 best | The run's score for that level. One board per level. |

Format: integer, higher is better. The per-level boards are sent the
score at the moment the level falls, not the total for the run.

## Achievements

Ten, all one-shot, all in the game's own voice. The trigger column is
where the game reports it, and every one of them is already wired.

| Id | Name | Earned by |
|---|---|---|
| `first_breach` | FIRST BREACH | Clearing level 1 |
| `chain_of_five` | CHAIN OF FIVE | A single chain taking five bricks |
| `clean_sweep` | CLEAN SWEEP | Clearing any level without losing the ball |
| `ahead_of_schedule` | AHEAD OF SCHEDULE | Clearing any level under its par time |
| `three_of_three` | THREE OF THREE | All three stars on one level |
| `patience` | PATIENCE | Clearing level 6, The Anvil |
| `one_hit` | ONE HIT | A single chain taking thirty bricks (level 9's ring) |
| `the_drift_cleared` | THE DRIFT CLEARED | Clearing level 12 |
| `constellation_charted` | CONSTELLATION CHARTED | Every level in The Drift cleared |
| `full_chart` | FULL CHART | All 36 stars |

Points: spread them as you like in App Store Connect; the game does not
know or care. Suggested split, hardest last: 5, 5, 10, 10, 10, 15, 15,
15, 25, 40.

## Descriptions for App Store Connect

Keep the tone of the game: short, dry, no exclamation marks.

- FIRST BREACH — The first field is open.
- CHAIN OF FIVE — One brick took four with it.
- CLEAN SWEEP — A field cleared without losing the ball.
- AHEAD OF SCHEDULE — A field cleared inside par.
- THREE OF THREE — Everything a single field has to give.
- PATIENCE — The Anvil is down.
- ONE HIT — Thirty bricks, one contact.
- THE DRIFT CLEARED — The last field of Universe 1.
- CONSTELLATION CHARTED — Every field in The Drift.
- FULL CHART — Thirty-six stars. Nothing left in Universe 1.
