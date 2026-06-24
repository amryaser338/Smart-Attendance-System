import json
import boto3
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
attendance_table = dynamodb.Table("attendance")
students_table   = dynamodb.Table("students")
CAIRO = ZoneInfo("Africa/Cairo")

def clean(x):
    if isinstance(x, Decimal):
        return int(x) if x % 1 == 0 else float(x)
    if isinstance(x, list):
        return [clean(i) for i in x]
    if isinstance(x, dict):
        return {k: clean(v) for k, v in x.items()}
    return x

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

def scan_roster(course_id, section_id):
    sec_key = f"{course_id}#{section_id}"
    roster = []
    last_key = None
    while True:
        kwargs = {}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = students_table.scan(**kwargs)
        for it in r.get("Items", []):
            sid = it.get("student_id")
            if not sid:
                continue
            section_ids = it.get("section_ids", []) or []
            if isinstance(section_ids, list) and sec_key in section_ids:
                roster.append(sid)
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
        if len(roster) > 5000:
            break
    roster.sort()
    return roster

def lambda_handler(event, context):
    body = parse_body(event)
    if body is None:
        return resp(400, {"message": "Invalid JSON body"})

    course_id   = body.get("course_id")
    section_id  = body.get("section_id")
    date        = body.get("date")
    present_ids = body.get("present_student_ids", [])

    if not course_id or not section_id or not date:
        return resp(400, {"message": "course_id, section_id, date are required"})
    if not isinstance(present_ids, list):
        return resp(400, {"message": "present_student_ids must be a list"})

    roster      = scan_roster(course_id, section_id)
    present_set = set([str(x) for x in present_ids])
    pk          = f"FINAL#{course_id}#{section_id}#{date}"
    now         = datetime.now(timezone.utc).isoformat()

    attendance_table.put_item(Item={
        "course_date": pk, "student_id": "_META_",
        "record_type": "final_meta", "course_id": course_id,
        "section_id": section_id, "date": date, "saved_at": now
    })

    with attendance_table.batch_writer() as batch:
        for sid in roster:
            st = "present" if sid in present_set else "absent"
            batch.put_item(Item={
                "course_date": pk, "student_id": sid,
                "status": st, "record_type": "final", "saved_at": now
            })

    return resp(200, {
        "message": "Final attendance saved", "pk": pk,
        "roster_count":  len(roster),
        "present_count": len([x for x in roster if x in present_set]),
        "absent_count":  len([x for x in roster if x not in present_set]),
    })
