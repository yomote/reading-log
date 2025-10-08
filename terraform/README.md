# Terraform IAC 運用フロー

## 構成概要

- DNS (Route53): `/live/dev/dns` でゾーン管理
- 証明書 (ACM): `/live/dev/certificate` で証明書発行・検証
- ECR (コンテナレジストリ): `/live/dev/ecr` でリポジトリ作成
- S3 (静的ファイル): `/live/dev/s3` でバケット作成・静的ホスティング
- アプリ/ALB/DB: `/live/dev/app` でVPC, ALB, ECS, RDSなど
- DBマイグレーション: Prisma/ECSタスク (run_migration_task.sh)
- 各リソースは `modules/` 配下の再利用モジュールで管理

## 環境前提

- 認証: `aws-vault exec dev-admin -- <command>` 形式（任意ツール置換可）
- リージョン: us-east-2（例）
- 変数は terraform.tfvars or -var で注入

## 環境変数例

```bash
export AWS_REGION=us-east-2
export ROOT_DOMAIN=example.com
export APP_FQDN=app.example.com
export REPO_NAME=reading-log-dev
export IMAGE_TAG=v1.0.3
export HOSTED_ZONE_ID=Z0123456789ABCDE
# 取得後に設定
export CERT_ARN=arn:aws:acm:us-east-2:ACCOUNT_ID:certificate/UUID
```

## 運用手順（全体フロー）

1. **DNSゾーン作成**

   ```bash
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/dns init
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/dns apply -auto-approve \
     -var "aws_region=$AWS_REGION" -var "root_domain=$ROOT_DOMAIN"
   ```

   - 出力される `name_servers` をレジストラ（お名前.com等）に登録
   - `dig NS example.com +short` でRoute53 NSへ切り替わったか確認

2. **ECR リポジトリ作成**

   ```bash
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/ecr init
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/ecr apply -auto-approve \
     -var "aws_region=$AWS_REGION" -var "repository_name=$REPO_NAME"
   ```

   - `terraform output repository_url` で `ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/reading-log-dev` を取得

3. **S3 バケット作成 & 静的ファイル配置**

   ```bash
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/s3 init
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/s3 apply -auto-approve \
     -var "aws_region=$AWS_REGION" -var 'bucket_name=reading-log-dev-assets'
   aws-vault exec dev-admin -- aws s3 sync public/ s3://reading-log-dev-assets/ --delete
   ```

   - CloudFront/OAIを使う場合は追加のterraformモジュールを適用

4. **Docker イメージ ビルド & プッシュ**

   - リポジトリURLは ECR output 参照
   - 専用スクリプト例 (まだ無い場合 `scripts/build_and_push.sh` 作成を推奨)

   ```bash
   ECR_URL="ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME"
   aws-vault exec dev-admin -- aws ecr get-login-password --region "$AWS_REGION" | \
     docker login --username AWS --password-stdin "$ECR_URL"
   docker build -t "$ECR_URL:$IMAGE_TAG" .
   docker push "$ECR_URL:$IMAGE_TAG"
   ```

5. **ACM 証明書発行 (DNS検証)**

   ```bash
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/certificate init
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/certificate apply -auto-approve \
     -var "aws_region=$AWS_REGION" \
     -var "domain_name=$APP_FQDN" \
     -var "hosted_zone_id=$HOSTED_ZONE_ID" \
     -var 'subject_alternative_names=[]'
   ```

   - `terraform -chdir=terraform/live/dev/certificate output certificate_arn` → `CERT_ARN` 環境変数に設定
   - ACMコンソールで `Issued` を確認

6. **アプリ / ALB / DB 作成**

   ```bash
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/app init
   aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/app apply -auto-approve \
     -var "aws_region=$AWS_REGION" \
     -var "app_image_tag=$IMAGE_TAG" \
     -var "db_username=readinglog" \
     -var "app_fqdn=$APP_FQDN" \
     -var "hosted_zone_id=$HOSTED_ZONE_ID" \
     -var "certificate_arn=$CERT_ARN"
   ```

7. **DB マイグレーション実行 (Prisma)**

   - 既存 `scripts/run_migration_task.sh` を利用
   - 最低限: CLUSTER, MIGRATION_TASK_DEF (または TASK_DEF_ARN), SERVICE (解決用)

   ```bash
   export CLUSTER=reading-log-dev-cluster
   export MIGRATION_TASK_DEF=reading-log-dev-migrate-task
   export SERVICE=reading-log-dev-service
   export REGION=$AWS_REGION
   aws-vault exec dev-admin -- ./scripts/run_migration_task.sh
   ```

   オプション:

   ```bash
   INTERVAL=10 TIMEOUT=300 SUBNETS=subnet-aaa,subnet-bbb SECURITY_GROUPS=sg-xxx \
     aws-vault exec dev-admin -- ./scripts/run_migration_task.sh
   ```

## トラブルシュート Quick Reference

| 症状 | 確認ポイント | 対処 |
|------|--------------|------|
| ACM Pending のまま | NS伝播 / 検証CNAME | digでCNAME存在, 待機 or TTL再確認 |
| HTTPS 警告 | FQDN一致 / Issued | ブラウザURLと証明書CN/SAN一致確認 |
| Migration失敗(exit≠0) | Taskログ / RDS接続 | 環境変数とDB権限 / Prismaエラー確認 |
| ALIAS解決不可 | hosted_zone_id / app_fqdn | ゾーンID誤り or NS未反映 |

## 分離構成のメリット

- apply順序が明確で失敗しにくい
- DNS / 証明書 / ECR / S3 / DB を独立更新
- CI/CD 分割 (並列最適化可)
- モジュール単位で再利用性向上

## 注意点

- 証明書は `Issued` 後に ALB 適用
- Image Tag の immutable 運用推奨（再ビルド禁止 or digestピン止め）
- Migration は冪等に（スクリプトはエラー時 exit!=0）
- リソース削除順序に注意（RDS削除前にバックアップ）

---

## クリーンアップ（Destroy）手順

環境を一時撤去する際の推奨削除順序です。依存関係の都合で順番が重要です。

推奨順序:

- 1) アプリ（VPC/ALB/ECS/RDS/Secrets 等）
- 2) 証明書（ACM）
- 3) ECR（中身のイメージを削除してから）
- 4) DNS（Route53 ホストゾーン）
- 5) Terraform state 用 S3 バケット / DynamoDB ロックテーブル（最後）

前提の環境変数例:

```bash
export AWS_REGION=us-east-2
export ROOT_DOMAIN=example.com
export APP_FQDN=app.example.com
export REPO_NAME=reading-log-dev
export IMAGE_TAG=v1.0.3
export HOSTED_ZONE_ID=Z0123456789ABCDE
export CERT_ARN=arn:aws:acm:us-east-2:ACCOUNT_ID:certificate/UUID
# リモートステート管理を消す場合のみ必要
export TF_STATE_BUCKET=reading-log-tf-state
export TF_LOCK_TABLE=terraform-locks
```

注意:

- ACM 証明書は ALB にアタッチ中だと削除できません。必ず先に「アプリ」を destroy。
- ECR は中身のイメージが残っていると削除できません。先に空にします。
- Terraform state 用の S3/DynamoDB は最後に削除してください。

### 1) アプリ（VPC/ALB/ECS/RDS/Secrets 等）を削除

```bash
aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/app destroy -auto-approve \
  -var "aws_region=$AWS_REGION" \
  -var "app_image_tag=$IMAGE_TAG" \
  -var "db_username=readinglog" \
  -var "app_fqdn=$APP_FQDN" \
  -var "hosted_zone_id=$HOSTED_ZONE_ID" \
  -var "certificate_arn=$CERT_ARN"
```

メモ:

- RDS の最終スナップショットが必要なら destroy 前に `skip_final_snapshot=false` と `final_snapshot_identifier` を設定して再 apply。
- Secrets 削除で失敗する場合は `terraform/scripts/force_delete_secrets.sh` が利用できます。

```bash
# 例: データベースURLを強制削除（ID/ARN は環境に合わせて）
AWS_REGION=$AWS_REGION ./terraform/scripts/force_delete_secrets.sh "reading-log/dev/DATABASE_URL"
```

### 2) 証明書（ACM）を削除

```bash
aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/certificate destroy -auto-approve \
  -var "aws_region=$AWS_REGION" \
  -var "domain_name=$APP_FQDN" \
  -var "hosted_zone_id=$HOSTED_ZONE_ID" \
  -var 'subject_alternative_names=[]'
```

ポイント: App 側の ALB/Listener が削除済みであること（未削除だと `InUse` で失敗）。

### 3) ECR を空にしてから削除（live/dev もしくは global）

すべてのイメージを削除（zsh + jq 必須）:

```bash
aws-vault exec dev-admin -- aws ecr list-images --repository-name "$REPO_NAME" --query 'imageIds[*]' --output json \
  | jq -c '.[]' | while read -r id; do \
      tag=$(jq -r '.imageTag // empty' <<<"$id"); dig=$(jq -r '.imageDigest // empty' <<<"$id"); \
      [[ -n "$tag" ]] && aws-vault exec dev-admin -- aws ecr batch-delete-image --repository-name "$REPO_NAME" --image-ids imageTag="$tag" >/dev/null || true; \
      [[ -n "$dig" ]] && aws-vault exec dev-admin -- aws ecr batch-delete-image --repository-name "$REPO_NAME" --image-ids imageDigest="$dig" >/dev/null || true; \
    done

# Terraform で削除（live/dev の方）
aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/ecr destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "repository_name=$REPO_NAME"

# （必要に応じて）global/ecr も destroy（リポジトリ名: reading-log）
aws-vault exec dev-admin -- terraform -chdir=terraform/global/ecr destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "repository_name=reading-log"
```

### 4) DNS（Route53 ホストゾーン）を削除

```bash
aws-vault exec dev-admin -- terraform -chdir=terraform/live/dev/dns destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "root_domain=$ROOT_DOMAIN"
```

### 5) Terraform state（S3/DynamoDB）を最後に削除（global/s3）

バケットはバージョニング有効のため、全オブジェクト・全バージョン・削除マーカーを除去してから destroy:

```bash
# 全オブジェクト削除
aws-vault exec dev-admin -- aws s3 rm "s3://$TF_STATE_BUCKET" --recursive || true

# 全バージョン/削除マーカー削除（jq 必須）
aws-vault exec dev-admin -- aws s3api list-object-versions --bucket "$TF_STATE_BUCKET" --output json \
  | jq -r '.Versions[]?, .DeleteMarkers[]? | "\(.Key) \(.VersionId)"' \
  | while read -r key ver; do \
      aws-vault exec dev-admin -- aws s3api delete-object --bucket "$TF_STATE_BUCKET" --key "$key" --version-id "$ver" >/dev/null || true; \
    done

# Terraform で削除
aws-vault exec dev-admin -- terraform -chdir=terraform/global/s3 destroy -auto-approve \
  -var "bucket_name=$TF_STATE_BUCKET" -var "table_name=$TF_LOCK_TABLE"
```

---

困ったとき:

- `terraform destroy` が依存関係で失敗 → 順序を再確認（App → ACM → ECR → DNS → S3）。
- Secrets Manager が `ScheduledDeletion` で停止 → `terraform/scripts/force_delete_secrets.sh` を利用。
- RDS の最終スナップショットが必要 → destroy 前に設定変更して再 apply。
