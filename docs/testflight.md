# TestFlight

How to get a build to testers, and what to ask them.

## Before the archive

1. Close the Godot editor. It owns `project.godot` and
   `export_presets.cfg` while it runs and writes its own copy over
   anything changed on disk, without saying so.
2. Bump the build number in `export_presets.cfg`:
   `application/version` is the build (integer, must increase on every
   upload), `application/short_version` is what testers see.
   `config/version` in `project.godot` is kept in step by hand.
3. `./tests/run.sh`. All suites, zero failures, no console output.
4. `MIN_FREE_GB=3 ./tools/deploy.sh --release --build` to check the
   release configuration compiles. It signs with the development
   certificate, which is enough to prove the code and the export are
   sound.

## The archive

A TestFlight build is a *distribution* build, which needs a distribution
certificate and an App Store provisioning profile. Neither exists until
the app has a record in App Store Connect, so that comes first:

1. App Store Connect → Apps → **+** → New App. Bundle id
   `com.alius.astroball`, name Astro Ball, primary language English.
2. Xcode → Settings → Accounts → Manage Certificates → **+** → Apple
   Distribution.
3. `godot --headless --export-release "iOS" build/ios/AstroBall.xcodeproj`
   then open the project in Xcode.
4. Set the run destination to **Any iOS Device (arm64)**. An archive
   cannot be made against a simulator or a connected phone.
5. Product → Archive. It takes a while: the whole engine is compiled
   with optimisation on.
6. In the Organizer window that opens: Distribute App → App Store
   Connect → Upload.

Processing on Apple's side takes ten minutes to an hour. The build shows
up under TestFlight in App Store Connect when it is done.

## Export settings worth checking

| Setting | Value | Why |
|---|---|---|
| `application/bundle_identifier` | `com.alius.astroball` | Must match the App Store Connect record exactly |
| `application/app_store_team_id` | The team id | Empty here fails at signing with no useful message |
| `application/export_method_release` | 0 (App Store) | Anything else cannot be uploaded |
| `application/min_ios_version` | 15.0 | Covers everything back to the iPhone 6s |
| `application/targeted_device_family` | 2 (iPhone) | The game is portrait phone only |
| `storyboard/custom_image@2x` and `@3x` | `launch_blank.png` | Empty means the engine's own logo, robot and all |
| `boot_splash/show_image` | false | The engine's boot screen, off |

## Testing groups

- **Internal** — up to 100 people on the team, no review, available
  within minutes of processing. Use this for yourself and anyone who can
  take a broken build.
- **External** — up to 10,000, needs a Beta App Review on the first
  build of each version. Usually a day. Later builds of the same version
  go out without review.

For an external group: TestFlight → Testers and Groups → **+** → name it,
add the build, enable Public Link if you want to share it without
collecting email addresses first.

## What to ask testers for

Ask narrow questions. "Any feedback?" gets nothing back worth having.

1. **Does the paddle go where your thumb goes?** Any level, one minute.
   This is the whole game and it is the thing that is hardest to see
   from the inside.
2. **Did you understand what a capsule did before you caught it?** Which
   ones surprised you, good or bad.
3. **Where did you stop?** Not where you died — where you put the phone
   down. That is the level that needs work.
4. **Did anything look unfinished?** A screen that flashed, a word that
   made no sense, something that looked like a placeholder.
5. **Battery and heat** after ten minutes. A phone that gets warm is a
   frame budget problem, and it will not show up on a Mac.

Feedback comes back through TestFlight itself: screenshots, a note, and
the device and OS version attached. There is nothing to build for it, and
the game links nowhere.

## The first-launch line

A test build says so, once, on the first run:

    TEST BUILD. BREAK THINGS. REPORT.

It links nowhere on purpose. It is shown once per install and never
again, and it is behind `OS.is_debug_build()`, so it cannot reach a
release build even if the flag that tracks it is lost.
