# Script templates

Canonical, generic versions of the scripts a published app needs. Copy them
into the app repo's `Scripts/` directory and replace every `{{PLACEHOLDER}}`
(they're all listed in the parameter table of [docs/PUBLISHING.md](../PUBLISHING.md)).
The placeholders make the templates non-runnable on purpose — a missed one
fails loudly.

| Template | Purpose |
| --- | --- |
| `signing-common.sh` | Creates/reuses a stable, neutral self-signed signing identity; signs app bundles. Sourced by the other two. |
| `release.sh` | Full release: tests → Release build → sign → zip → GitHub release → rewrite the cask in this tap. |
| `install-local.sh` | Build, sign, and install to `/Applications` for local development. |

**Backport rule:** these templates never execute, so they only stay correct if
fixes flow back. Any bug found in a live project's copy of these scripts must
be backported here in the same sitting. Likewise, when adopting the templates
into a new project, first `diff` them against the most recently published
app's `Scripts/` to catch anything not yet backported.
