# care-agentic-workflows

Canonical source repo for the Jira → PR agentic workflow system (gh-aw) used by
`care_fe` (and future repos). Workflow **sources** live here; consuming
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

Workflows use a fine-grained **PAT** (`GH_AW_AGENT_TOKEN`) for all writes that
must cascade past GitHub's recursion guard (state labels, review verdicts,
`@copilot` rework comments). The PAT must belong to a user with write access and
be scoped to the consumer repo with contents:rw, pull-requests:rw, issues:rw.

Required consumer configuration:

- Secret `GH_AW_AGENT_TOKEN` — the fine-grained PAT
- Everything falls back to the default `GITHUB_TOKEN` when unset (workflows still
  run, but downstream label-triggered workflows will NOT fire and the `@copilot`
  hand-back will be ignored).

A GitHub App can replace the PAT later (short-lived installation tokens, bot
attribution) by switching `github-token:` entries to a `github-app:` block —
see the gh-aw docs.

## Releasing

Tag a release (`vX.Y.Z`). `.github/workflows/release.yml` opens a `gh aw update`
PR against each registered consumer repo. Consumers also run
`glue/gh-aw-drift-check.yml` to fail CI if a `.lock.yml` was hot-edited out of
sync with its pinned source.
