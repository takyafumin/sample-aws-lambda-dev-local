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

# 関数: Lambda関数の状態確認（更新可能かチェック）
wait_for_lambda_function_ready() {
    local function_name="$1"
    local region="$2"
    local max_attempts=60  # 最大10分待機
    local wait_seconds=10
    
    echo "⏳ Lambda関数の更新準備完了を待機中..."
    
    for attempt in $(seq 1 $max_attempts); do
        local function_info=$(aws lambda get-function-configuration \
            --function-name "$function_name" \
            --region "$region" \
            --query '{State: State, LastUpdateStatus: LastUpdateStatus, LastUpdateStatusReason: LastUpdateStatusReason}' \
            --output json 2>/dev/null)
        
        if [[ -z "$function_info" ]]; then
            echo "   試行 $attempt/$max_attempts: 関数情報の取得に失敗 - ${wait_seconds}秒待機中..."
            sleep $wait_seconds
            continue
        fi
        
        local state=$(echo "$function_info" | python3 -c "import sys, json; print(json.load(sys.stdin).get('State', 'Unknown'))" 2>/dev/null || echo "Unknown")
        local last_update_status=$(echo "$function_info" | python3 -c "import sys, json; print(json.load(sys.stdin).get('LastUpdateStatus', 'Unknown'))" 2>/dev/null || echo "Unknown")
        local update_reason=$(echo "$function_info" | python3 -c "import sys, json; print(json.load(sys.stdin).get('LastUpdateStatusReason', ''))" 2>/dev/null || echo "")
        
        # 正常状態の確認
        if [[ "$state" == "Active" ]] && [[ "$last_update_status" == "Successful" ]]; then
            echo "${LOG_PREFIX_SUCCESS} Lambda関数が更新可能な状態になりました"
            return 0
        fi
        
        # 失敗状態の確認
        if [[ "$last_update_status" == "Failed" ]]; then
            echo "${LOG_PREFIX_ERROR} Lambda関数の更新が失敗状態です: $update_reason"
            return 1
        fi
        
        # 進行中状態の表示
        if [[ "$state" == "Pending" ]] || [[ "$last_update_status" == "InProgress" ]]; then
            echo "   試行 $attempt/$max_attempts: 状態=${state}, 更新状況=${last_update_status} - ECRイメージ処理中の可能性 (${wait_seconds}秒待機)"
        else
            echo "   試行 $attempt/$max_attempts: 状態=${state}, 更新状況=${last_update_status} - ${wait_seconds}秒待機中..."
        fi
        
        sleep $wait_seconds
    done
    
    echo "${LOG_PREFIX_ERROR} Lambda関数が更新可能な状態になりませんでした（タイムアウト）"
    return 1
}

# 関数: Lambda関数の環境変数更新（リトライ機能付き）
update_lambda_function_environment() {
    local function_name="$1"
    local region="$2"
    local environment_vars="$3"
    local max_retries=5
    local retry_wait=5
    
    if [[ -z "$environment_vars" ]]; then
        echo "${LOG_PREFIX_WARNING} 環境変数が設定されていないため、環境変数の更新をスキップします"
        return 0
    fi
    
    echo "🔧 Lambda関数の環境変数を更新しています..."
    
    for retry in $(seq 1 $max_retries); do
        local update_result=$(aws lambda update-function-configuration \
            --function-name "$function_name" \
            --region "$region" \
            --environment "Variables={$environment_vars}" 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo "${LOG_PREFIX_SUCCESS} Lambda関数の環境変数を更新しました"
            return 0
        fi
        
        # ResourceConflictException の場合はリトライ
        if echo "$update_result" | grep -q "ResourceConflictException\|operation cannot be performed at this time"; then
            if [[ $retry -lt $max_retries ]]; then
                echo "${LOG_PREFIX_WARNING} リソース競合エラーが発生しました。${retry_wait}秒後にリトライします（試行 $retry/$max_retries）"
                sleep $retry_wait
                retry_wait=$((retry_wait * 2))  # 指数バックオフ
                continue
            else
                echo "${LOG_PREFIX_ERROR} 最大リトライ回数に達しました。Lambda関数の環境変数の更新に失敗しました"
                echo "$update_result"
                return 1
            fi
        else
            echo "${LOG_PREFIX_ERROR} Lambda関数の環境変数の更新に失敗しました"
            echo "$update_result"
            return 1
        fi
    done
    
    return 1
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