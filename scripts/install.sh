#!/usr/bin/env bash
# Install (or refresh) the care agentic workflow pack into a consumer repo.
#
# Usage:
#   ./scripts/install.sh --target ../care_fe [--ref v1.0.0] [--repo ohcnetwork/care-agentic-workflows]
#
# What it does:
#   1. `gh aw add <repo>/workflows/<name>@<ref>` for every agentic workflow source
#      (creates the thin .md stub with its `source:` pin and the compiled .lock.yml).
#   2. Copies the deterministic glue workflows (glue/*.yml) into .github/workflows/.
#   3. Copies runner-files/ into .github/runner-files/.
#   4. Copies docs/QA_STATE_MACHINE.md into .github/.
#   5. Seeds the `state:*` + `jira-agent` labels (scripts/seed-state-labels.sh).
#   6. Prints the secrets/vars the consumer must configure.
#
# Idempotent: re-running refreshes stubs/locks and overwrites copied files.

set -euo pipefail

SOURCE_REPO="ohcnetwork/care-agentic-workflows"
REF="main"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --repo) SOURCE_REPO="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$TARGET" ] || { echo "--target <consumer repo path> is required" >&2; exit 2; }
[ -d "$TARGET/.git" ] || { echo "$TARGET is not a git repo" >&2; exit 2; }
command -v gh >/dev/null || { echo "gh CLI required" >&2; exit 2; }
gh extension list | grep -q 'github/gh-aw' || { echo "gh-aw extension required: gh extension install github/gh-aw" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")/.." && pwd)"

# Agentic workflows to install. Keep in sync with workflows/*.md (shared/ fragments
# are imported cross-repo, never installed directly).
WORKFLOWS=(
  jira-pr-author
  pr-reviewer
  pr-fix
  pr-rework
  pr-qa-playwright
  qa-watchdog
  ci-doctor
  needs-human-triage
  daily-repo-status
  daily-playwright-improver
  multi-device-docs-tester
  thank-you-note
)

echo "==> Installing ${#WORKFLOWS[@]} agentic workflows from $SOURCE_REPO@$REF into $TARGET"
for wf in "${WORKFLOWS[@]}"; do
  echo "--- gh aw add $wf"
  (cd "$TARGET" && gh aw add "$SOURCE_REPO/workflows/$wf@$REF" --force)
done

echo "==> Copying deterministic glue workflows"
mkdir -p "$TARGET/.github/workflows"
cp -v "$HERE"/glue/*.yml "$TARGET/.github/workflows/"

echo "==> Copying runner files"
mkdir -p "$TARGET/.github/runner-files"
cp -v "$HERE"/runner-files/* "$TARGET/.github/runner-files/"

echo "==> Copying state machine doc"
cp -v "$HERE/docs/QA_STATE_MACHINE.md" "$TARGET/.github/QA_STATE_MACHINE.md"

echo "==> Seeding labels"
TARGET_SLUG="$(cd "$TARGET" && gh repo view --json nameWithOwner --jq .nameWithOwner)"
bash "$HERE/scripts/seed-state-labels.sh" "$TARGET_SLUG" || echo "(label seeding failed — run scripts/seed-state-labels.sh manually)"

cat <<EOF

==> Done. Now configure in $TARGET_SLUG (Settings → Secrets and variables → Actions):

  Variable  CARE_AW_APP_ID            GitHub App id (App installed on the repo with
                                      contents:rw, pull-requests:rw, issues:rw)
  Secret    CARE_AW_APP_PRIVATE_KEY   the App's private key (PEM)
  Secret    JIRA_* / others           whatever the jira-pr-author workflow expects
  (Optional) Secret GH_AW_AGENT_TOKEN legacy write-access PAT; only needed if the
                                      Copilot coding agent ignores App-authored
                                      @copilot mentions (see shared/request-rework.md)

Then commit the changes in $TARGET and push.
Update later with: cd $TARGET && gh aw update
EOF
