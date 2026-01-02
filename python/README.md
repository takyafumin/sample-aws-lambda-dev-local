# AWS Lambda Python Sample

AWS Lambdaのローカル開発環境サンプルプロジェクト

## 前提条件

### 必要なツール

| ツール | バージョン |
|--------|-----------|
| Homebrew | - |
| Python | 3.13 |
| uv | latest |
| Docker | latest |
| AWS CLI | latest |

## セットアップ手順

```bash
# 1. 依存関係のインストール
uv sync

# 2. AWS認証情報の設定
aws configure
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
```

### 3. AWSデプロイ

```bash
# 自動デプロイ（ECRリポジトリ・Lambda関数も自動作成）
./scripts/deploy.sh

# 確認プロンプトなしで自動デプロイ（CI/CD用）
./scripts/deploy.sh --auto-create
# または
./scripts/deploy.sh -a
```

### 4. AWS実行確認

```bash
# デプロイされたLambda関数をテスト
./scripts/test-remote.sh
```

## プロジェクト構成

```
├── src/handlers/lambda_handler.py    # メインのLambda関数
├── tests/test_lambda_handler.py      # テストファイル
├── docker/Dockerfile                 # Lambda用Dockerファイル
├── scripts/                          # 自動化スクリプト
│   ├── test-local.sh                # Dockerローカルテスト
│   ├── deploy.sh                    # AWSデプロイ（自動作成対応）
│   └── test-remote.sh               # AWSリモートテスト
├── pyproject.toml                    # Python設定
└── uv.lock                          # 依存関係ロック
```

## 機能概要

このLambda関数は、S3バケット内のオブジェクト一覧を取得します。

## デプロイオプション

### 基本デプロイ
```bash
./scripts/deploy.sh
```
- Lambda関数が存在しない場合は作成確認を求めます
- 手動操作が必要です

### 自動デプロイ（CI/CD用）
```bash
./scripts/deploy.sh --auto-create
```
- 確認プロンプトなしで自動的にLambda関数を作成します
- CI/CDパイプラインに適しています

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
