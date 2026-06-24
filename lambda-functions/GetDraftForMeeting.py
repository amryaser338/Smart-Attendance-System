import json
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
attendance_table = dynamodb.Table("attendance")

def clean(obj):
    if isinstance(obj, list):
        return [clean(x) for x in obj]
    if isinstance(obj, dict):
        return {k: clean(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj

def resp(code, obj):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(clean(obj))
    }

def parse_body(event):
    if isinstance(event, dict) and event.get("body") is not None:
        b = event.get("body")
        if isinstance(b, str) and b.strip():
            try:
                return json.loads(b)
            except Exception:
                return None
        if isinstance(b, dict):
            return b
        return {}
    return event if isinstance(event, dict) else {}

def lambda_handler(event, context):
    body = parse_body(event)
    if body is None:
        return resp(400, {"message": "Invalid JSON body"})

    meeting_id = body.get("meeting_id")
    if not meeting_id:
        return resp(400, {"message": "meeting_id is required"})

    pk = f"DRAFT#{meeting_id}"
    items = []
    last_key = None
    while True:
        kwargs = {"KeyConditionExpression": Key("course_date").eq(pk)}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = attendance_table.query(**kwargs)
        items.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break

    overrides = sorted([{
        "student_id": it.get("student_id"),
        "status":     it.get("status"),
        "updated_at": it.get("updated_at")
    } for it in items], key=lambda x: x.get("student_id") or "")

    return resp(200, {"meeting_id": meeting_id, "count": len(overrides), "overrides": overrides})
