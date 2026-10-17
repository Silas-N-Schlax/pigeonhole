# Pigeonhole

Menu-bar-only macOS app (SwiftUI + Swift Package Manager, `LSUIElement`, no
Dock icon) that sorts your open and draft GitHub PRs into three slots (In
progress, In review, Needs action), plus a Reviews tab for PRs waiting on
your review. Read-only: it never writes to GitHub. See `znotes/design.md`
for the design reference and the live mockup link. Pull from it when
building any feature so the build matches what was designed.

`CLAUDE.md` is a one-line pointer to this file, so Claude Code and other
agent tooling read the same instructions.

Never build the app bundle, sign, install, or launch the app without the
user's explicit permission: no `Scripts/build-app.sh`, no `open`. Plain
`swift build` and `swift run PigeonholeChecks` are fine on their own.

## Commands

```sh
swift build                       # debug build
swift run PigeonholeChecks        # the checks; exits non-zero on failure
swift run PigeonholeSnapshots docs/screenshots   # README screenshots, sample data
Scripts/build-app.sh              # release build, signed .app, installs it
Scripts/create-signing-cert.sh    # once per machine; see README
```

There is no linter.

## Layout

Four targets in one SwiftPM package (`Package.swift`, Swift 5 language mode):

- `PigeonholeCore`: models, GitHub client, storage, themes, and the SwiftUI
  views under `Views/`.
- `Pigeonhole`: the executable. `AppDelegate.swift` builds the status item,
  the borderless board window and the Settings window by hand, not a SwiftUI
  `App`. It owns the one `AppState`.
- `PigeonholeChecks`: an executable, not a test target. The Command Line
  Tools ship neither XCTest nor swift-testing. One `check("case") { }` per
  behavior, `expect(_:_:)` for assertions.
- `PigeonholeSnapshots`: renders the README screenshots from made-up data
  through real windows. Rerun it after any visible change.

## Architecture

**`AppState`** (`@MainActor @Observable`) is the single store. Views read it
from the environment and call its methods; nothing else touches GitHub or
the disk. The production init borrows `gh auth token`; the internal init
takes a `connect` closure, `UserDefaults` and a `TagStore`, which the checks
use with a fake client.

**`GitHubClient`** is the protocol for every call the app makes. `GitHubAPI`
sends one GraphQL request per refresh (`Queries.board`) and one for the tag
picker's repo list (`Queries.repos`). `GraphQL.decode` keeps partial data
when GitHub also returns errors, so one SSO-blocked org can't blank the
board.

**`Status`** decides which slot a PR lands in and what its chip says. Keep
it a small pure type so the rules stay checkable.

**`Theme`** and **`Typography`** are handed down by `ThemedRoot` through the
environment. Views read `theme.card`, `type.ui(13, .semibold)` and never
pick a color or face themselves. Tags store a palette slot, not a color.

Every tunable number (window size, refresh interval, query limits) lives in
`AppConfig.swift`. Check there before hardcoding a number.

Use Object-Oriented principles rather than creating God-classes.

## Comments

Comments explain *why* a thing is the way it is, not what the code does;
limit to 80 characters unless there's a really good justification.
