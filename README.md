# NoahCLR's Homebrew Tap

```sh
brew install NoahCLR/tap/mac-tweaks
xattr -dr com.apple.quarantine "/Applications/Mac Tweaks.app"
```

The `xattr` line clears Gatekeeper quarantine — apps in this tap are signed but
not notarized. Alternatively, launch once and approve via System Settings →
Privacy & Security → **Open Anyway**.

| Cask | Description |
| --- | --- |
| [`bambucam`](https://github.com/NoahCLR/BambuCam) | Local-only Bambu Lab printer camera and status client for the menu bar |
| [`mac-tweaks`](https://github.com/NoahCLR/MacTweaks) | macOS menu bar utility with opt-in Finder and keyboard tweaks |

Maintainer docs: [docs/PUBLISHING.md](docs/PUBLISHING.md) — the full playbook for
publishing a new app through this tap.
