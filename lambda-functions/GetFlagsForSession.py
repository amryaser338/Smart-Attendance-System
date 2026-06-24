import json
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
sessions_table   = dynamodb.Table("qr_sessions")
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

    session_id = body.get("session_id")
    if not session_id:
        return resp(400, {"message": "session_id is required"})

    s = sessions_table.get_item(Key={"session_id": session_id})
    session = s.get("Item")
    if not session:
        return resp(400, {"message": "Session not found"})

    meeting_id = session.get("meeting_id")
    if not meeting_id:
        return resp(500, {"message": "Session missing meeting_id"})

    flag_pk = f"FLAG#{meeting_id}"
    r = attendance_table.query(KeyConditionExpression=Key("course_date").eq(flag_pk))

    flags = [{
        "student_id":      it.get("student_id"),
        "flag_reason":     it.get("flag_reason"),
        "message":         it.get("message"),
        "expected_app_id": it.get("expected_app_id"),
        "received_app_id": it.get("received_app_id"),
        "timestamp":       it.get("timestamp"),
        "session_id":      it.get("session_id")
    } for it in r.get("Items", [])]

    return resp(200, {
        "meeting_id":  meeting_id,
        "course_id":   session.get("course_id"),
        "section_id":  session.get("section_id"),
        "expires_at":  session.get("expires_at"),
        "flags_count": len(flags),
        "flags":       flags
    })
