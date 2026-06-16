# FastRepo

A Spotlight-style launcher to jump to any GitHub **repo or org you can access** (owned, org, or collaborator) from anywhere on your Mac. Global hotkey, fuzzy search, opens in your browser.

Native macOS menu-bar app. No Electron, no dependencies.

## Why

GitHub scatters the repos you're a collaborator on across orgs and users, with no single view. FastRepo lists them all via one API call (`/user/repos?affiliation=owner,collaborator,organization_member`) plus your orgs, and lets you jump in two keystrokes, from any app.

## Use

- Global hotkey **⌃⌘G** → a floating search panel opens center-screen.
- Type to fuzzy-search repos + orgs · `↑/↓` move · `Return` open in browser · `Esc` close.
- Menu-bar Octocat → Search, Refresh, Set/Clear token, Quit.

## Token

FastRepo needs a classic GitHub **personal access token** with `repo` + `read:org`:
https://github.com/settings/tokens/new?scopes=repo,read:org&description=FastRepo

It's stored only in your **login Keychain** (service `com.solarbeam.FastRepo`), never on disk in plaintext, and sent only to `api.github.com`. If an org uses SAML SSO, authorize the token for it.

## Install

Download the latest signed, notarized build from [Releases](https://github.com/alexfrih/fastrepo/releases), unzip, and drop `FastRepo.app` into `/Applications`. It auto-updates from then on (see below).

## Build from source

Requires macOS 14+ and the Swift toolchain.

```bash
scripts/run.sh      # build (release) + assemble dist/FastRepo.app + launch
scripts/release.sh  # build + codesign (Developer ID) + notarize + staple
```

## Auto-update

FastRepo updates itself via [Sparkle](https://sparkle-project.org): it checks the update feed in the background and installs new versions in place. No manual re-download when a bug is fixed. You can also trigger it from the menu (**Check for Updates…**).

## Project layout

- `Sources/FastRepo/main.swift` — `NSApplication` (`.accessory`) + `AppDelegate`.
- `AppDelegate.swift` — status item, menus, panel lifecycle, hotkey, sync.
- `HotKey.swift` — global hotkey via Carbon `RegisterEventHotKey` (no Accessibility permission needed).
- `SearchPanel.swift` / `SearchView.swift` / `SearchVM.swift` — floating panel + SwiftUI UI.
- `GitHubClient.swift` — fetches `/user/orgs` + `/user/repos` (all affiliations), caches.
- `Keychain.swift`, `Models.swift` — token storage; item model, search, cache.

## License

MIT © Alexandre Frih. See [LICENSE](LICENSE).

The GitHub Octocat mark is a trademark of GitHub, Inc., used here for a personal tool. FastRepo is not affiliated with or endorsed by GitHub.
