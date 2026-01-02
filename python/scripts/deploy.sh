#!/bin/bash

# AWS Lambda 関数のデプロイスクリプト (macOS対応)

set -e

# コマンドライン引数の処理
AUTO_CREATE_FUNCTION=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-create|-a)
            AUTO_CREATE_FUNCTION=true
            shift
            ;;
        *)
            echo "❓ 未知のオプション: $1"
            echo "💡 使用方法: $0 [--auto-create | -a]"
            exit 1
            ;;
    esac
done

# 変数設定
FUNCTION_NAME="${FUNCTION_NAME:-aws-sample-lambda}"
REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}"
DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-aws-lambda-python-sample}"
ACCOUNT_ID="${AWS_ACCOUNT_ID}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-aws-lambda-python-sample}"

echo "📋 デプロイ設定の確認..."
echo "   Function Name: $FUNCTION_NAME"
echo "   Region: $REGION"
echo "   Docker Image: $DOCKER_IMAGE_NAME"
echo "   ECR Repository: $ECR_REPOSITORY_NAME"

# Lambda環境変数の確認
if [[ -n "$AWS_BUCKET_NAME" ]] || [[ -n "$S3_BUCKET_NAME" ]]; then
    echo "   S3バケット名: 設定済み ✅"
    LAMBDA_BUCKET_NAME="${S3_BUCKET_NAME:-$AWS_BUCKET_NAME}"
else
    echo "   S3バケット名: 未設定 ⚠️"
    echo "   💡 Lambda関数でS3にアクセスする場合は以下の環境変数を設定してください:"
    echo "      export S3_BUCKET_NAME=your-bucket-name"
    echo "   注意: IAM Roleによる認証を使用します（APIキーは不要）"
    LAMBDA_BUCKET_NAME=""
fi

# AWS Account IDを取得（環境変数で設定されていない場合）
if [[ -z "$ACCOUNT_ID" ]]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

ECR_REPOSITORY_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"

# macOS対応: Apple Silicon (M1/M2) チェック
if [[ "$(uname)" == "Darwin" ]]; then
    echo "🍎 macOSを検出しました"
    if [[ "$(uname -m)" == "arm64" ]]; then
        echo "🔧 Apple Silicon (M1/M2) を検出しました - x86_64プラットフォームでビルドします"
        DOCKER_PLATFORM="--platform linux/amd64"
    else
        echo "🔧 Intel Macを検出しました"
        DOCKER_PLATFORM=""
    fi
else
    echo "🐧 Linux環境を検出しました"
    DOCKER_PLATFORM=""
fi

# 必要ツールの存在確認
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 が見つかりません"
        if [[ "$(uname)" == "Darwin" ]]; then
            echo "💡 Homebrewでインストールしてください: brew install $2"
        else
            echo "💡 パッケージマネージャーでインストールしてください"
        fi
        exit 1
    fi
}

echo "🔍 必要なツールの確認中..."
check_command "docker" "docker"
check_command "aws" "awscli"

# AWS認証情報の確認
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS認証情報が設定されていません"
    echo "💡 以下のコマンドでAWS CLIを設定してください:"
    echo "   aws configure"
    echo "   または AWS_PROFILE環境変数を設定してください"
    exit 1
fi

echo "✅ AWS認証情報を確認しました: $(aws sts get-caller-identity --query 'Arn' --output text)"

echo "🚀 Lambda関数のデプロイを開始します..."

# Dockerイメージのビルド
echo "📦 Dockerイメージをビルドしています..."
if [[ -n "$DOCKER_PLATFORM" ]]; then
    echo "🏗️ クロスプラットフォームビルド: $DOCKER_PLATFORM"
fi

docker buildx build $DOCKER_PLATFORM -t $DOCKER_IMAGE_NAME -f docker/Dockerfile . --load

# ECRリポジトリの存在確認・作成
echo "🗂️ ECRリポジトリを確認しています..."
if ! aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $REGION &> /dev/null; then
    echo "📁 ECRリポジトリを作成しています: $ECR_REPOSITORY_NAME"
    aws ecr create-repository \
        --repository-name $ECR_REPOSITORY_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true
    echo "✅ ECRリポジトリを作成しました"
else
    echo "✅ ECRリポジトリが存在しています: $ECR_REPOSITORY_NAME"
fi

# ECRにログイン
echo "🔐 ECRにログインしています..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI

# ECRにプッシュ
echo "📤 ECRにイメージをプッシュしています..."
docker tag $DOCKER_IMAGE_NAME:latest $ECR_REPOSITORY_URI:latest
docker push $ECR_REPOSITORY_URI:latest

# Lambda関数の存在確認
echo "🔍 Lambda関数の存在を確認しています..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &> /dev/null; then
    echo "✅ Lambda関数が存在しています。コードを更新します..."
    # Lambda関数の更新
    echo "🔄 Lambda関数を更新しています..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --image-uri $ECR_REPOSITORY_URI:latest \
        --region $REGION
    
    # 環境変数の設定
    echo "🔧 Lambda関数の環境変数を更新しています..."
    if [[ -n "$LAMBDA_BUCKET_NAME" ]]; then
        aws lambda update-function-configuration \
            --function-name $FUNCTION_NAME \
            --region $REGION \
            --environment "Variables={S3_BUCKET_NAME=$LAMBDA_BUCKET_NAME}"
    else
        echo "   ⚠️ S3バケット名が設定されていないため、環境変数の更新をスキップします"
    fi
else
    echo "❌ Lambda関数が存在しません: $FUNCTION_NAME"
    echo "💡 Lambda関数を作成してください:"
    echo "   aws lambda create-function \\"
    echo "       --function-name $FUNCTION_NAME \\"
    echo "       --package-type Image \\"
    echo "       --code ImageUri=$ECR_REPOSITORY_URI:latest \\"
    echo "       --role arn:aws:iam::$ACCOUNT_ID:role/lambda-execution-role \\"
    echo "       --region $REGION"
    echo ""
    echo "🤔 Lambda関数を自動作成しますか？ (y/N)"
    
    if [[ "$AUTO_CREATE_FUNCTION" == true ]]; then
        echo "🚀 --auto-create オプションが指定されているため、自動的に関数を作成します"
        response="y"
    else
        read -r response
    fi
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🆕 Lambda関数を作成しています..."
        
        # 実行ロールの確認・作成
        ROLE_NAME="lambda-execution-role"
        ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
        
        if ! aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
            echo "👤 Lambda実行ロールを作成しています..."
            # 信頼関係ドキュメント
            cat > /tmp/trust-policy.json << EOF
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
            aws iam create-role \
                --role-name $ROLE_NAME \
                --assume-role-policy-document file:///tmp/trust-policy.json
            
            # 基本実行ポリシーをアタッチ
            aws iam attach-role-policy \
                --role-name $ROLE_NAME \
                --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
            
            # S3アクセスポリシーをアタッチ
            aws iam attach-role-policy \
                --role-name $ROLE_NAME \
                --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
            
            rm /tmp/trust-policy.json
            echo "✅ Lambda実行ロールを作成しました"
            
            # ロールが反映されるまで少し待機
            echo "⏳ ロールの反映を待機しています..."
            sleep 10
        else
            echo "✅ Lambda実行ロールが存在しています"
        fi
        
        # Lambda関数を作成
        if [[ -n "$LAMBDA_BUCKET_NAME" ]]; then
            aws lambda create-function \
                --function-name $FUNCTION_NAME \
                --package-type Image \
                --code ImageUri=$ECR_REPOSITORY_URI:latest \
                --role $ROLE_ARN \
                --region $REGION \
                --timeout 30 \
                --memory-size 512 \
                --environment "Variables={S3_BUCKET_NAME=$LAMBDA_BUCKET_NAME}"
        else
            aws lambda create-function \
                --function-name $FUNCTION_NAME \
                --package-type Image \
                --code ImageUri=$ECR_REPOSITORY_URI:latest \
                --role $ROLE_ARN \
                --region $REGION \
                --timeout 30 \
                --memory-size 512
        fi
        echo "✅ Lambda関数を作成しました"
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
echo ""
echo "💡 Lambda関数をテストするには:"
echo "   aws lambda invoke --function-name $FUNCTION_NAME --region $REGION response.json"