import json
import boto3
from datetime import datetime, timezone
from decimal import Decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
attendance_table = dynamodb.Table("attendance")
qr_table         = dynamodb.Table("qr_sessions")

ALLOWED = {"present", "absent"}

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
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
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

def meeting_exists_in_qr_sessions(meeting_id):
    """
    Check if the meeting_id has at least one session in qr_sessions.
    Prevents orphaned drafts being written under unknown meeting_ids.
    """
    r = qr_table.scan(
        FilterExpression=boto3.dynamodb.conditions.Attr("meeting_id").eq(meeting_id),
        Limit=1
    )
    return r.get("Count", 0) > 0

def lambda_handler(event, context):
    body = parse_body(event)
    if body is None:
        return resp(400, {"message": "Invalid JSON body"})

    meeting_id = body.get("meeting_id")
    student_id = body.get("student_id")
    status     = body.get("status")

    if not meeting_id or not student_id or not status:
        return resp(400, {"message": "meeting_id, student_id, status are required"})

    status = str(status).lower()
    if status not in ALLOWED:
        return resp(400, {"message": "status must be 'present' or 'absent'"})

    # Validate meeting_id exists in qr_sessions
    if not meeting_exists_in_qr_sessions(meeting_id):
        return resp(400, {
            "message": f"meeting_id '{meeting_id}' not found in qr_sessions. Draft rejected."
        })

    pk  = f"DRAFT#{meeting_id}"
    now = datetime.now(timezone.utc).isoformat()

    attendance_table.put_item(Item={
        "course_date": pk,
        "student_id":  student_id,
        "status":      status,
        "updated_at":  now,
        "record_type": "draft_override"
    })

    return resp(200, {
        "message":    "Draft override saved",
        "meeting_id": meeting_id,
        "student_id": student_id,
        "status":     status
    })
