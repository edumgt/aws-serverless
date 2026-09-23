"""공개 S3 버킷을 관리하는 AWS Lambda 핸들러.

Lambda 핸들러: s3up3.lambda_handler

직접 호출 이벤트 예시:
    {"action": "upload", "key": "hello.txt", "content_base64": "aGVsbG8="}
    {"action": "list", "prefix": "images/"}
    {"action": "download", "key": "hello.txt"}
    {"action": "delete", "key": "hello.txt"}

API Gateway에서 호출할 때는 위 JSON을 요청 body로 보내거나 쿼리 파라미터로
전달할 수 있다. 모든 S3 요청은 AWS 자격 증명 없이 전송한다.
"""

import base64
import binascii
import json

import boto3
from boto3.exceptions import Boto3Error
from botocore import UNSIGNED
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError


BUCKET = "public-crud-100kb-086015456585"
REGION = "ap-northeast-2"


def _response(status_code, data):
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json; charset=utf-8"},
        "body": json.dumps(data, ensure_ascii=False),
    }


def _params(event):
    if not isinstance(event, dict):
        raise ValueError("이벤트는 JSON 객체여야 합니다.")

    params = dict(event.get("queryStringParameters") or {})
    if "body" in event and event["body"] is not None:
        body = event["body"]
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body, validate=True).decode("utf-8")
        if isinstance(body, str):
            body = json.loads(body)
        if not isinstance(body, dict):
            raise ValueError("body는 JSON 객체여야 합니다.")
        params.update(body)
    else:
        params.update(event)
    return params


def _required_key(params):
    key = params.get("key")
    if not isinstance(key, str) or not key:
        raise ValueError("key가 필요합니다.")
    return key


def lambda_handler(event, context):
    try:
        params = _params(event)
        action = params.get("action")
        if action not in ("upload", "update", "list", "download", "read", "delete"):
            raise ValueError("action은 upload, list, download, delete 중 하나여야 합니다.")

        if action in ("upload", "update"):
            key = _required_key(params)
            encoded = params.get("content_base64")
            if not isinstance(encoded, str):
                raise ValueError("content_base64가 필요합니다.")
            content = base64.b64decode(encoded, validate=True)
            content_type = params.get("content_type", "application/octet-stream")
            if not isinstance(content_type, str) or not content_type:
                raise ValueError("content_type은 문자열이어야 합니다.")

        elif action in ("download", "read", "delete"):
            key = _required_key(params)

        elif action == "list":
            prefix = params.get("prefix", "")
            if not isinstance(prefix, str):
                raise ValueError("prefix는 문자열이어야 합니다.")
            max_keys = int(params.get("max_keys", 1000))
            if not 1 <= max_keys <= 1000:
                raise ValueError("max_keys는 1~1000이어야 합니다.")

    except (ValueError, TypeError, binascii.Error, UnicodeDecodeError, json.JSONDecodeError) as error:
        return _response(400, {"error": str(error)})

    try:
        s3 = boto3.client(
            "s3", region_name=REGION, config=Config(signature_version=UNSIGNED)
        )

        if action in ("upload", "update"):
            s3.put_object(Bucket=BUCKET, Key=key, Body=content, ContentType=content_type)
            result = {"key": key, "size": len(content), "uri": f"s3://{BUCKET}/{key}"}

        elif action == "list":
            request = {"Bucket": BUCKET, "Prefix": prefix, "MaxKeys": max_keys}
            token = params.get("continuation_token")
            if token:
                request["ContinuationToken"] = token
            page = s3.list_objects_v2(**request)
            result = {
                "objects": [
                    {"key": obj["Key"], "size": obj["Size"]}
                    for obj in page.get("Contents", [])
                ],
                "next_token": page.get("NextContinuationToken"),
            }

        elif action in ("download", "read"):
            response = s3.get_object(Bucket=BUCKET, Key=key)
            content = response["Body"].read()
            result = {
                "key": key,
                "content_type": response.get("ContentType", "application/octet-stream"),
                "content_base64": base64.b64encode(content).decode("ascii"),
            }

        elif action == "delete":
            s3.delete_object(Bucket=BUCKET, Key=key)
            result = {"key": key, "deleted": True}

        return _response(200, result)

    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "S3Error")
        status = 404 if code in ("NoSuchKey", "404") else 502
        return _response(status, {"error": code})
    except (Boto3Error, BotoCoreError) as error:
        return _response(502, {"error": str(error)})
