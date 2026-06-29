import json
import os
import boto3
from decimal import Decimal
from datetime import datetime, timedelta

dynamodb = boto3.resource("dynamodb", region_name=os.environ["AWS_REGION"])
table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])


def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError


def respond(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=decimal_default, ensure_ascii=False),
    }


def handler(event, context):
    path   = event.get("path", "/")
    method = event.get("httpMethod", "GET")
    params = event.get("queryStringParameters") or {}

    # GET /analysis/{ticker}
    if method == "GET" and path.startswith("/analysis/"):
        ticker = path.split("/")[-1].upper()
        date   = params.get("date", (datetime.utcnow() - timedelta(days=1)).strftime("%Y-%m-%d"))

        resp = table.get_item(Key={"ticker": ticker, "date": date})
        item = resp.get("Item")
        if not item:
            return respond(404, {"message": f"{ticker} / {date} 데이터 없음"})
        return respond(200, item)

    # GET /analysis  (목록: 특정 날짜 전체)
    if method == "GET" and path == "/analysis":
        date  = params.get("date", (datetime.utcnow() - timedelta(days=1)).strftime("%Y-%m-%d"))
        limit = int(params.get("limit", 20))

        resp = table.query(
            IndexName="date-ticker-index",
            KeyConditionExpression=boto3.dynamodb.conditions.Key("date").eq(date),
            Limit=limit,
        )
        return respond(200, {"items": resp.get("Items", []), "count": resp.get("Count", 0)})

    return respond(404, {"message": "Not found"})
