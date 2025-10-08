#!/usr/bin/env zsh
set -euo pipefail

# Minimal force delete for AWS Secrets Manager
# Usage: force_delete_secrets.sh SECRET_ID [SECRET_ID ...]
# Uses AWS_PROFILE/AWS_REGION from environment if set.

if (( $# == 0 )); then
  echo "Usage: $0 SECRET_ID [SECRET_ID ...]" >&2
  exit 2
fi

PROFILE="${AWS_PROFILE:-}"
REGION="${AWS_REGION:-}"

# Build AWS CLI args
typeset -a AWS_ARGS
AWS_ARGS=()
[[ -n "$PROFILE" ]] && AWS_ARGS+=(--profile "$PROFILE")
[[ -n "$REGION"  ]] && AWS_ARGS+=(--region  "$REGION")

for sid in "$@"; do
  echo "[*] $sid"
  # Force delete; if it fails (e.g. scheduled for deletion or not found), try restore then force delete again.
  aws secretsmanager delete-secret --secret-id "$sid" --force-delete-without-recovery ${AWS_ARGS:+${AWS_ARGS[@]}} >/dev/null 2>&1 || {
    aws secretsmanager restore-secret --secret-id "$sid" ${AWS_ARGS:+${AWS_ARGS[@]}} >/dev/null 2>&1 || true
    aws secretsmanager delete-secret --secret-id "$sid" --force-delete-without-recovery ${AWS_ARGS:+${AWS_ARGS[@]}} >/dev/null 2>&1 || true
  }
  echo "[OK] done: $sid"
  echo
done
