import pytest
import json
from unittest.mock import patch, MagicMock
import sys
import os

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from handlers.lambda_handler import lambda_handler, getBucketObjectNames


class TestLambdaHandler:
    """Lambda Handler のテスト"""

    @patch("handlers.lambda_handler.boto3.resource")
    def test_lambda_handler_success(self, mock_boto_resource):
        """Lambda Handler の正常ケースのテスト"""
        # Mock S3 resource
        mock_bucket = MagicMock()
        mock_obj = MagicMock()
        mock_obj.key = "test-object.txt"
        mock_bucket.objects.all.return_value = [mock_obj]

        mock_s3 = MagicMock()
        mock_s3.Bucket.return_value = mock_bucket
        mock_boto_resource.return_value = mock_s3

        # Test event
        event = {}
        context = None

        # Execute
        result = lambda_handler(event, context)

        # Assert
        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert "bucket_names" in body


class TestGetBucketObjectNames:
    """getBucketObjectNames 関数のテスト"""

    @patch.dict(
        os.environ,
        {
            "ACCESS_KEY": "test-access-key",
            "SECRET_KEY": "test-secret-key",
            "BUCKET_NAME": "test-bucket",
        },
    )
    @patch("handlers.lambda_handler.boto3.resource")
    def test_get_bucket_object_names_success(self, mock_boto_resource):
        """正常ケースのテスト"""
        # Mock setup
        mock_bucket = MagicMock()
        mock_obj = MagicMock()
        mock_obj.key = "test-file.txt"
        mock_bucket.objects.all.return_value = [mock_obj]

        mock_s3 = MagicMock()
        mock_s3.Bucket.return_value = mock_bucket
        mock_boto_resource.return_value = mock_s3

        # Execute
        result = getBucketObjectNames()

        # Assert
        assert result == ["test-file.txt"]
        mock_boto_resource.assert_called_once_with(
            "s3",
            aws_access_key_id="test-access-key",
            aws_secret_access_key="test-secret-key",
        )
