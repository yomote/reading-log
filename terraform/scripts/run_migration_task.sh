#!/usr/bin/env bash
set -euo pipefail
# 目的: 専用のマイグレーション TaskDefinition (migrate) を 1 回実行して終了コードを返す。
# 必須: CLUSTER, MIGRATION_TASK_DEF(=family名 or ARN) もしくは TASK_DEF_ARN
# 片方未指定時の補完: SUBNETS, SECURITY_GROUPS が無い場合 SERVICE から引く
# 任意: REGION(us-east-2) ASSIGN_PUBLIC(自動取得 or DISABLED/ENABLED) INTERVAL(5) TIMEOUT(0=無制限)
# 使い方:
#   CLUSTER=reading-log-dev-cluster \
#   MIGRATION_TASK_DEF=reading-log-dev-migrate-task \
#   SERVICE=reading-log-dev-service \
#   ./scripts/run_migration_task.sh
# Help: -h/--help

[[ ${1:-} =~ ^(-h|--help)$ ]] && { grep '^# ' "$0" | sed 's/^# \?//'; exit 0; }

REGION=${REGION:-us-east-2}
INTERVAL=${INTERVAL:-5}
TIMEOUT=${TIMEOUT:-0}
: "${CLUSTER:?CLUSTER required}" || true
# 互換名
MIGRATION_TASK_DEF=${MIGRATION_TASK_DEF:-${TASK_DEF_ARN:-}}
: "${MIGRATION_TASK_DEF:?MIGRATION_TASK_DEF (or TASK_DEF_ARN) required}" || true

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
err() { log "ERROR: $*"; exit 1; }
need() { command -v "$1" >/dev/null || err "$1 required"; }
need aws; need jq

# ---- ネットワーク情報解決 ----
if [[ -z "${SUBNETS:-}" || -z "${SECURITY_GROUPS:-}" ]]; then
  : "${SERVICE:?SERVICE required when SUBNETS/SECURITY_GROUPS unset}" || true
  SVC_JSON=$(aws ecs describe-services --region "$REGION" --cluster "$CLUSTER" --services "$SERVICE" --query 'services[0]' --output json)
  [[ "$SVC_JSON" == null ]] && err "service not found"
  SUBNETS=$(jq -r '.networkConfiguration.awsvpcConfiguration.subnets | join(",")' <<<"$SVC_JSON")
  SECURITY_GROUPS=$(jq -r '.networkConfiguration.awsvpcConfiguration.securityGroups | join(",")' <<<"$SVC_JSON")
  ASSIGN_PUBLIC=${ASSIGN_PUBLIC:-$(jq -r '.networkConfiguration.awsvpcConfiguration.assignPublicIp' <<<"$SVC_JSON")}
else
  ASSIGN_PUBLIC=${ASSIGN_PUBLIC:-DISABLED}
fi
[[ -n "$SUBNETS" && -n "$SECURITY_GROUPS" ]] || err "network resolution failed"

# 形式整形 (subnet-1,subnet-2 → [subnet-1,subnet-2])
_sub="[${SUBNETS//,/ ,}]"; _sub=${_sub// ,/,}
_sg="[${SECURITY_GROUPS//,/ ,}]"; _sg=${_sg// ,/,}
NETWORK_CFG="awsvpcConfiguration={subnets=${_sub},securityGroups=${_sg},assignPublicIp=${ASSIGN_PUBLIC}}"

# ---- タスク起動 ----
log "START cluster=$CLUSTER taskDef=$MIGRATION_TASK_DEF subnets=$SUBNETS sgs=$SECURITY_GROUPS"
FULL=$(aws ecs run-task --region "$REGION" --cluster "$CLUSTER" --launch-type FARGATE \
  --task-definition "$MIGRATION_TASK_DEF" --network-configuration "$NETWORK_CFG" --output json)
FAIL=$(jq -r '.failures[]? | "\(.arn) \(.reason)"' <<<"$FULL")
[[ -n "$FAIL" ]] && err "run-task failures: $FAIL"
TASK_ARN=$(jq -r '.tasks[0].taskArn' <<<"$FULL")
[[ "$TASK_ARN" == null ]] && err "no task started"
TASK_ID=${TASK_ARN##*/}
log "[1] started task=$TASK_ID"

# ---- 停止待ち ----
START_TS=$(date +%s)
STATUS=$(jq -r '.tasks[0].lastStatus' <<<"$FULL")
while [[ "$STATUS" != STOPPED ]]; do
  log "[2] status=$STATUS"
  sleep "$INTERVAL"
  DESCRIBE=$(aws ecs describe-tasks --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN" --query 'tasks[0]' --output json)
  STATUS=$(jq -r '.lastStatus' <<<"$DESCRIBE")
  if (( TIMEOUT > 0 )); then
    NOW=$(date +%s); (( NOW - START_TS > TIMEOUT )) && err "timeout ${TIMEOUT}s"
  fi
done
log "[2] status=STOPPED"

EXIT_CODE=$(jq -r '.containers[0].exitCode' <<<"$DESCRIBE")
STOP_REASON=$(jq -r '.stoppedReason' <<<"$DESCRIBE")
log "[3] done task=$TASK_ID exitCode=$EXIT_CODE reason=$STOP_REASON"
[[ "$EXIT_CODE" == 0 ]] || exit "$EXIT_CODE"
