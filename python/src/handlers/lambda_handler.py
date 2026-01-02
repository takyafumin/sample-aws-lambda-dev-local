import json
import boto3
import os
from typing import Any, Dict, List
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


def getBucketObjectNames() -> List[str]:
    """S3のバケット内のオブジェクト名を取得する

    Returns:
        array: バケットオブジェクト名の配列
    """
    try:
        # 環境変数の取得（推奨: S3_BUCKET_NAME, 後方互換: AWS_BUCKET_NAME）
        bucket_name = os.getenv("S3_BUCKET_NAME") or os.getenv("AWS_BUCKET_NAME")

        if not bucket_name:
            print("Error: Missing required environment variable (S3_BUCKET_NAME)")
            return []

        # Lambda環境の判定（AWS_LAMBDA_FUNCTION_NAMEが存在するかで判定）
        is_lambda_env = os.getenv("AWS_LAMBDA_FUNCTION_NAME") is not None

        if is_lambda_env:
            # Lambda実行環境: IAM Roleを使用（デフォルト認証）
            print("Running in Lambda environment - using IAM Role for S3 access")
            s3 = boto3.resource("s3")
        else:
            # ローカル開発環境: 明示的な認証情報を使用
            access_key = os.getenv("AWS_ACCESS_KEY_ID")
            secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")

            if access_key and secret_key:
                print(
                    "Running in local environment - using API credentials for S3 access"
                )
                s3 = boto3.resource(
                    "s3",
                    aws_access_key_id=access_key,
                    aws_secret_access_key=secret_key,
                )
            else:
                print(
                    "Local environment detected but no API credentials found - trying default credentials"
                )
                s3 = boto3.resource("s3")

        bucket = s3.Bucket(bucket_name)
        bucket_names = []
        for obj in bucket.objects.all():
            bucket_names.append(obj.key)
        return bucket_names

    except Exception as e:
        print(f"Error accessing S3: {str(e)}")
        return []


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """サンプルLambda関数

    Args:
        event (_type_): lambdaイベント
        context (_type_): コンテキスト

    Returns:
        _type_: _description_
    """

    print("Hello world!")

    # Call the function to get bucket names
    bucket_names = getBucketObjectNames()
    print(f"Bucket names: {bucket_names}")

    return {"statusCode": 200, "body": json.dumps({"bucket_names": bucket_names})}


if __name__ == "__main__":
    event: Dict[str, Any] = {}
    lambda_handler(event, None)
