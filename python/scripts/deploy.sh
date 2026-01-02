#!/bin/bash

# AWS Lambda 関数のデプロイスクリプト

set -e

# 変数設定
FUNCTION_NAME="aws-sample-lambda"
REGION="ap-northeast-1"
DOCKER_IMAGE_NAME="aws-lambda-python-sample"

echo "🚀 Lambda関数のデプロイを開始します..."

# Dockerイメージのビルド
echo "📦 Dockerイメージをビルドしています..."
docker build -t $DOCKER_IMAGE_NAME -f docker/Dockerfile .

# ECRにプッシュ（必要に応じて）
# echo "📤 ECRにイメージをプッシュしています..."
# docker tag $DOCKER_IMAGE_NAME:latest $ECR_REPOSITORY_URI:latest
# docker push $ECR_REPOSITORY_URI:latest

# Lambda関数の更新
echo "🔄 Lambda関数を更新しています..."
# aws lambda update-function-code \
#     --function-name $FUNCTION_NAME \
#     --image-uri $ECR_REPOSITORY_URI:latest \
#     --region $REGION

echo "✅ デプロイが完了しました！"