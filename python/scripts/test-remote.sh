#!/bin/bash

# Lambda関数のリモートテストスクリプト (macOS対応)

set -e

# 変数設定
FUNCTION_NAME="${FUNCTION_NAME:-aws-sample-lambda}"
REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}"
TEST_EVENT="${1:-test_event.json}"
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
    cat > "$TEST_EVENT" << 'EOF'
{
    "Records": [
        {
            "messageId": "test-message-id-remote",
            "receiptHandle": "test-receipt-handle",
            "body": "{\"message\": \"Hello from remote Lambda test\"}",
            "attributes": {},
            "messageAttributes": {},
            "md5OfBody": "test-md5",
            "eventSource": "aws:sqs",
            "eventSourceARN": "arn:aws:sqs:ap-northeast-1:123456789012:test-queue",
            "awsRegion": "ap-northeast-1"
        }
    ]
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
else
    echo "❌ レスポンスファイルが作成されませんでした"
    exit 1
fi

# ログの確認
echo ""
echo "📊 最新のログを確認しますか？ (y/N)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "📜 CloudWatch Logsを確認しています..."
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
    
    if [[ "$LATEST_STREAM" != "None" && -n "$LATEST_STREAM" ]]; then
        echo "📋 最新のログ (ストリーム: $LATEST_STREAM):"
        aws logs get-log-events \
            --log-group-name "$LOG_GROUP" \
            --log-stream-name "$LATEST_STREAM" \
            --region $REGION \
            --query 'events[*].message' \
            --output text
    else
        echo "⚠️ ログが見つかりませんでした"
    fi
fi