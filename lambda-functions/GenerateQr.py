import json
import boto3
import uuid
import time
from datetime import datetime
from zoneinfo import ZoneInfo
from boto3.dynamodb.conditions import Attr

dynamodb = boto3.resource("dynamodb")
qr_table      = dynamodb.Table("qr_sessions")
courses_table = dynamodb.Table("courses")

CAIRO = ZoneInfo("Africa/Cairo")

QR_DURATION_SECONDS = 60

def dow3_today():
    return datetime.now(CAIRO).strftime("%a").upper()[:3]

def resp(code, obj):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(obj)
    }

def get_or_create_meeting_id(course_id, section_id, date_str):
    """
    Reuse same meeting_id for all QR sessions created on the same day
    for the same course+section.
    """
    existing = []
    last_key = None
    while True:
        kwargs = {
            "FilterExpression": (
                Attr("course_id").eq(course_id) &
                Attr("section_id").eq(section_id) &
                Attr("meeting_id").contains(date_str)
            )
        }
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = qr_table.scan(**kwargs)
        existing.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break

    if existing:
        # Reuse earliest created meeting_id for today
        existing.sort(key=lambda x: int(x.get("created_at") or 0))
        return existing[0]["meeting_id"]

    # No session today yet — create a new meeting_id
    return f"{course_id}#{section_id}#{date_str}#{uuid.uuid4().hex[:8]}"


def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            return resp(400, {"message": "Invalid JSON body"})
    else:
        body = event or {}

    course_id  = body.get("course_id")
    section_id = body.get("section_id")

    if not course_id or not section_id:
        return resp(400, {"message": "course_id and section_id are required"})

    # meeting_days check
    today = dow3_today()

    c = courses_table.get_item(Key={"course_id": course_id})
    course = c.get("Item")
    if not course:
        return resp(400, {"message": f"Course {course_id} not found"})

    sections = course.get("sections", []) or []
    sec_obj  = None
    for s in sections:
        if s.get("section_id") == section_id:
            sec_obj = s
            break

    if not sec_obj:
        return resp(400, {"message": f"Section {section_id} not found in course {course_id}"})

    meeting_days = sec_obj.get("meeting_days", []) or []
    if not isinstance(meeting_days, list):
        meeting_days = [meeting_days]
    meeting_days_norm = [str(d).upper()[:3] for d in meeting_days]

    if today not in meeting_days_norm:
        return resp(403, {
            "message":      "Attendance not allowed today for this section",
            "today":        today,
            "meeting_days": meeting_days_norm
        })

    date_str   = datetime.now(CAIRO).strftime("%Y-%m-%d")
    meeting_id = get_or_create_meeting_id(course_id, section_id, date_str)

    session_id = str(uuid.uuid4())
    now        = int(time.time())
    expires_at = now + QR_DURATION_SECONDS

    item = {
        "session_id": session_id,
        "meeting_id": meeting_id,
        "course_id":  course_id,
        "section_id": section_id,
        "created_at": now,
        "expires_at": expires_at
    }

    qr_table.put_item(Item=item)

    return resp(200, {
        "session_id":       session_id,
        "meeting_id":       meeting_id,
        "course_id":        course_id,
        "section_id":       section_id,
        "created_at":       now,
        "expires_at":       expires_at,
        "duration_seconds": QR_DURATION_SECONDS   # Flutter uses this for the timer
    })
