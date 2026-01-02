#!/bin/bash

# Lambda関数のローカルテストスクリプト (リファクタリング版)

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリの読み込み
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# コマンドライン引数の処理
TEST_EVENT="${1:-$DEFAULT_TEST_EVENT_LOCAL}"

# メイン処理開始
echo "${LOG_PREFIX_TEST} Lambda関数のローカルテストを開始します..."
echo ""

# 設定の読み込み
load_configuration
echo ""

# .envファイルの読み込み
load_env_file
echo ""

# プラットフォーム判定
detect_platform
echo ""

# Dockerイメージの存在確認とビルド
echo "🔍 Dockerイメージの存在を確認しています..."
if ! check_docker_image "$DOCKER_IMAGE_NAME"; then
    echo "${LOG_PREFIX_INFO} Dockerイメージが見つかりません。ビルドを開始します..."
    if ! build_docker_image "$DOCKER_IMAGE_NAME" "docker/Dockerfile"; then
        echo "${LOG_PREFIX_ERROR} Dockerイメージのビルドに失敗しました"
        exit 1
    fi
fi
echo ""

# テストイベントファイルの存在確認・作成
create_test_event_file "$TEST_EVENT" "local"
echo ""

# AWS環境変数の確認
required_aws_vars=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "S3_BUCKET_NAME")
if ! check_aws_environment_variables "${required_aws_vars[@]}"; then
    echo ""
    if ! confirm_action "🤔 環境変数なしでテストを続行しますか？ (y/N)" "N" false; then
        echo "⏭️ テストを中止しました"
        exit 1
    fi
    echo "${LOG_PREFIX_WARNING} 環境変数なしでテストを続行します（S3機能は動作しません）"
fi
echo ""

# Dockerコンテナでテスト実行
echo "🚀 AWS Lambda Runtime Interface Emulatorでテストを実行しています..."

# AWS標準環境変数のリスト（存在する場合のみ設定）
# 注意: S3_BUCKET_NAMEはDockerイメージビルド時に設定されているため除外
ENV_ARGS=()
AWS_ENV_VARS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_DEFAULT_REGION"
    "AWS_SESSION_TOKEN"
)

for var in "${AWS_ENV_VARS[@]}"; do
    if [[ -n "${!var}" ]]; then
        ENV_ARGS+=("-e" "$var=${!var}")
    fi
done

# バックグラウンドでLambda Emulatorを起動
CONTAINER_NAME="lambda-test-$$"
docker run --rm -d -p "${LAMBDA_RIE_PORT}:8080" \
    "${ENV_ARGS[@]}" \
    --name "$CONTAINER_NAME" \
    "${DOCKER_IMAGE_NAME}:latest"

# Dockerコンテナが起動するまで待機
echo "⏳ Lambda Emulatorの起動を待機しています..."
sleep "$LAMBDA_STARTUP_WAIT"

# ヘルスチェック
echo "🩺 Lambda Emulatorのヘルスチェック中..."
for i in $(seq 1 "$LAMBDA_HEALTHCHECK_RETRIES"); do
    if curl -s "http://localhost:${LAMBDA_RIE_PORT}/2015-03-31/functions/function/invocations" > /dev/null 2>&1; then
        echo "${LOG_PREFIX_SUCCESS} Lambda Emulator が正常に起動しました"
        break
    fi
    echo "   待機中... ($i/$LAMBDA_HEALTHCHECK_RETRIES)"
    sleep 1
done

# Lambda関数を呼び出し
echo "📡 Lambda関数を呼び出しています..."
echo "   Event file: $TEST_EVENT"

# curlでLambda関数を呼び出し、結果を整形
RESPONSE=$(curl -s -XPOST "http://localhost:${LAMBDA_RIE_PORT}/2015-03-31/functions/function/invocations" \
    -d @"$TEST_EVENT" \
    --header "Content-Type: application/json")

echo ""
echo "📄 実行結果:"
format_json_output "$RESPONSE"
echo ""

# クリーンアップ
echo "🛑 テストコンテナを停止しています..."
docker stop "$CONTAINER_NAME" &> /dev/null || echo "コンテナは既に停止しています"

echo "${LOG_PREFIX_SUCCESS} ローカルテストが完了しました！"