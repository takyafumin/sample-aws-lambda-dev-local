# AWS Lambda Shell Scripts - Refactored Structure

このディレクトリには、リファクタリングされたAWS Lambda関数のデプロイとテストを行うためのシェルスクリプトが含まれています。

## 📁 ディレクトリ構造

```
scripts/
├── config/
│   └── settings.sh         # 共通設定とデフォルト値
├── lib/
│   └── utils.sh           # 共通ユーティリティ関数
├── infra/
│   └── aws-resources.sh   # AWSインフラリソース管理
├── deploy.sh              # Lambda関数デプロイスクリプト（リファクタリング版）
├── test-local.sh          # ローカルテストスクリプト（リファクタリング版）
├── test-remote.sh         # リモートテストスクリプト（リファクタリング版）
└── README.md              # このファイル
```

## 🚀 主要な改善点

### 1. モジュール化
- **設定の分離**: [config/settings.sh](config/settings.sh) - すべてのデフォルト値と設定管理
- **共通関数**: [lib/utils.sh](lib/utils.sh) - 再利用可能なユーティリティ関数
- **インフラ管理**: [infra/aws-resources.sh](infra/aws-resources.sh) - AWS リソース操作の専用関数

### 2. 保守性の向上
- 重複コードの削除
- 一貫したエラーハンドリング
- 統一されたロギング形式
- 設定値の集中管理

### 3. 拡張性
- 新機能追加が容易
- 設定変更が一箇所で完結
- テスト環境への対応が簡単

## 📋 使用方法

### デプロイ
```bash
# 基本的なデプロイ
./scripts/deploy.sh

# Lambda関数が存在しない場合、自動作成
./scripts/deploy.sh --auto-create

# ヘルプを表示
./scripts/deploy.sh --help
```

### ローカルテスト
```bash
# デフォルトのテストイベントでテスト
./scripts/test-local.sh

# カスタムテストイベントファイルを使用
./scripts/test-local.sh path/to/custom-event.json
```

### リモートテスト
```bash
# デフォルトのテストイベントでテスト
./scripts/test-remote.sh

# カスタムテストイベントファイルを使用
./scripts/test-remote.sh path/to/custom-event.json
```

## 🔧 設定可能な環境変数

### 基本設定
- `FUNCTION_NAME`: Lambda関数名（デフォルト: `aws-sample-lambda`）
- `AWS_DEFAULT_REGION`: AWSリージョン（デフォルト: `ap-northeast-1`）
- `DOCKER_IMAGE_NAME`: Dockerイメージ名（デフォルト: `aws-lambda-python-sample`）

### ECR設定
- `ECR_REPOSITORY_NAME`: ECRリポジトリ名（デフォルト: `aws-lambda-python-sample`）
- `AWS_ACCOUNT_ID`: AWSアカウントID（自動取得）

### Lambda設定
- `S3_BUCKET_NAME`: S3バケット名（オプション）
- `LAMBDA_ROLE_NAME`: IAMロール名（デフォルト: `lambda-execution-role`）

## 📂 設定ファイル

### [config/settings.sh](config/settings.sh)
すべてのデフォルト設定値と設定管理関数が含まれています：
- デフォルト値の定義
- 環境変数の読み込み
- 設定情報の表示

### [lib/utils.sh](lib/utils.sh)
共通で使用されるユーティリティ関数：
- プラットフォーム検出（macOS、Apple Silicon対応）
- コマンド存在確認
- Dockerイメージ操作
- AWS認証確認

### [infra/aws-resources.sh](infra/aws-resources.sh)
AWSインフラリソース管理の専用関数：
- ECRリポジトリ管理
- Lambda関数操作
- IAMロール管理
- CloudWatch Logs操作

## 🔒 セキュリティ

### 環境変数の管理
`.env` ファイルを使用して環境変数を管理することを推奨します：

```bash
# .env ファイルの例
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET_NAME=your_bucket_name
AWS_DEFAULT_REGION=ap-northeast-1
FUNCTION_NAME=my-lambda-function
```

### IAMロール
Lambda関数には以下のポリシーを持つIAMロールが自動作成されます：
- `AWSLambdaBasicExecutionRole`: 基本的なLambda実行権限
- `AmazonS3ReadOnlyAccess`: S3読み取り専用権限

## 🐛 トラブルシューティング

### よくある問題と解決方法

1. **Dockerイメージのビルドエラー**
   - Apple Silicon Mac の場合、自動的に `--platform linux/amd64` が適用されます
   - Docker BuildX が利用可能な場合は自動的に使用されます

2. **AWS認証エラー**
   - AWS CLI の設定を確認: `aws configure`
   - AWS_PROFILE 環境変数を設定

3. **Lambda関数が見つからない**
   - デプロイを先に実行: `./scripts/deploy.sh --auto-create`

## 💡 ベストプラクティス

1. **環境変数の管理**
   - `.env` ファイルを使用
   - 機密情報をコードにハードコードしない

2. **テスト**
   - ローカルテストから始める
   - リモートテスト前にデプロイを確認

3. **カスタマイズ**
   - 設定値は環境変数で上書き
   - カスタム設定は `config/settings.sh` に追加

## 🚀 今後の拡張予定

- CI/CDパイプライン対応
- 複数環境サポート（dev/staging/prod）
- Lambda Layersサポート
- カスタムドメイン設定
- モニタリング設定自動化