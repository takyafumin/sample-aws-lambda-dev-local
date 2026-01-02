# AWS Lambda Python Sample

AWS Lambdaのローカル開発環境サンプルプロジェクト

## 環境セットアップ

```bash
# 自動セットアップ（推奨）
./scripts/setup-macos.sh
aws configure

# または手動セットアップ
brew install uv awscli docker
uv sync
```

## 開発ワークフロー

### 1. ローカル実行（Python直接）

```bash
# Lambda関数を直接実行してテスト
uv run python src/handlers/lambda_handler.py

# 単体テスト実行
uv run pytest tests/
```

### 2. ローカル実行（Docker）

```bash
# Dockerでテスト実行
./scripts/test-local.sh

# 手動でDockerテスト
docker build -t aws-lambda-python-sample -f docker/Dockerfile .
docker run --rm -d -p 9000:8080 aws-lambda-python-sample
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
     -d '{"Records": [{"body": "test"}]}'
```

### 3. AWSデプロイ

```bash
# 自動デプロイ（ECRリポジトリ・Lambda関数も自動作成）
./scripts/deploy.sh
```

### 4. AWS実行確認

```bash
# デプロイされたLambda関数をテスト
./scripts/test-remote.sh

# 手動でAWSテスト
aws lambda invoke --function-name aws-sample-lambda response.json
cat response.json
```

## プロジェクト構成

```
├── src/handlers/lambda_handler.py    # メインのLambda関数
├── tests/test_lambda_handler.py      # テストファイル
├── docker/Dockerfile                 # Lambda用Dockerファイル
├── scripts/                          # 自動化スクリプト
│   ├── setup-macos.sh               # 環境セットアップ
│   ├── test-local.sh                # Dockerローカルテスト
│   ├── deploy.sh                    # AWSデプロイ
│   └── test-remote.sh               # AWSリモートテスト
├── pyproject.toml                    # Python設定
└── uv.lock                          # 依存関係ロック
```

## 機能概要

このLambda関数は、S3バケット内のオブジェクト一覧を取得します。

## カスタマイズ

環境変数で設定を変更できます：

```bash
export FUNCTION_NAME="my-lambda"
export ECR_REPOSITORY_NAME="my-repo"
export AWS_DEFAULT_REGION="us-west-2"
```

## トラブルシューティング

### よくある問題

```bash
# Docker未起動
❌ Cannot connect to the Docker daemon
💡 Docker Desktopを起動してください

# AWS認証エラー
❌ Unable to locate credentials
💡 aws configure で設定してください
```

### Apple Silicon (M1/M2/M3) Mac

ARM/AMD64の切り替えは自動判定されます。特別な設定は不要です。
