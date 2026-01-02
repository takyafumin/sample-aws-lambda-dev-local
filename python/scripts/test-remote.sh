#!/bin/bash

# Lambda関数のリモートテストスクリプト (リファクタリング版)

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリの読み込み
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/infra/aws-resources.sh"

# コマンドライン引数の処理
TEST_EVENT="${1:-$DEFAULT_TEST_EVENT_REMOTE}"
OUTPUT_FILE="${2:-response.json}"

# メイン処理開始
echo "☁️ リモートLambda関数のテストを開始します..."
echo ""

# 設定の読み込み
load_configuration
echo ""

# AWS認証情報の確認
if ! verify_aws_credentials; then
    exit 1
fi
echo ""

# Lambda関数の存在確認
echo "🔍 Lambda関数の存在を確認しています..."
if ! check_lambda_function_exists "$FUNCTION_NAME" "$REGION"; then
    echo "${LOG_PREFIX_ERROR} Lambda関数が見つかりません: $FUNCTION_NAME"
    echo "${LOG_PREFIX_INFO} 先にデプロイを実行してください: ./scripts/deploy.sh"
    exit 1
fi
echo "${LOG_PREFIX_SUCCESS} Lambda関数が存在しています: $FUNCTION_NAME"
echo ""

# テストイベントファイルの存在確認・作成
create_test_event_file "$TEST_EVENT" "remote"
echo ""

# Lambda関数を実行
echo "🚀 Lambda関数を実行しています..."
echo "   Function: $FUNCTION_NAME"
echo "   Region: $REGION"
echo "   Event: $TEST_EVENT"
echo "   Output: $OUTPUT_FILE"
echo ""

if ! invoke_lambda_function "$FUNCTION_NAME" "$REGION" "$TEST_EVENT" "$OUTPUT_FILE"; then
    echo "${LOG_PREFIX_ERROR} Lambda関数の呼び出しに失敗しました"
    exit 1
fi

# 結果の表示
if [[ -f "$OUTPUT_FILE" ]]; then
    echo ""
    echo "📄 実行結果:"
    format_json_output "$(cat "$OUTPUT_FILE")"
    echo ""
    echo "${LOG_PREFIX_SUCCESS} Lambda関数のテストが完了しました！"
    
    # response.jsonファイルを削除
    rm -f "$OUTPUT_FILE"
else
    echo "${LOG_PREFIX_ERROR} レスポンスファイルが作成されませんでした"
    exit 1
fi

# ログの確認
echo ""
echo "📜 最新のログを確認しています..."
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

# 最新のログストリームを取得
LATEST_STREAM=$(get_latest_log_stream "$LOG_GROUP" "$REGION")

if [[ "$LATEST_STREAM" != "None" && -n "$LATEST_STREAM" && "$LATEST_STREAM" != "null" ]]; then
    echo "📋 最新のログストリーム: $LATEST_STREAM"
    # CloudWatch Logsコンソールへのリンクを生成
    CONSOLE_URL=$(generate_cloudwatch_url "$REGION" "$LOG_GROUP" "$LATEST_STREAM")
    echo "🔗 CloudWatch Logsで確認: $CONSOLE_URL"
else
    echo "${LOG_PREFIX_WARNING} ログストリームが見つかりませんでした"
    # 少し待機してから再試行
    echo "   ⏳ ログの反映を待機しています..."
    sleep 5
    
    LATEST_STREAM=$(get_latest_log_stream "$LOG_GROUP" "$REGION")
    
    if [[ "$LATEST_STREAM" != "None" && -n "$LATEST_STREAM" && "$LATEST_STREAM" != "null" ]]; then
        echo "📋 最新のログストリーム: $LATEST_STREAM"
        CONSOLE_URL=$(generate_cloudwatch_url "$REGION" "$LOG_GROUP" "$LATEST_STREAM")
        echo "🔗 CloudWatch Logsで確認: $CONSOLE_URL"
    else
        echo "${LOG_PREFIX_WARNING} ログが見つかりませんでした"
        echo "${LOG_PREFIX_INFO} Lambda関数のロググループを手動で確認: /aws/lambda/$FUNCTION_NAME"
    fi
fi