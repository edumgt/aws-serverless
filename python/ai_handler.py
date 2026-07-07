import base64
import json
import os

import boto3
from botocore.exceptions import BotoCoreError, ClientError


REGION_NAME = os.environ.get("AWS_REGION") or os.environ.get("AWS_REGION_NAME")
DEFAULT_LANGUAGE = os.environ.get("AI_DEFAULT_LANGUAGE", "ko")
REKOGNITION_MAX_LABELS = int(os.environ.get("REKOGNITION_MAX_LABELS", "10"))
REKOGNITION_MIN_CONFIDENCE = float(os.environ.get("REKOGNITION_MIN_CONFIDENCE", "80"))
PII_SUPPORTED_LANGUAGES = {"en", "es"}

comprehend = boto3.client("comprehend", region_name=REGION_NAME)
rekognition = boto3.client("rekognition", region_name=REGION_NAME)


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, ensure_ascii=False),
    }


def _parse_body(event):
    body = event.get("body")
    if body in (None, ""):
        return {}

    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")

    if isinstance(body, dict):
        return body

    if isinstance(body, str):
        return json.loads(body)

    raise ValueError("Unsupported body type")


def analyze_text(event, context):
    try:
        payload = _parse_body(event)
    except (ValueError, json.JSONDecodeError) as exc:
        return _response(400, {"message": "Invalid JSON body", "detail": str(exc)})

    text = (payload.get("text") or "").strip()
    if not text:
        return _response(400, {"message": "text is required"})

    language_code = payload.get("language_code", DEFAULT_LANGUAGE)
    include_pii = bool(payload.get("detect_pii", False))

    try:
        sentiment_result = comprehend.detect_sentiment(
            Text=text,
            LanguageCode=language_code,
        )
        entities_result = comprehend.detect_entities(
            Text=text,
            LanguageCode=language_code,
        )
    except (BotoCoreError, ClientError) as exc:
        return _response(502, {"message": "Comprehend request failed", "detail": str(exc)})

    response_body = {
        "service": "amazon-comprehend",
        "language_code": language_code,
        "sentiment": sentiment_result["Sentiment"],
        "sentiment_score": sentiment_result["SentimentScore"],
        "entities": [
            {
                "text": entity["Text"],
                "type": entity["Type"],
                "score": round(entity["Score"], 4),
            }
            for entity in entities_result.get("Entities", [])
        ],
        "entity_count": len(entities_result.get("Entities", [])),
    }

    if include_pii:
        if _pii_language_supported(language_code):
            try:
                pii_result = comprehend.detect_pii_entities(
                    Text=text,
                    LanguageCode=language_code,
                )
            except (BotoCoreError, ClientError) as exc:
                return _response(502, {"message": "PII detection failed", "detail": str(exc)})

            response_body["pii_entities"] = [
                {
                    "type": entity["Type"],
                    "score": round(entity["Score"], 4),
                    "begin_offset": entity["BeginOffset"],
                    "end_offset": entity["EndOffset"],
                }
                for entity in pii_result.get("Entities", [])
            ]
        else:
            response_body["pii_warning"] = (
                f"DetectPiiEntities is not supported for language_code '{language_code}'. "
                "Use en or es."
            )

    return _response(200, response_body)


def detect_image_labels(event, context):
    try:
        payload = _parse_body(event)
        image = _build_rekognition_image(payload)
    except (ValueError, json.JSONDecodeError) as exc:
        return _response(400, {"message": str(exc)})

    try:
        result = rekognition.detect_labels(
            Image=image,
            MaxLabels=int(payload.get("max_labels", REKOGNITION_MAX_LABELS)),
            MinConfidence=float(payload.get("min_confidence", REKOGNITION_MIN_CONFIDENCE)),
        )
    except (BotoCoreError, ClientError) as exc:
        return _response(502, {"message": "Rekognition request failed", "detail": str(exc)})

    labels = []
    for label in result.get("Labels", []):
        labels.append(
            {
                "name": label["Name"],
                "confidence": round(label["Confidence"], 2),
                "categories": [category["Name"] for category in label.get("Categories", [])],
                "parents": [parent["Name"] for parent in label.get("Parents", [])],
                "instances": len(label.get("Instances", [])),
            }
        )

    return _response(
        200,
        {
            "service": "amazon-rekognition",
            "label_count": len(labels),
            "labels": labels,
        },
    )


def _build_rekognition_image(payload):
    image_bytes_base64 = payload.get("image_bytes_base64")
    if image_bytes_base64:
        return {"Bytes": base64.b64decode(image_bytes_base64)}

    s3_bucket = payload.get("s3_bucket")
    s3_key = payload.get("s3_key")
    if s3_bucket and s3_key:
        return {"S3Object": {"Bucket": s3_bucket, "Name": s3_key}}

    raise ValueError(
        "Provide either image_bytes_base64 or both s3_bucket and s3_key"
    )


def _pii_language_supported(language_code):
    normalized = (language_code or "").split("-")[0].lower()
    return normalized in PII_SUPPORTED_LANGUAGES
