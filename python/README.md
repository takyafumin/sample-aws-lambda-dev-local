# AWS Lambda Python Sample

AWS Lambdaのローカル開発環境サンプルプロジェクト

## プロジェクト構成

```
├── src/
│   └── handlers/
│       ├── __init__.py
│       └── lambda_handler.py      # Lambda関数のメインハンドラ
├── tests/
│   └── test_lambda_handler.py     # テストファイル
├── docs/
│   └── README.md                  # 詳細ドキュメント
├── docker/
│   └── Dockerfile                 # Lambda用Dockerファイル
├── config/
│   └── .env.sample               # 環境変数のサンプル
├── scripts/
│   └── deploy.sh                 # デプロイスクリプト
├── .env                          # 環境変数（gitignore対象）
├── pyproject.toml                # プロジェクト設定
└── uv.lock                       # 依存関係ロックファイル
```

## 環境設定

1. 環境変数ファイルを設定：
   ```bash
   cp config/.env.sample .env
   # .envファイルに実際の値を設定
   ```

2. Python環境のセットアップ：
   ```bash
   uv sync
   ```

## ローカル開発

### テスト実行
```bash
uv run pytest tests/
```

### Lambda関数の実行
```bash
uv run python src/handlers/lambda_handler.py
```

## Dockerでの実行

### イメージのビルド
```bash
docker build -t aws-lambda-python-sample -f docker/Dockerfile .
```

### コンテナの実行
```bash
docker run -p 9000:8080 --env-file .env aws-lambda-python-sample
```

### Lambda関数の呼び出し
```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
```

## デプロイ

```bash
./scripts/deploy.sh
```

## 機能概要

このサンプルプロジェクトは、S3バケット内のオブジェクト一覧を取得するLambda関数です。

### 主な機能
- S3バケット内のオブジェクト名取得
- 環境変数による設定管理
- エラーハンドリング
- Dockerコンテナでの実行サポート
