#!/bin/bash

# AWS Lambda デプロイメント共通ユーティリティ関数

source "$(dirname "${BASH_SOURCE[0]}")/../config/settings.sh"

# 関数: プラットフォーム判定とDockerプラットフォーム設定
detect_platform() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "🍎 macOSを検出しました"
        if [[ "$(uname -m)" == "arm64" ]]; then
            echo "🔧 Apple Silicon (M1/M2/M3) を検出しました - x86_64プラットフォームでビルドします"
            export DOCKER_PLATFORM="--platform linux/amd64"
        else
            echo "🔧 Intel Macを検出しました"
            export DOCKER_PLATFORM=""
        fi
    else
        echo "🐧 Linux環境を検出しました"
        export DOCKER_PLATFORM=""
    fi
}

# 関数: 必要なコマンドの存在確認
check_required_commands() {
    local commands=("$@")
    local missing_commands=()
    
    echo "🔍 必要なツールの確認中..."
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        echo "${LOG_PREFIX_ERROR} 以下のツールが見つかりません:"
        for cmd in "${missing_commands[@]}"; do
            echo "   - $cmd"
        done
        
        if [[ "$(uname)" == "Darwin" ]]; then
            echo "${LOG_PREFIX_INFO} Homebrewでインストールしてください:"
            for cmd in "${missing_commands[@]}"; do
                case $cmd in
                    "docker")
                        echo "   brew install --cask docker"
                        ;;
                    "aws")
                        echo "   brew install awscli"
                        ;;
                    *)
                        echo "   brew install $cmd"
                        ;;
                esac
            done
        else
            echo "${LOG_PREFIX_INFO} パッケージマネージャーでインストールしてください"
        fi
        return 1
    fi
    
    echo "${LOG_PREFIX_SUCCESS} 必要なツールが全て利用可能です"
    return 0
}

# 関数: AWS認証情報の確認
verify_aws_credentials() {
    echo "🔐 AWS認証情報を確認しています..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "${LOG_PREFIX_ERROR} AWS認証情報が設定されていません"
        echo "${LOG_PREFIX_INFO} 以下のコマンドでAWS CLIを設定してください:"
        echo "   aws configure"
        echo "   または AWS_PROFILE環境変数を設定してください"
        return 1
    fi
    
    local caller_identity=$(aws sts get-caller-identity --query 'Arn' --output text)
    echo "${LOG_PREFIX_SUCCESS} AWS認証情報を確認しました: $caller_identity"
    return 0
}

# 関数: Dockerイメージのビルド
build_docker_image() {
    local image_name="$1"
    local dockerfile_path="${2:-docker/Dockerfile}"
    
    echo "${LOG_PREFIX_DEPLOY} Dockerイメージをビルドしています..."
    
    if [[ -n "$DOCKER_PLATFORM" ]]; then
        echo "🏗️ クロスプラットフォームビルド: $DOCKER_PLATFORM"
    fi
    
    if command -v docker buildx &> /dev/null; then
        docker buildx build $DOCKER_PLATFORM -t "$image_name" -f "$dockerfile_path" . --load
    else
        docker build $DOCKER_PLATFORM -t "$image_name" -f "$dockerfile_path" .
    fi
    
    if [[ $? -eq 0 ]]; then
        echo "${LOG_PREFIX_SUCCESS} Dockerイメージのビルドが完了しました: $image_name"
        return 0
    else
        echo "${LOG_PREFIX_ERROR} Dockerイメージのビルドに失敗しました"
        return 1
    fi
}

# 関数: Dockerイメージの存在確認
check_docker_image() {
    local image_name="$1"
    
    echo "🔍 Dockerイメージの存在を確認しています..."
    
    if docker image inspect "${image_name}:latest" &> /dev/null; then
        echo "${LOG_PREFIX_SUCCESS} Dockerイメージが存在しています: ${image_name}:latest"
        return 0
    else
        echo "${LOG_PREFIX_WARNING} Dockerイメージが見つかりません: ${image_name}:latest"
        return 1
    fi
}

# 関数: テストイベントファイルの作成
create_test_event_file() {
    local event_file="$1"
    local test_mode="$2"
    
    if [[ -f "$event_file" ]]; then
        return 0
    fi
    
    echo "📝 テストイベントファイルを作成しています: $event_file"
    
    # ディレクトリが存在しない場合は作成
    mkdir -p "$(dirname "$event_file")"
    
    if [[ "$test_mode" == "remote" ]]; then
        cat > "$event_file" << 'EOF'
{
    "test_mode": "remote",
    "message": "Hello from remote Lambda test",
    "environment": "production",
    "timestamp": "2026-01-02T00:00:00Z"
}
EOF
    else
        cat > "$event_file" << 'EOF'
{
    "test_mode": "local",
    "message": "Hello from local test",
    "timestamp": "2026-01-02T00:00:00Z"
}
EOF
    fi
    
    echo "${LOG_PREFIX_SUCCESS} テストイベントファイルを作成しました: $event_file"
}

# 関数: AWS環境変数の確認
check_aws_environment_variables() {
    local required_vars=("$@")
    local missing_vars=()
    
    echo "🔍 必要なAWS環境変数の確認中..."
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "${LOG_PREFIX_WARNING} 以下のAWS標準環境変数が設定されていません:"
        for var in "${missing_vars[@]}"; do
            echo "   - $var"
        done
        echo ""
        echo "${LOG_PREFIX_INFO} 以下のいずれかの方法で環境変数を設定してください:"
        echo "   1. .envファイルを作成してください:"
        echo "      AWS_ACCESS_KEY_ID=your_access_key"
        echo "      AWS_SECRET_ACCESS_KEY=your_secret_key"
        echo "      S3_BUCKET_NAME=your_bucket_name"
        echo ""
        echo "   2. 環境変数として設定してください:"
        echo "      export AWS_ACCESS_KEY_ID=your_access_key"
        echo "      export AWS_SECRET_ACCESS_KEY=your_secret_key"
        echo "      export S3_BUCKET_NAME=your_bucket_name"
        echo ""
        return 1
    else
        echo "${LOG_PREFIX_SUCCESS} 必要なAWS標準環境変数が設定されています"
        return 0
    fi
}

# 関数: ユーザーの確認を取る
confirm_action() {
    local message="$1"
    local default_response="${2:-N}"
    local auto_confirm="${3:-false}"
    
    echo "$message"
    
    if [[ "$auto_confirm" == true ]]; then
        echo "🚀 自動実行オプションが指定されているため、自動的に実行します"
        return 0
    fi
    
    local prompt="(y/N)"
    if [[ "$default_response" == "Y" ]]; then
        prompt="(Y/n)"
    fi
    
    echo "🤔 $prompt"
    read -r response
    
    if [[ "$default_response" == "Y" ]]; then
        if [[ "$response" =~ ^[Nn]$ ]]; then
            return 1
        else
            return 0
        fi
    else
        if [[ "$response" =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# 関数: CloudWatch Logs URLの生成
generate_cloudwatch_url() {
    local region="$1"
    local log_group="$2"
    local log_stream="$3"
    
    local log_stream_encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$log_stream', safe=''))" 2>/dev/null || echo "$log_stream")
    local log_group_encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$log_group', safe=''))" 2>/dev/null || echo "$log_group")
    
    echo "https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/${log_group_encoded}/log-events/${log_stream_encoded}"
}

# 関数: JSONの整形出力
format_json_output() {
    local json_content="$1"
    
    echo "$json_content" | python3 -m json.tool 2>/dev/null || echo "$json_content"
}