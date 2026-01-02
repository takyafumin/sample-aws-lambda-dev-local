import json
import boto3
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


def getBucketObjectNames():
    """S3のバケット内のオブジェクト名を取得する

    Returns:
        array: バケットオブジェクト名の配列
    """
    try:
        access_key = os.getenv("ACCESS_KEY")
        secret_key = os.getenv("SECRET_KEY")
        bucket_name = os.getenv("BUCKET_NAME")

        if not access_key or not secret_key or not bucket_name:
            print("Error: Missing required environment variables")
            return []

        s3 = boto3.resource(
            "s3",
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
        )
        bucket = s3.Bucket(bucket_name)
        bucket_names = []
        for obj in bucket.objects.all():
            bucket_names.append(obj.key)
        return bucket_names

    except Exception as e:
        print(f"Error accessing S3: {str(e)}")
        return []


def lambda_handler(event, context):
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
    event = {}
    lambda_handler(event, None)
