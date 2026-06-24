import json
import boto3
from boto3.dynamodb.conditions import Attr, Key
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
students_table   = dynamodb.Table("students")
attendance_table = dynamodb.Table("attendance")
qr_table         = dynamodb.Table("qr_sessions")

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

def scan_roster(course_id, section_id):
    section_key = f"{course_id}#{section_id}"
    roster = []
    last_key = None
    while True:
        kwargs = {
            "FilterExpression": Attr("section_ids").contains(section_key),
            "ProjectionExpression": "student_id, #n",
            "ExpressionAttributeNames": {"#n": "name"}
        }
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = students_table.scan(**kwargs)
        roster.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
    roster.sort(key=lambda x: x.get("student_id", ""))
    return roster

def query_all_by_pk(pk_value):
    items = []
    last_key = None
    while True:
        kwargs = {"KeyConditionExpression": Key("course_date").eq(pk_value)}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = attendance_table.query(**kwargs)
        items.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
    return items

def find_all_meetings_today(course_id, section_id, date_str):
    """
    Find ALL unique meeting_ids for this course+section+today.

    Two sources:
    1. qr_sessions table  — normal path
    2. attendance table   — fallback for orphaned meeting_ids not in qr_sessions
                            (e.g. sessions deleted before TTL was turned off)

    Sorted oldest -> newest so newer drafts override older ones.
    """
    meeting_map = {}

    # ── Source 1: qr_sessions ─────────────────────────────────────────────
    items = []
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
        items.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break

    for it in items:
        mid = it.get("meeting_id")
        if not mid:
            continue
        existing = meeting_map.get(mid)
        if not existing or int(it.get("created_at") or 0) > int(existing.get("created_at") or 0):
            meeting_map[mid] = it

    # ── Source 2: attendance table fallback ───────────────────────────────
    for prefix in [f"SCAN#{course_id}#{section_id}#{date_str}",
                   f"DRAFT#{course_id}#{section_id}#{date_str}"]:
        att_items = []
        last_key = None
        while True:
            kwargs = {
                "FilterExpression": Attr("course_date").begins_with(prefix)
            }
            if last_key:
                kwargs["ExclusiveStartKey"] = last_key
            r = attendance_table.scan(**kwargs)
            att_items.extend(r.get("Items", []))
            last_key = r.get("LastEvaluatedKey")
            if not last_key:
                break

        for it in att_items:
            mid = it.get("meeting_id")
            if not mid or mid in meeting_map:
                continue
            # Orphaned meeting — treat as oldest
            meeting_map[mid] = {
                "meeting_id": mid,
                "session_id": None,
                "created_at": 0
            }

    meetings = list(meeting_map.values())
    meetings.sort(key=lambda x: int(x.get("created_at") or 0))  # oldest -> newest
    return meetings

def lambda_handler(event, context):
    body = parse_body(event)
    if body is None:
        return resp(400, {"message": "Invalid JSON body"})

    course_id  = body.get("course_id")
    section_id = body.get("section_id")
    meeting_id = body.get("meeting_id")

    if not course_id or not section_id or not meeting_id:
        return resp(400, {"message": "course_id, section_id, meeting_id are required"})

    # Extract date from meeting_id: format is course#section#date#hex
    parts = meeting_id.split("#")
    if len(parts) < 3:
        return resp(400, {"message": "Invalid meeting_id format"})
    date_str = parts[2]  # e.g. 2026-03-07

    roster      = scan_roster(course_id, section_id)
    all_meetings = find_all_meetings_today(course_id, section_id, date_str)

    scanned_ids = set()
    overrides   = {}
    ordered_meeting_ids = []

    for m in all_meetings:
        mid = m.get("meeting_id")
        if not mid:
            continue
        ordered_meeting_ids.append(mid)

        for it in query_all_by_pk(f"SCAN#{mid}"):
            sid = it.get("student_id")
            if sid:
                scanned_ids.add(sid)

        for it in query_all_by_pk(f"DRAFT#{mid}"):
            sid = it.get("student_id")
            st  = (it.get("status") or "").strip().lower()
            if sid and st in ("present", "absent"):
                overrides[sid] = st  # newer meeting draft wins

    absent_students = []
    for s in roster:
        sid = s.get("student_id")
        if not sid:
            continue

        is_present = sid in scanned_ids
        if sid in overrides:
            is_present = (overrides[sid] == "present")

        if not is_present:
            absent_students.append({
                "student_id": sid,
                "name":       s.get("name", "")
            })

    return resp(200, {
        "course_id":       course_id,
        "section_id":      section_id,
        "meeting_id":      meeting_id,
        "meetings_today":  ordered_meeting_ids,
        "absent_count":    len(absent_students),
        "absent_students": absent_students
    })
