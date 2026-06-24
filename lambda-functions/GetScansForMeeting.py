import json
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
attendance_table = dynamodb.Table("attendance")

def clean_decimals(obj):
    if isinstance(obj, list):
        return [clean_decimals(i) for i in obj]
    if isinstance(obj, dict):
        return {k: clean_decimals(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj

def resp(code, obj):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(clean_decimals(obj))
    }

def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            return resp(400, {"message": "Invalid JSON body"})
    else:
        body = event or {}

    meeting_id = body.get("meeting_id")
    if not meeting_id:
        return resp(400, {"message": "meeting_id is required"})

    scan_pk = f"SCAN#{meeting_id}"
    r = attendance_table.query(KeyConditionExpression=Key("course_date").eq(scan_pk))
    scanned_ids = sorted(list(set(it.get("student_id") for it in r.get("Items", []) if it.get("student_id"))))
    return resp(200, {"meeting_id": meeting_id, "scan_pk": scan_pk, "scanned_student_ids": scanned_ids, "count": len(scanned_ids)})
