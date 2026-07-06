# Publishing a Mac App via This Tap

Step-by-step playbook for taking a local macOS app repo public and distributing it
through this Homebrew tap (`NoahCLR/homebrew-tap`). Written as context for coding
agents doing the work; follow it top to bottom for a first publish, or jump to
[Subsequent releases](#subsequent-releases) for an app that is already published.

Generic script templates live in [`templates/`](../templates/) in this repo —
copy them into the app repo and fill the placeholders. When in doubt about a
step, also `diff` against the `Scripts/` of the most recently published app:
live scripts are battle-tested, templates are not (see policy 7).

## Parameters

Resolve these before starting; every step and template placeholder below is
written against them.

| Parameter | Meaning | Example |
| --- | --- | --- |
| `APP_NAME` | Display name, as the `.app` bundle is named | `My App` |
| `ARTIFACT_PREFIX` | Release zip prefix, no spaces | `MyApp` |
| `GITHUB_REPO` | Public source repo | `NoahCLR/MyApp` |
| `BUNDLE_ID` | Main app bundle identifier | `com.noah.MyApp` |
| `CASK_TOKEN` | Cask name: lowercase, hyphenated | `my-app` |
| `MIN_MACOS` | Deployment target, as a brew symbol | `:sonoma` (14) |
| `ZAP_PATHS` | Files the app writes that `brew zap` should trash | preference plists |

The tap itself is fixed: `NoahCLR/homebrew-tap`, casks in `Casks/`, installs via
`brew install NoahCLR/tap/CASK_TOKEN`.

## Standing policies

These were decided deliberately; do not relitigate them per project.

1. **Identity allowlist.** The following are fine to appear in public repos,
   commits, and metadata: the owner's full name (Noah Christian Le Roy), the
   git author email already used on public commits (noahleroy@gmail.com), and
   the GitHub handle (NoahCLR). **Everything else is a blocker**: employer- or
   client-related identifiers, other people's names or emails, credentials,
   tokens, API keys, absolute home paths, and Apple team IDs in tracked files.
2. **Certificate email.** An Apple Development certificate embeds its Apple ID
   email in every app it signs (`codesign -dvv` reveals it). Rule: sign with
   the neutral self-signed local identity — `signing-common.sh` defaults to it
   and creates it on first use; an Apple Development certificate must be
   explicitly requested via the `APP_SIGNING_IDENTITY` env var and should not
   be. Gatekeeper treats unnotarized apps identically regardless of
   certificate, so the neutral identity costs nothing. For an app that already
   shipped with a different identity, switching resets every user's
   Accessibility/Input Monitoring grants — do it as early as possible or not
   at all.
3. **First-publish squash.** Every first publish squashes history to a single
   `v1.0.0` commit. Pre-publish history is assumed to be working noise and a
   leak surface; do not push it.
4. **Agent docs stay local.** `CLAUDE.md` and `AGENTS.md` are always gitignored
   and never published. Public contributor docs, if wanted, are a separate
   `CONTRIBUTING.md`.
5. **Releases are built locally, never in CI.** The signing certificate lives
   only in the owner's login keychain. CI would sign ad-hoc, which changes the
   code-signing identity every build and resets users' permission grants on
   every update. A stable identity is the entire mechanism by which
   `brew upgrade` preserves TCC permissions.
6. **Publishing is gated on the owner.** Creating public repos, pushing, and
   creating releases are outward-facing; an agent following this doc should
   confirm with the owner before the first push of a new project (steps up to
   and including the squash are local and reversible).
7. **Template backport rule.** The templates in `templates/` never execute, so
   they only stay correct if fixes flow back. Any bug found in a live
   project's copy of these scripts is backported to the templates in the same
   sitting. When adopting templates into a new project, first `diff` them
   against the most recently published app's `Scripts/` to catch anything not
   yet backported.

## Phase 0 — pre-publish sanity sweep

Run from the app repo root. Every check must pass (or the finding must be
explicitly approved by the owner) before anything is pushed.

```sh
# 0. You are on the right GitHub account
gh auth status            # active account must be NoahCLR

# 1. What would actually be published
git ls-files              # review the full list; nothing unexpected

# 2. No build artifacts or user state tracked
git ls-files | grep -iE 'build/|DerivedData|xcuserdata|\.DS_Store' && echo FAIL || echo OK

# 3. .gitignore covers the basics
cat .gitignore            # expect: build dirs, DerivedData, xcuserdata, .DS_Store,
                          # CLAUDE.md, AGENTS.md

# 4. Personal data in tracked files (allowlist: owner name, gmail, handle)
git grep -inE '@[a-z0-9.-]+\.(com|nl|io|dev)|/Users/' -- . | grep -vi "BUNDLE_ID prefix"
# every hit must be on the allowlist; work/client identifiers are hard blockers

# 5. No Apple team IDs or provisioning references in the project file
#    (empty assignments like PROVISIONING_PROFILE_SPECIFIER = "" are fine)
git grep -nE 'DEVELOPMENT_TEAM = [A-Z0-9]|PROVISIONING_PROFILE_SPECIFIER = "[^"]|TeamIdentifier' && echo FAIL || echo OK

# 6. Secret-shaped strings anywhere in history (pre-squash tree included)
git log --all -p | grep -inE 'password|secret|token|api[_-]?key|BEGIN (RSA|EC|OPENSSH)' | head

# 7. Tests pass on the exact tree being published
xcodebuild -project <Project>.xcodeproj -scheme <Scheme> -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Also verify the human-facing basics: `README.md` is user-facing (see Phase 1),
`LICENSE` exists, and the copyright string in the app's `Info.plist` uses the
owner's full name.

## Phase 1 — repo preparation

1. **LICENSE**: MIT, `Copyright (c) <year> Noah Christian Le Roy` (standing
   default; only deviate if the owner asks).
2. **Versions**: set `CFBundleShortVersionString` to `1.0.0` (full semver, not
   `1.0`) in **every** target's Info.plist (app + any extensions). The release
   script derives the tag from the main app's value.
3. **README shape** (top to bottom): what the app does → Install via Homebrew
   (see Gatekeeper note below) → build-from-source alternative → first-run
   setup (every permission/System Settings toggle the app needs, one at a
   time) → development docs → license. Screenshots optional, never blocking.
4. **Gitignore** `CLAUDE.md` and `AGENTS.md` (policy 4).
5. **Copy the release tooling** from this repo's `templates/` into the app
   repo's `Scripts/`, fill every `{{PLACEHOLDER}}` (each template's header
   lists its own), `chmod +x`, and `zsh -n` each script. Then apply policy 7:
   `diff` against the most recently published app's `Scripts/` for
   not-yet-backported fixes. `install-local.sh` is optional but recommended;
   delete the appex-signing/registration blocks for apps without extensions.

Cask template rules learned the hard way:
- `depends_on macos:` takes a bare symbol (`:sonoma`), **not** a comparison
  string — the string form is deprecated and warns on every brew command.
- `ZAP_PATHS` must list specific files, never a whole `Application Support`
  directory: on the dev machine that directory can contain the self-signed
  signing key, and `brew zap` would delete it.
- Run `brew style --cask NoahCLR/tap/CASK_TOKEN` after the cask lands; it must
  report no offenses.

## Phase 2 — squash and publish the source repo

Confirm with the owner, then:

```sh
git checkout --orphan release
git rm -r --cached -q -f .
git add -A                          # respects the updated .gitignore
git ls-files | grep -E 'CLAUDE|AGENTS' && echo FAIL   # must print nothing
git commit -m "APP_NAME v1.0.0"     # single public commit
git branch -M main
git tag v1.0.0
gh repo create <name> --public --source . --push --description "..."
git push origin v1.0.0
```

## Phase 3 — first release

```sh
./Scripts/release.sh
```

The script (from `templates/release.sh`) refuses a dirty tree, runs
the tests, builds Release, signs with the stable identity, zips with
`ditto -c -k --sequesterRsrc --keepParent`, pushes the tag, creates the GitHub
release with the zip attached, then clones this tap fresh into a temp dir,
rewrites `Casks/CASK_TOKEN.rb` with the new version + sha256, and pushes.
There is no manual cask-editing step in the happy path.

## Phase 4 — verify end to end

Never declare success without this. On the dev machine:

```sh
brew tap noahclr/tap                       # first time only
brew install CASK_TOKEN                    # if a non-brew copy exists in /Applications:
                                           # quit the app, rm -rf it, then install
xattr -dr com.apple.quarantine "/Applications/APP_NAME.app"
codesign --verify --deep --strict "/Applications/APP_NAME.app"
open "/Applications/APP_NAME.app" && sleep 3 && pgrep -x "APP_NAME"
brew style --cask noahclr/tap/CASK_TOKEN
```

Replacing a locally-installed copy with the brew copy is safe **only** because
both are signed with the same identity — permission grants survive.

### Gatekeeper reality (as of Homebrew 6 / macOS 15+)

- Apps here are signed but **not notarized** (no paid Apple Developer account),
  so Gatekeeper blocks the first launch of any quarantined copy — including
  after every `brew upgrade`.
- Homebrew 6 **removed** `--no-quarantine`; do not document it.
- macOS 15+ removed the right-click → Open bypass. The two working options,
  which README, cask caveats, and release notes must all state:
  `xattr -dr com.apple.quarantine "/Applications/APP_NAME.app"`, or launch
  once → System Settings → Privacy & Security → **Open Anyway**.

## Subsequent releases

1. Bump `CFBundleShortVersionString` in every Info.plist (semver).
2. Commit; tree must be clean.
3. `./Scripts/release.sh` — it does everything, including updating this tap.
4. Spot-check: `brew update && brew upgrade CASK_TOKEN` on the dev machine, then
   re-apply the `xattr` clear.

## Failure modes seen in practice

| Symptom | Cause / fix |
| --- | --- |
| Permissions reset after update | Signing identity changed. Keep one stable cert per app, forever. |
| `brew install` refuses: "already an App" | A non-brew copy is in `/Applications`. Quit, delete, reinstall via brew. |
| Deprecation warning on every brew command | Cask uses string form of `depends_on macos:`. Use the symbol. |
| App blocked at launch after upgrade | Expected (quarantine re-applied). `xattr -dr` again or Open Anyway. |
| `release.sh` exits "Release already exists" | Version wasn't bumped; bump `CFBundleShortVersionString`. |
