#!/bin/bash

# Lambda関数のリモートテストスクリプト (macOS対応)

set -e

# 変数設定
FUNCTION_NAME="${FUNCTION_NAME:-aws-sample-lambda}"
REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}"
TEST_EVENT="${1:-resources/events/test_event_remote.json}"
OUTPUT_FILE="${2:-response.json}"

echo "☁️ リモートLambda関数のテストを開始します..."

# AWS認証情報の確認
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS認証情報が設定されていません"
    echo "💡 以下のコマンドでAWS CLIを設定してください:"
    echo "   aws configure"
    exit 1
fi

# Lambda関数の存在確認
echo "🔍 Lambda関数の存在を確認しています..."
if ! aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &> /dev/null; then
    echo "❌ Lambda関数が見つかりません: $FUNCTION_NAME"
    echo "💡 先にデプロイを実行してください: ./scripts/deploy.sh"
    exit 1
fi

# テストイベントファイルの存在確認・作成
if [[ ! -f "$TEST_EVENT" ]]; then
    echo "📝 テストイベントファイルを作成しています: $TEST_EVENT"
    # ディレクトリが存在しない場合は作成
    mkdir -p "$(dirname "$TEST_EVENT")"
    cat > "$TEST_EVENT" << 'EOF'
{
    "test_mode": "remote",
    "message": "Hello from remote Lambda test",
    "environment": "production",
    "timestamp": "2026-01-02T00:00:00Z"
}
EOF
fi

# Lambda関数を実行
echo "🚀 Lambda関数を実行しています..."
echo "   Function: $FUNCTION_NAME"
echo "   Region: $REGION"
echo "   Event: $TEST_EVENT"
echo "   Output: $OUTPUT_FILE"

aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --payload file://"$TEST_EVENT" \
    --cli-binary-format raw-in-base64-out \
    "$OUTPUT_FILE"

# 結果の表示
if [[ -f "$OUTPUT_FILE" ]]; then
    echo ""
    echo "📄 実行結果:"
    cat "$OUTPUT_FILE" | python3 -m json.tool 2>/dev/null || cat "$OUTPUT_FILE"
    echo ""
    echo "✅ Lambda関数のテストが完了しました！"
    
    # response.jsonファイルを削除
    rm -f "$OUTPUT_FILE"
else
    echo "❌ レスポンスファイルが作成されませんでした"
    exit 1
fi

# ログの確認
echo ""
echo "📜 最新のログを確認しています..."
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

# 最新のログストリームを取得
LATEST_STREAM=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --region $REGION \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null)

if [[ "$LATEST_STREAM" != "None" && -n "$LATEST_STREAM" && "$LATEST_STREAM" != "null" ]]; then
    echo "📋 最新のログストリーム: $LATEST_STREAM"
    # CloudWatch Logsコンソールへのリンクを生成
    LOG_STREAM_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$LATEST_STREAM', safe=''))" 2>/dev/null || echo "$LATEST_STREAM")
    LOG_GROUP_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$LOG_GROUP', safe=''))" 2>/dev/null || echo "$LOG_GROUP")
    CONSOLE_URL="https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/${LOG_GROUP_ENCODED}/log-events/${LOG_STREAM_ENCODED}"
    echo "🔗 CloudWatch Logsで確認: $CONSOLE_URL"
else
    echo "⚠️ ログストリームが見つかりませんでした"
    # 少し待機してから再試行
    echo "   ⏳ ログの反映を待機しています..."
    sleep 5
    
    LATEST_STREAM=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --region $REGION \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null)
    
    if [[ "$LATEST_STREAM" != "None" && -n "$LATEST_STREAM" && "$LATEST_STREAM" != "null" ]]; then
        echo "📋 最新のログストリーム: $LATEST_STREAM"
        # CloudWatch Logsコンソールへのリンクを生成
        LOG_STREAM_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$LATEST_STREAM', safe=''))" 2>/dev/null || echo "$LATEST_STREAM")
        LOG_GROUP_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$LOG_GROUP', safe=''))" 2>/dev/null || echo "$LOG_GROUP")
        CONSOLE_URL="https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/${LOG_GROUP_ENCODED}/log-events/${LOG_STREAM_ENCODED}"
        echo "🔗 CloudWatch Logsで確認: $CONSOLE_URL"
    else
        echo "⚠️ ログが見つかりませんでした"
        echo "💡 Lambda関数のロググループを手動で確認: /aws/lambda/$FUNCTION_NAME"
    fi
fi