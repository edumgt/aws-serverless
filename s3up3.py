"""공개 S3 버킷을 관리하는 AWS Lambda 핸들러.

Lambda 핸들러: s3up3.lambda_handler

직접 호출 이벤트 예시:
    {"action": "upload", "key": "hello.txt", "content_base64": "aGVsbG8="}
    {"action": "list", "prefix": "images/"}
    {"action": "download", "key": "hello.txt"}
    {"action": "delete", "key": "hello.txt"}

REST API 경로:
    GET /objects                 객체 목록
    POST /objects                업로드 (JSON body에 key, content_base64)
    GET /objects/{key}           다운로드 (JSON body에 content_base64 반환)
    PUT /objects/{key}           갱신 (JSON body에 content_base64)
    DELETE /objects/{key}        삭제
    OPTIONS /objects[/{key}]    CORS 사전 요청

직접 호출은 action을 사용한다. 모든 S3 요청은 AWS 자격 증명 없이 전송한다.
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
        "headers": {
            "content-type": "application/json; charset=utf-8",
            "access-control-allow-origin": "*",
            "access-control-allow-methods": "GET,POST,PUT,DELETE,OPTIONS",
            "access-control-allow-headers": "content-type",
        },
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

    method = event.get("httpMethod")
    if method is not None:
        if not isinstance(method, str):
            raise ValueError("httpMethod는 문자열이어야 합니다.")
        method = method.upper()
        path_key = (event.get("pathParameters") or {}).get("proxy")
        actions = {"POST": "upload", "PUT": "update", "DELETE": "delete",
                   "OPTIONS": "options"}
        if method == "GET":
            params["action"] = "download" if path_key else "list"
        else:
            params["action"] = actions.get(method, "unsupported")
        if path_key:
            params["key"] = path_key
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
        if action == "options":
            return _response(200, {"ok": True})
        if action == "unsupported":
            return _response(405, {"error": "지원하지 않는 HTTP 메소드입니다."})
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
