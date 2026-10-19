# Pigeonhole

A pigeonhole cabinet is the wall of wooden slots an old mailroom sorted
letters into. Pigeonhole does the same with your GitHub pull requests, from
the menu bar.

![The board, sorting PRs into In progress, In review and Needs action](docs/screenshots/board-mailroom.png)

## What it does

- **Three slots.** In progress holds your drafts. In review holds PRs waiting
  on reviewers. Needs action holds anything waiting on you: changes
  requested, unresolved comments, failing CI, or approved and ready to merge.
- **Reviews tab** for PRs where your review was requested.
- **Every org at once.** Filter by owner (All, Personal, or one org) and by
  your own tags.
- **Tags** for repos you care about, with a name and color, shown on every
  card. Filter by a tag or by Untagged.
- **Click a card** to open the PR in your browser and copy its branch name.
  **⌥⌘P** (changeable) shows or hides the board from anywhere.
- **Keyboard driven.** Arrow keys move between cards, Return opens one, C
  copies its branch, Tab (or 1 and 2) switches tabs, R refreshes, Escape
  closes.
- **Activity window.** By default only PRs with activity in the last 30 days
  show. You can pick 14, 60 or 90 days, a year, or everything.
- Six themes, two light and four dark, plus six font pairs and three text
  sizes.

![The Walnut theme](docs/screenshots/board-walnut.png)

![Reviews waiting on you](docs/screenshots/reviews.png)

<p>
  <img src="docs/screenshots/settings-appearance.png" width="49%" alt="Appearance settings with six themes and font presets">
  <img src="docs/screenshots/settings-tags.png" width="49%" alt="Tag editor with color swatches and a repo picker">
</p>

It's read-only. It borrows the GitHub CLI's login, so there's no token to
create, nothing goes in the Keychain, and one login covers every org you've
authorized `gh` for. It only ever talks to `api.github.com`.

## Requirements

- macOS 14 or later
- A Swift toolchain. The Command Line Tools are enough:
  `xcode-select --install`
- The [GitHub CLI](https://cli.github.com), signed in:
  `brew install gh && gh auth login`

## Install

```sh
git clone https://github.com/Silas-N-Schlax/pigeonhole.git
cd pigeonhole
Scripts/create-signing-cert.sh   # optional, once per machine, asks for your password
Scripts/build-app.sh             # builds, installs to /Applications, opens it
```

Look for the cubbies in your menu bar. Left click opens the board; right
click has Refresh, Settings and Quit. To update later, `git pull` and run
`Scripts/build-app.sh` again.

The signing certificate gives every build the same signature, which keeps
"Open at login" pointing at the right app across rebuilds. Without it the
build falls back to ad-hoc signing and still works.

## Missing PRs from an org?

That org probably restricts OAuth apps or uses SAML single sign-on. Run
`gh auth refresh`, or authorize the GitHub CLI for that org on github.com.
The rest of the board keeps working either way.

## Development

```sh
swift build                                       # debug build
swift run PigeonholeChecks                        # logic checks
swift run PigeonholeSnapshots docs/screenshots    # regenerate these screenshots
```

The screenshots are rendered from made-up sample data, never real PRs.
