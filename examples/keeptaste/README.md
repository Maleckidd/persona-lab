# KeepTaste: the configs persona-lab was built on

A snapshot, not a working copy. These four directories are `persona-lab/config*`
from [KeepTaste](https://github.com/Maleckidd/KeepTaste), a recipe manager for
Android, as of commit `d828466` (2026-11-14). The working configs stay in that
repository, next to the `history/` and `runs/` of its studies. They are here to
show what a real config looks like: hooks, start states, a focused study, a
research-team study and a calibration build.

They do not run from this repository, because they call into the app's own:

- `scripts/reset-demo-library.sh`, `scripts/lib/screen.sh` and
  `assets/store/keeptaste-demo*.zip` for the `demo` start state,
- `node_modules`, for `config-research/scrub-comments.js`,
- the app's sources and Gradle build, for `config-seeded/build.sh` and
  `seeded.patch`,
- `persona-lab/runs/seeded/app-seeded.apk`, which that build writes.

Two lines differ from the original: `APP_REPO` in `config/config.sh` and `REPO`
in `config-seeded/build.sh` take the app's repository from the environment
instead of from where the file is.

Paths below are relative to this directory; commands are run from the app's
repository, where the same directories are under `persona-lab/`.

## The personas and their materials are invented

The people in every `personas.json` and everything they are handed as their
own were written for these studies: the blog page, the Instagram caption and
its `@sophie.cooks.at.home` handle and the message from a mother in
`config-import/clipboard/`, and the grandmother's recipe card and the cookbook
page in `config-import/photos/`, which are rendered from the `*.html` next to
them. Any likeness to a real person, account or blog is a coincidence.

The exception is four recipe pages the import and research studies link to,
which are real and public: one on `kwestiasmaku.com` and three on
`doradcasmaku.pl` (`config-import/clipboard/url-*.txt`, `SHARE_URL` in
`config-import/config.sh`, and the materials of four personas). Only their
addresses are here; the app fetches the pages during a run.

## What is in the config

- `config/brief.md` (PL) and `config/brief.en.md` are the **Play Store
  listing** text (short + full description, version B from
  `assets/store/play-store-listing.md`) — what a user reads before installing.
  Edit them freely; personas get the one in their language.
- Start states: `fresh` (`pm clear` + per-app locale) and `demo` (the curated
  demo library via `scripts/reset-demo-library.sh`, which needs
  `assets/store/keeptaste-demo*.zip` and the coordinates in `scripts/lib/screen.sh`).
- The app UI language follows the persona's language via
  `cmd locale set-app-locales`.
- `capture_state` in `config/config.sh` reads the end state through the UI,
  because the release build is not debuggable: a cold start into "all recipes"
  by deep link (`keeptaste://cookbook/all`), the full text of the three most
  recently changed recipes, the recipe titles, every cookbook on the home
  screen with the recipes in it, the shopping lists and the first list. It
  taps recipe cards, cookbook tiles, list rows and Back, nothing else. It finds
  cards and tiles by shape (the only tall tappable elements on the recipe
  list; tappable squares half the screen wide on the home screen), so a
  redesign of either screen needs a look at it. The "new cookbook" tile has
  the shape of a cookbook and is skipped by its label (`CAPTURE_SKIP_TILES`),
  which has to follow `home.newCookbook` in `i18n/dictionary.ts`.
  Lists are read as card titles only, the first `CAPTURE_TITLES` (12) of each,
  so that two reads of the same list come out the same. The search field of
  "all recipes" takes focus by itself and brings the keyboard up over the
  lower cards; the hook closes it (`keyboard_hide`) before every tap and
  scroll there. Before that a tap on the third card typed a letter into the
  search, and a scroll glide-typed a word.
- `config-import/personas.json` has `expect` patterns for every import path
  (the recipe is there, ingredients have their own section, the mother's
  private notes are gone, no hashtags), so that study's outcomes no longer
  depend on what the persona thinks it saved.
- `config-seeded/` is the calibration run. `seeded.patch` plants six defects
  (no confirmation after saving, a PDF share action called "Export", an error
  that only says "Error.", no add button inside a cookbook, an empty search
  that claims there are no recipes, an import button called "More");
  `seeded.json` lists them for the scorer. The patch is never left in the
  working tree:

  ```bash
  bash persona-lab/config-seeded/build.sh     # apply → gradlew assembleRelease → take it back out
  bash "$PERSONA_LAB_ENGINE/run.sh" persona-lab/config-seeded \
    --seeded persona-lab/config-seeded/seeded.json
  ```

  The run installs the seeded APK over the app on the emulator; build and
  install a normal one afterwards. When the patch stops applying, the code has
  moved: plant the defects again and save them with `git diff`.
- `config/calibration/real-testers.md` — the 5 external testers' feedback goes
  here; the synthesis then adds a "Kalibracja" section (what the personas caught,
  missed, recall).
