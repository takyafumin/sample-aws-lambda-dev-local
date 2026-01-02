#!/bin/bash

# AWS Lambda 関数のデプロイスクリプト (リファクタリング版)

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリの読み込み
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/infra/aws-resources.sh"

# コマンドライン引数の処理
AUTO_CREATE_FUNCTION=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-create|-a)
            AUTO_CREATE_FUNCTION=true
            shift
            ;;
        --help|-h)
            echo "AWS Lambda デプロイスクリプト"
            echo ""
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "オプション:"
            echo "  --auto-create, -a    Lambda関数が存在しない場合、自動的に作成"
            echo "  --help, -h          このヘルプメッセージを表示"
            echo ""
            echo "必要な環境変数:"
            echo "  FUNCTION_NAME       Lambda関数名 (デフォルト: aws-sample-lambda)"
            echo "  AWS_DEFAULT_REGION  AWSリージョン (デフォルト: ap-northeast-1)"
            echo "  S3_BUCKET_NAME      S3バケット名 (オプション)"
            exit 0
            ;;
        *)
            echo "❓ 未知のオプション: $1"
            echo "💡 使用方法: $0 [--auto-create | -a] [--help | -h]"
            exit 1
            ;;
    esac
done

# メイン処理開始
echo "${LOG_PREFIX_DEPLOY} AWS Lambda デプロイを開始します..."
echo ""

# .envファイルから環境変数を読み込み
load_env_file

# 設定の読み込みと表示
load_configuration
display_configuration
echo ""

# プラットフォーム判定
detect_platform
echo ""

# 必要なツールの確認
if ! check_required_commands "docker" "aws"; then
    exit 1
fi
echo ""

# AWS認証情報の確認
if ! verify_aws_credentials; then
    exit 1
fi
echo ""

# Dockerイメージのビルド
if ! build_docker_image "$DOCKER_IMAGE_NAME" "docker/Dockerfile"; then
    exit 1
fi
echo ""

# ECRリポジトリの存在確認・作成
if ! ensure_ecr_repository "$ECR_REPOSITORY_NAME" "$REGION"; then
    exit 1
fi
echo ""

# ECRにログイン
if ! login_to_ecr "$REGION" "$ECR_REPOSITORY_URI"; then
    exit 1
fi
echo ""

# ECRにプッシュ
if ! push_image_to_ecr "$DOCKER_IMAGE_NAME" "$ECR_REPOSITORY_URI" "latest"; then
    exit 1
fi

# ECRプッシュ後の待機（Lambda関数が自動的に新しいイメージを参照する可能性があるため）
echo "⏳ ECRプッシュ完了後、Lambda関数の安定化を待機中..."
sleep 10
echo ""

# Lambda関数の存在確認とデプロイ
echo "🔍 Lambda関数の存在を確認しています..."
if check_lambda_function_exists "$FUNCTION_NAME" "$REGION"; then
    echo "${LOG_PREFIX_SUCCESS} Lambda関数が存在しています。コードを更新します..."
    
    # Lambda関数のコード更新
    if ! update_lambda_function_code "$FUNCTION_NAME" "$ECR_REPOSITORY_URI:latest" "$REGION"; then
        exit 1
    fi
    
    # 環境変数の更新
    env_vars=""
    if [[ -n "$LAMBDA_BUCKET_NAME" ]]; then
        env_vars="S3_BUCKET_NAME=$LAMBDA_BUCKET_NAME"
    fi
    if ! update_lambda_function_environment "$FUNCTION_NAME" "$REGION" "$env_vars"; then
        exit 1
    fi
    
else
    echo "${LOG_PREFIX_ERROR} Lambda関数が存在しません: $FUNCTION_NAME"
    echo "${LOG_PREFIX_INFO} Lambda関数を作成してください:"
    echo "   aws lambda create-function \\"
    echo "       --function-name $FUNCTION_NAME \\"
    echo "       --package-type Image \\"
    echo "       --code ImageUri=$ECR_REPOSITORY_URI:latest \\"
    echo "       --role $ROLE_ARN \\"
    echo "       --region $REGION"
    echo ""
    
    if confirm_action "🤔 Lambda関数を自動作成しますか？ (y/N)" "N" "$AUTO_CREATE_FUNCTION"; then
        # 実行ロールの確認・作成
        if ! ensure_lambda_execution_role "$LAMBDA_ROLE_NAME" "$ACCOUNT_ID"; then
            exit 1
        fi
        
        # 環境変数の準備
        env_vars=""
        if [[ -n "$LAMBDA_BUCKET_NAME" ]]; then
            env_vars="S3_BUCKET_NAME=$LAMBDA_BUCKET_NAME"
        fi
        
        # Lambda関数を作成
        if ! create_lambda_function "$FUNCTION_NAME" "$ECR_REPOSITORY_URI:latest" "$ROLE_ARN" "$REGION" "$env_vars" "$DEFAULT_TIMEOUT" "$DEFAULT_MEMORY_SIZE"; then
            exit 1
        fi
    else
        echo "⏭️ Lambda関数の作成をスキップしました"
        exit 0
    fi
fi

echo ""
echo "🎉 デプロイが完了しました！"
echo "📋 デプロイ情報:"
echo "   Function Name: $FUNCTION_NAME"
echo "   Region: $REGION"
echo "   ECR Repository: $ECR_REPOSITORY_URI"
echo "   Image Tag: latest"
if [[ -n "$LAMBDA_BUCKET_NAME" ]]; then
    echo "   S3 Bucket: $LAMBDA_BUCKET_NAME"
fi
echo ""
echo "${LOG_PREFIX_INFO} Lambda関数をテストするには:"
echo "   ./scripts/test-remote.sh"
echo "   または"
echo "   aws lambda invoke --function-name $FUNCTION_NAME --region $REGION response.json"