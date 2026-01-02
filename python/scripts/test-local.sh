#!/bin/bash

# Lambda関数のローカルテストスクリプト (macOS対応)

set -e

# 変数設定
DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-aws-lambda-python-sample}"
TEST_EVENT="${1:-resources/events/test_event.json}"

echo "🧪 Lambda関数のローカルテストを開始します..."

# macOS対応: Apple Silicon (M1/M2) チェック
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        echo "🔧 Apple Silicon (M1/M2) を検出しました - x86_64プラットフォームで実行します"
        DOCKER_PLATFORM="--platform linux/amd64"
    else
        echo "🔧 Intel Macを検出しました"
        DOCKER_PLATFORM=""
    fi
else
    DOCKER_PLATFORM=""
fi

# Dockerイメージの存在確認とビルド
echo "🔍 Dockerイメージの存在を確認しています..."
if ! docker image inspect ${DOCKER_IMAGE_NAME}:latest &> /dev/null; then
    echo "📦 Dockerイメージが見つかりません。ビルドを開始します..."
    if [[ -n "$DOCKER_PLATFORM" ]]; then
        echo "🏗️ クロスプラットフォームビルド: $DOCKER_PLATFORM"
    fi
    docker build $DOCKER_PLATFORM -t ${DOCKER_IMAGE_NAME}:latest -f docker/Dockerfile .
    echo "✅ Dockerイメージのビルドが完了しました"
else
    echo "✅ Dockerイメージが存在しています: ${DOCKER_IMAGE_NAME}:latest"
fi

# テストイベントファイルの存在確認
if [[ ! -f "$TEST_EVENT" ]]; then
    echo "📝 テストイベントファイルを作成しています: $TEST_EVENT"
    # ディレクトリが存在しない場合は作成
    mkdir -p "$(dirname "$TEST_EVENT")"
    cat > "$TEST_EVENT" << 'EOF'
{
    "test_mode": "local",
    "message": "Hello from local test",
    "timestamp": "2026-01-02T00:00:00Z"
}
EOF
fi

# Dockerコンテナでテスト実行
echo "🚀 AWS Lambda Runtime Interface Emulatorでテストを実行しています..."

# バックグラウンドでLambda Emulatorを起動
docker run --rm -d -p 9000:8080 \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    -e AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
    -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}" \
    --name lambda-test-$$ \
    ${DOCKER_IMAGE_NAME}:latest

# Dockerコンテナが起動するまで待機
echo "⏳ Lambda Emulatorの起動を待機しています..."
sleep 5

# ヘルスチェック
echo "🩺 Lambda Emulatorのヘルスチェック中..."
for i in {1..10}; do
    if curl -s http://localhost:9000/2015-03-31/functions/function/invocations > /dev/null 2>&1; then
        echo "✅ Lambda Emulator が正常に起動しました"
        break
    fi
    echo "   待機中... ($i/10)"
    sleep 1
done

# Lambda関数を呼び出し
echo "📡 Lambda関数を呼び出しています..."
echo "   Event file: $TEST_EVENT"

# curlでLambda関数を呼び出し、結果を整形
RESPONSE=$(curl -s -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
    -d @"$TEST_EVENT" \
    --header "Content-Type: application/json")

echo ""
echo "📄 実行結果:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# クリーンアップ
echo "🛑 テストコンテナを停止しています..."
docker stop lambda-test-$$ &> /dev/null || echo "コンテナは既に停止しています"

echo "✅ ローカルテストが完了しました！"