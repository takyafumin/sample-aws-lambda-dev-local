#!/bin/bash

# AWS Lambda デプロイメント設定ファイル

# Lambda関数設定
DEFAULT_FUNCTION_NAME="aws-sample-lambda"
DEFAULT_REGION="ap-northeast-1"
DEFAULT_TIMEOUT=30
DEFAULT_MEMORY_SIZE=512

# Docker設定
DEFAULT_DOCKER_IMAGE_NAME="aws-lambda-python-sample"

# ECR設定
DEFAULT_ECR_REPOSITORY_NAME="aws-lambda-python-sample"

# IAM設定
DEFAULT_LAMBDA_ROLE_NAME="lambda-execution-role"

# ファイルパス設定
DEFAULT_TEST_EVENT_LOCAL="resources/events/test_event.json"
DEFAULT_TEST_EVENT_REMOTE="resources/events/test_event_remote.json"

# Lambda Runtime Interface Emulator設定
LAMBDA_RIE_PORT=9000
LAMBDA_HEALTHCHECK_RETRIES=10
LAMBDA_STARTUP_WAIT=5

# Logging設定
LOG_PREFIX_DEPLOY="📦"
LOG_PREFIX_TEST="🧪"
LOG_PREFIX_INFRA="🏗️"
LOG_PREFIX_SUCCESS="✅"
LOG_PREFIX_WARNING="⚠️"
LOG_PREFIX_ERROR="❌"
LOG_PREFIX_INFO="💡"

# 関数: 環境変数の設定とデフォルト値の適用
load_configuration() {
    # 基本設定
    export FUNCTION_NAME="${FUNCTION_NAME:-$DEFAULT_FUNCTION_NAME}"
    export REGION="${AWS_DEFAULT_REGION:-$DEFAULT_REGION}"
    export DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-$DEFAULT_DOCKER_IMAGE_NAME}"
    export ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-$DEFAULT_ECR_REPOSITORY_NAME}"
    export LAMBDA_ROLE_NAME="${LAMBDA_ROLE_NAME:-$DEFAULT_LAMBDA_ROLE_NAME}"
    
    # AWSアカウントIDを取得
    if [[ -z "$ACCOUNT_ID" ]]; then
        export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    fi
    
    # ECRリポジトリURIを構築
    if [[ -n "$ACCOUNT_ID" ]]; then
        export ECR_REPOSITORY_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
    fi
    
    # S3バケット名の設定（後方互換性対応）
    if [[ -n "$AWS_BUCKET_NAME" ]] && [[ -z "$S3_BUCKET_NAME" ]]; then
        export S3_BUCKET_NAME="$AWS_BUCKET_NAME"
    fi
    export LAMBDA_BUCKET_NAME="${S3_BUCKET_NAME}"
    
    # IAM Role ARNを構築
    if [[ -n "$ACCOUNT_ID" ]]; then
        export ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"
    fi
    
    # テストイベントファイルパス
    export TEST_EVENT_LOCAL="${TEST_EVENT_LOCAL:-$DEFAULT_TEST_EVENT_LOCAL}"
    export TEST_EVENT_REMOTE="${TEST_EVENT_REMOTE:-$DEFAULT_TEST_EVENT_REMOTE}"
}

# 関数: 設定情報の表示
display_configuration() {
    echo "${LOG_PREFIX_INFO} 現在の設定:"
    echo "   Function Name: $FUNCTION_NAME"
    echo "   Region: $REGION"
    echo "   Docker Image: $DOCKER_IMAGE_NAME"
    echo "   ECR Repository: $ECR_REPOSITORY_NAME"
    if [[ -n "$S3_BUCKET_NAME" ]]; then
        echo "   S3バケット名: $S3_BUCKET_NAME ${LOG_PREFIX_SUCCESS}"
    else
        echo "   S3バケット名: 未設定 ${LOG_PREFIX_WARNING}"
        echo "   ${LOG_PREFIX_INFO} Lambda関数でS3にアクセスする場合は以下の環境変数を設定してください:"
        echo "      export S3_BUCKET_NAME=your-bucket-name"
    fi
    if [[ -n "$ACCOUNT_ID" ]]; then
        echo "   AWS Account ID: $ACCOUNT_ID"
        echo "   ECR Repository URI: $ECR_REPOSITORY_URI"
        echo "   IAM Role ARN: $ROLE_ARN"
    fi
}

# .envファイルから環境変数を読み込み
load_env_file() {
    local env_file=".env"
    if [[ -f "$env_file" ]]; then
        echo "${LOG_PREFIX_INFO} .envファイルから環境変数を読み込んでいます..."
        set -a  # 自動的にエクスポート
        source "$env_file"
        set +a
        echo "${LOG_PREFIX_SUCCESS} .envファイルから環境変数を読み込みました"
    else
        echo "${LOG_PREFIX_WARNING} .envファイルが見つかりません"
    fi
}