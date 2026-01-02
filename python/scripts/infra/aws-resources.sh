#!/bin/bash

# AWS インフラストラクチャ管理スクリプト

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

# 関数: ECRリポジトリの存在確認・作成
ensure_ecr_repository() {
    local repository_name="$1"
    local region="$2"
    
    echo "🗂️ ECRリポジトリを確認しています..."
    
    if aws ecr describe-repositories --repository-names "$repository_name" --region "$region" &> /dev/null; then
        echo "${LOG_PREFIX_SUCCESS} ECRリポジトリが存在しています: $repository_name"
        return 0
    else
        echo "📁 ECRリポジトリを作成しています: $repository_name"
        
        aws ecr create-repository \
            --repository-name "$repository_name" \
            --region "$region" \
            --image-scanning-configuration scanOnPush=true
        
        if [[ $? -eq 0 ]]; then
            echo "${LOG_PREFIX_SUCCESS} ECRリポジトリを作成しました: $repository_name"
            return 0
        else
            echo "${LOG_PREFIX_ERROR} ECRリポジトリの作成に失敗しました: $repository_name"
            return 1
        fi
    fi
}

# 関数: ECRにログイン
login_to_ecr() {
    local region="$1"
    local ecr_uri="$2"
    
    echo "🔐 ECRにログインしています..."
    
    aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$ecr_uri"
    
    if [[ $? -eq 0 ]]; then
        echo "${LOG_PREFIX_SUCCESS} ECRへのログインが成功しました"
        return 0
    else
        echo "${LOG_PREFIX_ERROR} ECRへのログインに失敗しました"
        return 1
    fi
}

# 関数: Dockerイメージをタグ付けしてECRにプッシュ
push_image_to_ecr() {
    local local_image_name="$1"
    local ecr_repository_uri="$2"
    local tag="${3:-latest}"
    
    echo "📤 ECRにイメージをプッシュしています..."
    
    # イメージにタグ付け
    docker tag "${local_image_name}:latest" "${ecr_repository_uri}:${tag}"
    
    if [[ $? -ne 0 ]]; then
        echo "${LOG_PREFIX_ERROR} イメージのタグ付けに失敗しました"
        return 1
    fi
    
    # ECRにプッシュ
    docker push "${ecr_repository_uri}:${tag}"
    
    if [[ $? -eq 0 ]]; then
        echo "${LOG_PREFIX_SUCCESS} ECRへのイメージプッシュが完了しました: ${ecr_repository_uri}:${tag}"
        return 0
    else
        echo "${LOG_PREFIX_ERROR} ECRへのイメージプッシュに失敗しました"
        return 1
    fi
}

# 関数: Lambda実行ロールの存在確認・作成
ensure_lambda_execution_role() {
    local role_name="$1"
    local account_id="$2"
    
    echo "👤 Lambda実行ロールを確認しています: $role_name"
    
    if aws iam get-role --role-name "$role_name" &> /dev/null; then
        echo "${LOG_PREFIX_SUCCESS} Lambda実行ロールが存在しています: $role_name"
        return 0
    fi
    
    echo "🆕 Lambda実行ロールを作成しています: $role_name"
    
    # 信頼関係ドキュメントを作成
    local trust_policy_file="/tmp/lambda-trust-policy-$$.json"
    cat > "$trust_policy_file" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    # ロールを作成
    if ! aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "file://$trust_policy_file"; then
        echo "${LOG_PREFIX_ERROR} Lambda実行ロールの作成に失敗しました"
        rm -f "$trust_policy_file"
        return 1
    fi
    
    # 基本実行ポリシーをアタッチ
    aws iam attach-role-policy \
        --role-name "$role_name" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    # S3読み取り専用ポリシーをアタッチ
    aws iam attach-role-policy \
        --role-name "$role_name" \
        --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
    
    # 一時ファイルを削除
    rm -f "$trust_policy_file"
    
    echo "${LOG_PREFIX_SUCCESS} Lambda実行ロールを作成しました: $role_name"
    echo "⏳ ロールの反映を待機しています..."
    sleep 10
    
    return 0
}

# 関数: Lambda関数の存在確認
check_lambda_function_exists() {
    local function_name="$1"
    local region="$2"
    
    aws lambda get-function --function-name "$function_name" --region "$region" &> /dev/null
}

# 関数: Lambda関数の作成
create_lambda_function() {
    local function_name="$1"
    local image_uri="$2"
    local role_arn="$3"
    local region="$4"
    local environment_vars="$5"
    local timeout="${6:-$DEFAULT_TIMEOUT}"
    local memory_size="${7:-$DEFAULT_MEMORY_SIZE}"
    
    echo "🆕 Lambda関数を作成しています: $function_name"
    
    local create_cmd="aws lambda create-function \
        --function-name $function_name \
        --package-type Image \
        --code ImageUri=$image_uri \
        --role $role_arn \
        --region $region \
        --timeout $timeout \
        --memory-size $memory_size"
    
    # 環境変数が指定されている場合は追加
    if [[ -n "$environment_vars" ]]; then
        create_cmd="$create_cmd --environment \"Variables={$environment_vars}\""
    fi
    
    # コマンドを実行
    eval "$create_cmd"
    
    if [[ $? -eq 0 ]]; then
        echo "${LOG_PREFIX_SUCCESS} Lambda関数を作成しました: $function_name"
        return 0
    else
        echo "${LOG_PREFIX_ERROR} Lambda関数の作成に失敗しました: $function_name"
        return 1
    fi
}

# 関数: Lambda関数のコード更新
update_lambda_function_code() {
    local function_name="$1"
    local image_uri="$2"
    local region="$3"
    
    echo "🔄 Lambda関数のコードを更新しています: $function_name"
    
    aws lambda update-function-code \
        --function-name "$function_name" \
        --image-uri "$image_uri" \
        --region "$region"
    
    if [[ $? -eq 0 ]]; then
        echo "${LOG_PREFIX_SUCCESS} Lambda関数のコード更新が完了しました: $function_name"
        return 0
    else
        echo "${LOG_PREFIX_ERROR} Lambda関数のコード更新に失敗しました: $function_name"
        return 1
    fi
}

# 関数: Lambda関数の環境変数更新
update_lambda_function_environment() {
    local function_name="$1"
    local region="$2"
    local environment_vars="$3"
    
    if [[ -z "$environment_vars" ]]; then
        echo "${LOG_PREFIX_WARNING} 環境変数が設定されていないため、環境変数の更新をスキップします"
        return 0
    fi
    
    echo "🔧 Lambda関数の環境変数を更新しています..."
    
    aws lambda update-function-configuration \
        --function-name "$function_name" \
        --region "$region" \
        --environment "Variables={$environment_vars}"
    
    if [[ $? -eq 0 ]]; then
        echo "${LOG_PREFIX_SUCCESS} Lambda関数の環境変数を更新しました"
        return 0
    else
        echo "${LOG_PREFIX_ERROR} Lambda関数の環境変数の更新に失敗しました"
        return 1
    fi
}

# 関数: Lambda関数の呼び出し
invoke_lambda_function() {
    local function_name="$1"
    local region="$2"
    local event_file="$3"
    local output_file="$4"
    
    echo "🚀 Lambda関数を呼び出しています: $function_name"
    echo "   Event: $event_file"
    echo "   Output: $output_file"
    
    aws lambda invoke \
        --function-name "$function_name" \
        --region "$region" \
        --payload "file://$event_file" \
        --cli-binary-format raw-in-base64-out \
        "$output_file"
    
    return $?
}

# 関数: 最新のCloudWatch Logsストリームを取得
get_latest_log_stream() {
    local log_group="$1"
    local region="$2"
    
    aws logs describe-log-streams \
        --log-group-name "$log_group" \
        --region "$region" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null
}