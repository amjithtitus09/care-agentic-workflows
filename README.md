# care-agentic-workflows

Canonical source repo for the Jira → PR agentic workflow system (gh-aw) used by
`care_fe` (and future ohcnetwork repos). Workflow **sources** live here; consuming
repos carry only thin `.md` stubs (with `source:` pins) plus compiled `.lock.yml`
artifacts, installed and refreshed via `gh aw`.

## Layout

```
workflows/          gh-aw agentic workflow sources (.md)
workflows/shared/   importable shared fragments (cross-repo imports)
glue/               deterministic (non-agentic) Actions YAML, copied into consumers
runner-files/       files referenced by workflows at runtime (copied into consumers)
scripts/            install.sh (one-command consumer install), seed-state-labels.sh
docs/               QA_STATE_MACHINE.md, architecture notes
```

## Installing into a consumer repo

```bash
./scripts/install.sh --target ../care_fe --ref v1.0.0
```

This wraps `gh aw add` for every workflow, copies `glue/` + `runner-files/` +
`scripts/seed-state-labels.sh`, seeds the `state:*` labels, and prints the
secrets/vars that must be configured (see below).

Updating an already-installed consumer: `gh aw update` (or wait for the release
automation PR).

## Tokens

Workflows use a **GitHub App** (not a PAT) for all writes that must cascade past
GitHub's recursion guard (state labels, review verdicts, `@copilot` rework
comments). See `workflows/shared/app-token.md` and `docs/TOKENS.md`.

Required consumer configuration:

- Variable `CARE_AW_APP_ID` — the GitHub App id
- Secret `CARE_AW_APP_PRIVATE_KEY` — the App private key (PEM)

## Releasing

Tag a release (`vX.Y.Z`). `.github/workflows/release.yml` opens a `gh aw update`
PR against each registered consumer repo. Consumers also run
`glue/gh-aw-drift-check.yml` to fail CI if a `.lock.yml` was hot-edited out of
sync with its pinned source.
