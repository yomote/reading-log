#!/usr/bin/env zsh
set -euo pipefail

# Cleanup & Destroy Orchestrator for reading-log (dev)
# Requires: aws, jq, terraform, zsh
# Usage examples:
#   ./terraform/scripts/cleanup_destroy.sh -y \
#     --profile dev-admin --region us-east-2 \
#     --root-domain example.com --app-fqdn app.example.com \
#     --repo-name reading-log-dev --image-tag v1.0.3 \
#     --hosted-zone-id Z0123456789ABCDE \
#     --cert-arn arn:aws:acm:us-east-2:ACCOUNT_ID:certificate/UUID \
#     --tf-state-bucket reading-log-tf-state --tf-lock-table terraform-locks
#
# Flags:
#   -y | --yes                 Non-interactive (auto approve)
#   --profile PROFILE          AWS profile (propagated to AWS CLI)
#   --region REGION            AWS region (default from $AWS_REGION or us-east-2)
#   --root-domain DOMAIN       Root domain for Route53 zone (e.g., example.com)
#   --app-fqdn FQDN            App FQDN (e.g., app.example.com)
#   --repo-name NAME           ECR repo name for live/dev (e.g., reading-log-dev)
#   --image-tag TAG            Image tag used at apply (e.g., v1.0.3)
#   --hosted-zone-id ZONE_ID   Hosted zone ID
#   --cert-arn ARN             ACM certificate ARN
#   --tf-state-bucket BUCKET   S3 bucket for Terraform state (delete last)
#   --tf-lock-table TABLE      DynamoDB lock table name (delete last)
#   --skip-app|--skip-acm|--skip-ecr|--skip-dns|--skip-state  Skip steps
#   --verify                 Only verify what's left (no destroy)
#   --vpc-id VPC_ID          Target VPC ID used for verify checks (optional)
#   --vpc-tag-name NAME      Tag filter for VPC Name used for verify (default: main)
#   --vpc-tag-env ENV        Tag filter for VPC Env used for verify (default: dev)
#
# Env fallbacks: AWS_PROFILE, AWS_REGION, ROOT_DOMAIN, APP_FQDN, REPO_NAME,
# IMAGE_TAG, HOSTED_ZONE_ID, CERT_ARN, TF_STATE_BUCKET, TF_LOCK_TABLE

# ------------- utils -------------
log() { printf '%s\n' "$*" >&2; }
info() { log "[INFO] $*"; }
warn() { log "[WARN] $*"; }
err() { log "[ERROR] $*"; exit 1; }
need() { command -v "$1" >/dev/null || err "$1 is required"; }
confirm() { [[ "$ASSUME_YES" == 1 ]] && return 0; read -r '?Proceed? [y/N] ' yn; [[ "$yn" == [yY]* ]]; }

need aws; need jq; need terraform

# ------------- args -------------
ASSUME_YES=0
AWS_PROFILE_ARG=()
AWS_REGION=${AWS_REGION:-us-east-2}
ROOT_DOMAIN=${ROOT_DOMAIN:-}
APP_FQDN=${APP_FQDN:-}
REPO_NAME=${REPO_NAME:-}
IMAGE_TAG=${IMAGE_TAG:-}
HOSTED_ZONE_ID=${HOSTED_ZONE_ID:-}
CERT_ARN=${CERT_ARN:-}
TF_STATE_BUCKET=${TF_STATE_BUCKET:-}
TF_LOCK_TABLE=${TF_LOCK_TABLE:-}

SKIP_APP=0
SKIP_ACM=0
SKIP_ECR=0
SKIP_DNS=0
SKIP_STATE=0
VERIFY_ONLY=0
VPC_TAG_NAME=${VPC_TAG_NAME:-main}
VPC_TAG_ENV=${VPC_TAG_ENV:-dev}
VPC_ID=${VPC_ID:-}


while (( $# > 0 )); do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    --profile) shift; [[ -n "${1:-}" ]] || err "--profile requires value"; export AWS_PROFILE="$1"; AWS_PROFILE_ARG=(--profile "$1") ;;
    --region) shift; [[ -n "${1:-}" ]] || err "--region requires value"; AWS_REGION="$1" ;;
    --root-domain) shift; ROOT_DOMAIN="${1:-}" ;;
    --app-fqdn) shift; APP_FQDN="${1:-}" ;;
    --repo-name) shift; REPO_NAME="${1:-}" ;;
    --image-tag) shift; IMAGE_TAG="${1:-}" ;;
    --hosted-zone-id) shift; HOSTED_ZONE_ID="${1:-}" ;;
    --cert-arn) shift; CERT_ARN="${1:-}" ;;
    --tf-state-bucket) shift; TF_STATE_BUCKET="${1:-}" ;;
    --tf-lock-table) shift; TF_LOCK_TABLE="${1:-}" ;;
    --skip-app) SKIP_APP=1 ;;
    --skip-acm) SKIP_ACM=1 ;;
    --skip-ecr) SKIP_ECR=1 ;;
    --skip-dns) SKIP_DNS=1 ;;
    --skip-state) SKIP_STATE=1 ;;
  --verify) VERIFY_ONLY=1 ;;
  --vpc-id) shift; VPC_ID="${1:-}" ;;
  --vpc-tag-name) shift; VPC_TAG_NAME="${1:-}" ;;
  --vpc-tag-env) shift; VPC_TAG_ENV="${1:-}" ;;
    -h|--help)
      sed -n '1,120p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) err "unknown arg: $1" ;;
  esac
  shift
done

TF_DESTROY() {
  local dir="$1"; shift
  info "terraform destroy: $dir"
  # Ensure backend and providers are initialized before destroy
  terraform -chdir="$dir" init -input=false -upgrade -reconfigure >/dev/null 2>&1 || true
  terraform -chdir="$dir" destroy -auto-approve "$@"
}

auto_detect_state_backend() {
  # If TF_STATE_BUCKET or TF_LOCK_TABLE are unset, try to detect from local tfstate
  local tf=terraform/global/s3/terraform.tfstate
  [[ -f "$tf" ]] || return 0
  if [[ -z "$TF_STATE_BUCKET" ]]; then
    TF_STATE_BUCKET=$(jq -r '.resources[]? | select(.type=="aws_s3_bucket" and .name=="terraform_state") | .instances[0].attributes.bucket' "$tf" 2>/dev/null || echo "")
    [[ "$TF_STATE_BUCKET" == null ]] && TF_STATE_BUCKET=""
    [[ -n "$TF_STATE_BUCKET" ]] && info "auto-detected TF_STATE_BUCKET=$TF_STATE_BUCKET"
  fi
  if [[ -z "$TF_LOCK_TABLE" ]]; then
    TF_LOCK_TABLE=$(jq -r '.resources[]? | select(.type=="aws_dynamodb_table" and .name=="terraform_locks") | .instances[0].attributes.name' "$tf" 2>/dev/null || echo "")
    [[ "$TF_LOCK_TABLE" == null ]] && TF_LOCK_TABLE=""
    [[ -n "$TF_LOCK_TABLE" ]] && info "auto-detected TF_LOCK_TABLE=$TF_LOCK_TABLE"
  fi
}

TF_STATE_LIST() {
  local dir="$1"
  terraform -chdir="$dir" state list 2>/dev/null || true
}

verify_report() {
  info "[verify] Terraform state residues:"
  echo "- app:        $(TF_STATE_LIST terraform/live/dev/app | wc -l | tr -d ' ') resources"
  echo "- certificate: $(TF_STATE_LIST terraform/live/dev/certificate | wc -l | tr -d ' ') resources"
  echo "- ecr (live):  $(TF_STATE_LIST terraform/live/dev/ecr | wc -l | tr -d ' ') resources"
  echo "- dns:        $(TF_STATE_LIST terraform/live/dev/dns | wc -l | tr -d ' ') resources"
  echo "- global/s3:  $(TF_STATE_LIST terraform/global/s3 | wc -l | tr -d ' ') resources"

  # AWS-side checks (best-effort)
  if aws sts get-caller-identity >/dev/null 2>&1; then
    info "[verify] AWS resources existence (best-effort):"
    echo "- ECS cluster: $(aws ecs describe-clusters --region "$AWS_REGION" --clusters reading-log-dev-cluster --query 'clusters[0].status' --output text 2>/dev/null)"
    echo "- ECS services: $(aws ecs list-services --region "$AWS_REGION" --cluster reading-log-dev-cluster --query 'length(serviceArns)' --output text 2>/dev/null)"
    echo "- ALB: $(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'length(LoadBalancers[?contains(LoadBalancerName, `reading-log-dev`)])' --output text 2>/dev/null)"
    echo "- VPC(main/dev): $(aws ec2 describe-vpcs --region "$AWS_REGION" --filters Name=tag:Name,Values=main Name=tag:Env,Values=dev --query 'length(Vpcs)' --output text 2>/dev/null)"
    echo "- RDS(reading-log-dev-mysql): $(aws rds describe-db-instances --region "$AWS_REGION" --db-instance-identifier reading-log-dev-mysql --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)"
    if [[ -n "$ROOT_DOMAIN" ]]; then
      echo "- Route53 zone: $(aws route53 list-hosted-zones-by-name --dns-name "$ROOT_DOMAIN" --query 'length(HostedZones)' --output text 2>/dev/null)"
    fi
    if [[ -n "$APP_FQDN" ]]; then
      echo "- ACM($APP_FQDN): $(aws acm list-certificates --region "$AWS_REGION" --query "length(CertificateSummaryList[?DomainName=='$APP_FQDN'])" --output text 2>/dev/null)"
    fi
    if [[ -n "$REPO_NAME" ]]; then
      echo "- ECR($REPO_NAME): $(aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$REPO_NAME" --query 'length(repositories)' --output text 2>/dev/null)"
    fi
    if [[ -n "$TF_STATE_BUCKET" ]]; then
      aws s3api head-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" >/dev/null 2>&1 && echo "- state bucket: exists" || echo "- state bucket: not found"
    fi
    if [[ -n "$TF_LOCK_TABLE" ]]; then
      echo "- lock table: $(aws dynamodb describe-table --region "$AWS_REGION" --table-name "$TF_LOCK_TABLE" --query 'Table.TableStatus' --output text 2>/dev/null)"
    fi

    # VPC infra deep-checks
    # Resolve target VPC id for checks (prefer explicit, then tags)
    local vpc_id
    if [[ -n "$VPC_ID" ]]; then
      vpc_id="$VPC_ID"
    else
      vpc_id=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
        --filters Name=tag:Name,Values="$VPC_TAG_NAME" Name=tag:Env,Values="$VPC_TAG_ENV" \
        --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
    fi
    if [[ -n "$vpc_id" && "$vpc_id" != "None" && "$vpc_id" != "null" ]]; then
      echo "- VPC ID: $vpc_id"
      echo "- IGW in VPC: $(aws ec2 describe-internet-gateways --region "$AWS_REGION" --filters Name=attachment.vpc-id,Values="$vpc_id" --query 'length(InternetGateways)' --output text 2>/dev/null)"
      echo "- NAT GW in VPC: $(aws ec2 describe-nat-gateways --region "$AWS_REGION" --filter Name=vpc-id,Values="$vpc_id" --query 'length(NatGateways[?State!=`deleted`])' --output text 2>/dev/null)"
      echo "- Subnets in VPC: $(aws ec2 describe-subnets --region "$AWS_REGION" --filters Name=vpc-id,Values="$vpc_id" --query 'length(Subnets)' --output text 2>/dev/null)"
      echo "- Route tables in VPC: $(aws ec2 describe-route-tables --region "$AWS_REGION" --filters Name=vpc-id,Values="$vpc_id" --query 'length(RouteTables)' --output text 2>/dev/null)"
      echo "- SecurityGroups(non-default) in VPC: $(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=vpc-id,Values="$vpc_id" --query 'length(SecurityGroups[?GroupName!=`default`])' --output text 2>/dev/null)"
      echo "- NACLs(non-default) in VPC: $(aws ec2 describe-network-acls --region "$AWS_REGION" --filters Name=vpc-id,Values="$vpc_id" --query 'length(NetworkAcls[?IsDefault==`false`])' --output text 2>/dev/null)"
      echo "- VPC endpoints: $(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" --filters Name=vpc-id,Values="$vpc_id" --query 'length(VpcEndpoints)' --output text 2>/dev/null)"
      echo "- ENIs in VPC: $(aws ec2 describe-network-interfaces --region "$AWS_REGION" --filters Name=vpc-id,Values="$vpc_id" --query 'length(NetworkInterfaces)' --output text 2>/dev/null)"
    fi

    # Secrets best-effort: look up by common substrings
    local sm_regex
    sm_regex="reading-log|yomo-reading-log"
    [[ -n "$REPO_NAME" ]] && sm_regex="$sm_regex|$REPO_NAME"
    [[ -n "$APP_FQDN" ]] && sm_regex="$sm_regex|$APP_FQDN"
    echo "- Secrets(matches: $sm_regex): $(aws secretsmanager list-secrets --region "$AWS_REGION" --max-results 100 --query 'SecretList[].Name' --output json 2>/dev/null | jq -r --arg re "$sm_regex" '[ .[] | select(test($re)) ] | length')"

    # IaC tag-based sweep visibility (Project=reading-log, Env=dev)
    # Many modules tag resources with these; this gives a cross-service view via Tagging API
    local tag_count
    tag_count=$(aws resourcegroupstaggingapi get-resources \
      --region "$AWS_REGION" \
      --tag-filters Key=Project,Values=reading-log Key=Env,Values=dev \
      --query 'length(ResourceTagMappingList)' --output text 2>/dev/null || echo "0")
    echo "- Tagged resources (Project=reading-log,Env=dev): ${tag_count}"
  else
    warn "[verify] AWS credentials not found; skipped cloud-side checks. Set AWS_PROFILE/credentials to enable."
  fi
}

# ------------- step 1: app -------------
step_app() {
  (( SKIP_APP )) && { info "[skip] app"; return 0; }
  for v in APP_FQDN IMAGE_TAG HOSTED_ZONE_ID CERT_ARN; do
    [[ -n "${(P)v}" ]] || err "missing required var for app destroy: $v"
  done
  info "[1/5] Destroy App (VPC/ALB/ECS/RDS/Secrets)"
  info "vars: region=$AWS_REGION fqdn=$APP_FQDN tag=$IMAGE_TAG zone=$HOSTED_ZONE_ID cert=$CERT_ARN"
  confirm || { warn "abort app"; return 1; }
  TF_DESTROY terraform/live/dev/app \
    -var "aws_region=$AWS_REGION" \
    -var "app_image_tag=$IMAGE_TAG" \
    -var "db_username=readinglog" \
    -var "app_fqdn=$APP_FQDN" \
    -var "hosted_zone_id=$HOSTED_ZONE_ID" \
    -var "certificate_arn=$CERT_ARN"
}

# ------------- step 2: acm -------------
step_acm() {
  (( SKIP_ACM )) && { info "[skip] acm"; return 0; }
  for v in APP_FQDN HOSTED_ZONE_ID; do
    [[ -n "${(P)v}" ]] || err "missing required var for acm destroy: $v"
  done
  info "[2/5] Destroy ACM certificate"
  confirm || { warn "abort acm"; return 1; }
  TF_DESTROY terraform/live/dev/certificate \
    -var "domain_name=$APP_FQDN" \
    -var "hosted_zone_id=$HOSTED_ZONE_ID" \
    -var 'subject_alternative_names=[]'
}

# ------------- step 3: ecr -------------
empty_ecr_repo() {
  local repo="$1"
  info "Empty ECR repo: $repo"
  local imgs
  imgs=$(aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} ecr list-images --region "$AWS_REGION" --repository-name "$repo" --query 'imageIds[*]' --output json || echo '[]')
  jq -c '.[]' <<<"$imgs" | while read -r id; do
    local tag dig
    tag=$(jq -r '.imageTag // empty' <<<"$id");
    dig=$(jq -r '.imageDigest // empty' <<<"$id");
    if [[ -n "$tag" ]]; then
      aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} ecr batch-delete-image --region "$AWS_REGION" --repository-name "$repo" --image-ids imageTag="$tag" >/dev/null || true
    fi
    if [[ -n "$dig" ]]; then
      aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} ecr batch-delete-image --region "$AWS_REGION" --repository-name "$repo" --image-ids imageDigest="$dig" >/dev/null || true
    fi
  done
}

step_ecr() {
  (( SKIP_ECR )) && { info "[skip] ecr"; return 0; }
  [[ -n "$REPO_NAME" ]] || err "missing --repo-name for ECR"
  info "[3/5] Empty and destroy ECR"
  confirm || { warn "abort ecr"; return 1; }
  empty_ecr_repo "$REPO_NAME"
  TF_DESTROY terraform/live/dev/ecr \
    -var "aws_region=$AWS_REGION" -var "repository_name=$REPO_NAME"
  # Optionally destroy global ECR (default name: reading-log)
  if [[ -d terraform/global/ecr ]]; then
    TF_DESTROY terraform/global/ecr \
      -var "aws_region=$AWS_REGION" -var "repository_name=reading-log" || true
  fi
}

# ------------- step 4: dns -------------
step_dns() {
  (( SKIP_DNS )) && { info "[skip] dns"; return 0; }
  [[ -n "$ROOT_DOMAIN" ]] || err "missing --root-domain for DNS"
  info "[4/5] Destroy Route53 hosted zone ($ROOT_DOMAIN)"
  confirm || { warn "abort dns"; return 1; }
  # Attempt to cleanup non-NS/SOA records to avoid HostedZoneNotEmpty
  if [[ -n "$HOSTED_ZONE_ID" ]]; then
    info "Cleanup record sets in zone: $HOSTED_ZONE_ID (excluding NS/SOA)"
    aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --output json \
      | jq -c '.ResourceRecordSets[] | select(.Type != "NS" and .Type != "SOA")' \
      | while read -r rr; do
          name=$(jq -r '.Name' <<<"$rr"); type=$(jq -r '.Type' <<<"$rr");
          change=$(jq -c --arg n "$name" --arg t "$type" '{Changes:[{Action:"DELETE", ResourceRecordSet:.}]}' <<<"$rr")
          aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "$change" >/dev/null 2>&1 || true
        done
    # small wait for propagation
    sleep 2
  fi
  TF_DESTROY terraform/live/dev/dns \
    -var "aws_region=$AWS_REGION" -var "root_domain=$ROOT_DOMAIN"
}

# ------------- step 5: state backend -------------
purge_bucket_versions() {
  local bkt="$1"
  info "Purge S3 versions & delete markers in s3://$bkt"
  aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} s3 rm "s3://$bkt" --region "$AWS_REGION" --recursive || true
  aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} s3api list-object-versions --region "$AWS_REGION" --bucket "$bkt" --output json \
    | jq -r '.Versions[]?, .DeleteMarkers[]? | "\(.Key) \(.VersionId)"' \
    | while read -r key ver; do
        aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} s3api delete-object --region "$AWS_REGION" --bucket "$bkt" --key "$key" --version-id "$ver" >/dev/null || true
      done
}

step_state() {
  (( SKIP_STATE )) && { info "[skip] state"; return 0; }
  # Prefer actual values from tfstate if present
  local tf=terraform/global/s3/terraform.tfstate
  local actual_bucket="" actual_table=""
  if [[ -f "$tf" ]]; then
    actual_bucket=$(jq -r '.resources[]? | select(.type=="aws_s3_bucket" and .name=="terraform_state") | .instances[0].attributes.bucket' "$tf" 2>/dev/null || echo "")
    [[ "$actual_bucket" == null ]] && actual_bucket=""
    actual_table=$(jq -r '.resources[]? | select(.type=="aws_dynamodb_table" and .name=="terraform_locks") | .instances[0].attributes.name' "$tf" 2>/dev/null || echo "")
    [[ "$actual_table" == null ]] && actual_table=""
  fi
  # Use detected values if provided ones are empty or mismatched
  if [[ -n "$actual_bucket" && "$TF_STATE_BUCKET" != "$actual_bucket" ]]; then
    warn "TF_STATE_BUCKET mismatch: provided='$TF_STATE_BUCKET' actual='$actual_bucket' -> using actual"
    TF_STATE_BUCKET="$actual_bucket"
  fi
  if [[ -n "$actual_table" && "$TF_LOCK_TABLE" != "$actual_table" ]]; then
    warn "TF_LOCK_TABLE mismatch: provided='$TF_LOCK_TABLE' actual='$actual_table' -> using actual"
    TF_LOCK_TABLE="$actual_table"
  fi
  [[ -n "$TF_STATE_BUCKET" && -n "$TF_LOCK_TABLE" ]] || { warn "skip state: missing TF_STATE_BUCKET/TF_LOCK_TABLE"; return 0; }
  info "[5/5] Destroy Terraform state backend (global/s3)"
  confirm || { warn "abort state"; return 1; }
  purge_bucket_versions "$TF_STATE_BUCKET"
  TF_DESTROY terraform/global/s3 \
    -var "bucket_name=$TF_STATE_BUCKET" -var "table_name=$TF_LOCK_TABLE"
  # Delete DynamoDB lock table explicitly if it still exists (not tracked by tfstate)
  if aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} dynamodb describe-table --region "$AWS_REGION" --table-name "$TF_LOCK_TABLE" >/dev/null 2>&1; then
    info "Delete DynamoDB lock table: $TF_LOCK_TABLE"
    aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} dynamodb delete-table --region "$AWS_REGION" --table-name "$TF_LOCK_TABLE" >/dev/null || true
    # Wait until table is deleted
    for i in {1..30}; do
      aws ${AWS_PROFILE_ARG:+${AWS_PROFILE_ARG[@]}} dynamodb describe-table --region "$AWS_REGION" --table-name "$TF_LOCK_TABLE" >/dev/null 2>&1 || { info "Lock table deleted"; break; }
      sleep 2
    done
  fi
}


# ------------- run -------------
info "Cleanup start (region=$AWS_REGION profile=${AWS_PROFILE:-})"
auto_detect_state_backend || true
if (( VERIFY_ONLY )); then
  verify_report
else
  step_app || true
  step_acm || true
  step_ecr || true
  step_dns || true
  step_state || true
  info "---"
  verify_report || true
fi
info "Cleanup done"
