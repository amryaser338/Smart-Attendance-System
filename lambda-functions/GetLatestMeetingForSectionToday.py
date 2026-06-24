import json
import boto3
from datetime import datetime
from zoneinfo import ZoneInfo
from decimal import Decimal
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource("dynamodb")
attendance_table = dynamodb.Table("attendance")
qr_table         = dynamodb.Table("qr_sessions")
students_table   = dynamodb.Table("students")

CAIRO = ZoneInfo("Africa/Cairo")


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
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(clean(obj)),
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


def today_str():
    return datetime.now(CAIRO).strftime("%Y-%m-%d")


def scan_students_for_section(section_key):
    roster = []
    last_key = None
    while True:
        kwargs = {
            "FilterExpression": Attr("section_ids").contains(section_key),
            "ProjectionExpression": "student_id, #n",
            "ExpressionAttributeNames": {"#n": "name"},
        }
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = students_table.scan(**kwargs)
        roster.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
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


def find_all_meetings_today(course_id, section_id, today):
    """
    Find ALL unique meeting_ids for this course+section+today.

    Two sources:
    1. qr_sessions table — normal path, all properly generated QR sessions
    2. attendance table  — fallback for orphaned meeting_ids that exist in
                           SCAN/DRAFT records but have no qr_sessions entry
                           (e.g. manually created via Postman during testing)

    Both sources are merged so no meeting is ever missed.
    Sorted by created_at ascending so newer drafts override older ones.
    """

    meeting_map = {}  # meeting_id -> session item

    # ── Source 1: qr_sessions ──────────────────────────────────────────────
    items = []
    last_key = None
    while True:
        kwargs = {
            "FilterExpression": (
                Attr("course_id").eq(course_id) &
                Attr("section_id").eq(section_id) &
                Attr("meeting_id").contains(today)
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

    # ── Source 2: attendance table fallback ────────────────────────────────
    # Scan for any SCAN# or DRAFT# records for this course+section+today
    # that have a meeting_id not already found in qr_sessions
    for prefix in [f"SCAN#{course_id}#{section_id}#{today}",
                   f"DRAFT#{course_id}#{section_id}#{today}"]:
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
            # Orphaned meeting — add it with created_at = 0 (treat as oldest)
            meeting_map[mid] = {
                "meeting_id": mid,
                "session_id": None,
                "created_at": 0
            }

    meetings = list(meeting_map.values())
    meetings.sort(key=lambda x: int(x.get("created_at") or 0))  # oldest -> newest
    return meetings


def lambda_handler(event, context):
    try:
        body = parse_body(event)
        if body is None:
            return resp(400, {"message": "Invalid JSON body"})

        course_id  = body.get("course_id")
        section_id = body.get("section_id")
        if not course_id or not section_id:
            return resp(400, {"message": "course_id and section_id are required"})

        today       = today_str()
        section_key = f"{course_id}#{section_id}"

        # ── PRIORITY 1: FINAL ─────────────────────────────────────────────
        final_pk    = f"FINAL#{course_id}#{section_id}#{today}"
        final_items = query_all_by_pk(final_pk)

        if final_items:
            students      = []
            present_count = 0
            absent_count  = 0
            no = 1

            for it in sorted(final_items, key=lambda x: x.get("student_id", "")):
                sid = it.get("student_id")
                if sid in (None, "", "_META_"):
                    continue

                status = (it.get("status") or "absent").strip().lower()
                if status == "present":
                    present_count += 1
                else:
                    status = "absent"
                    absent_count += 1

                students.append({
                    "no":         no,
                    "student_id": sid,
                    "status":     status,
                    "source":     "final",
                })
                no += 1

            return resp(200, {
                "found":         True,
                "course_id":     course_id,
                "section_id":    section_id,
                "date":          today,
                "mode":          "FINAL",
                "has_final":     True,
                "meeting_id":    None,
                "session_id":    None,
                "present_count": present_count,
                "absent_count":  absent_count,
                "students":      students,
            })

        # ── Load roster ───────────────────────────────────────────────────
        roster_items = scan_students_for_section(section_key)
        roster_items = sorted(roster_items, key=lambda x: x.get("student_id", ""))

        roster_map = {}
        for s in roster_items:
            sid = s.get("student_id")
            if sid and sid != "_META_":
                roster_map[sid] = s.get("name", "")

        roster_ids = list(roster_map.keys())

        # ── PRIORITY 2: Any QR session today ─────────────────────────────
        all_meetings = find_all_meetings_today(course_id, section_id, today)

        if not all_meetings:
            # PRIORITY 3: DEFAULT
            students = []
            for i, sid in enumerate(roster_ids, start=1):
                students.append({
                    "no":         i,
                    "student_id": sid,
                    "name":       roster_map.get(sid, ""),
                    "status":     "present",
                    "source":     "default_no_meeting",
                })

            return resp(200, {
                "found":         True,
                "course_id":     course_id,
                "section_id":    section_id,
                "date":          today,
                "mode":          "DEFAULT",
                "has_final":     False,
                "meeting_id":    None,
                "session_id":    None,
                "present_count": len(roster_ids),
                "absent_count":  0,
                "students":      students,
            })

        # Accumulate SCAN + DRAFT across ALL meetings today
        scanned_set = set()
        overrides   = {}

        latest_session_id = None
        latest_meeting_id = None
        latest_created_at = -1

        for meeting_item in all_meetings:
            mid        = meeting_item.get("meeting_id")
            sid_sess   = meeting_item.get("session_id")
            created_at = int(meeting_item.get("created_at") or 0)

            if created_at > latest_created_at:
                latest_created_at = created_at
                latest_session_id = sid_sess
                latest_meeting_id = mid

            for it in query_all_by_pk(f"SCAN#{mid}"):
                s = it.get("student_id")
                if s:
                    scanned_set.add(s)

            for it in query_all_by_pk(f"DRAFT#{mid}"):
                s  = it.get("student_id")
                st = (it.get("status") or "").strip().lower()
                if s and st in ("present", "absent"):
                    overrides[s] = st  # newest meeting draft wins

        # Zero activity across ALL meetings → DEFAULT
        if len(scanned_set) == 0 and len(overrides) == 0:
            students = []
            for i, sid in enumerate(roster_ids, start=1):
                students.append({
                    "no":         i,
                    "student_id": sid,
                    "name":       roster_map.get(sid, ""),
                    "status":     "present",
                    "source":     "default_meeting_no_activity",
                })

            return resp(200, {
                "found":                True,
                "course_id":            course_id,
                "section_id":           section_id,
                "date":                 today,
                "mode":                 "DEFAULT",
                "has_final":            False,
                "meeting_id":           latest_meeting_id,
                "session_id":           latest_session_id,
                "present_count":        len(roster_ids),
                "absent_count":         0,
                "scan_count":           0,
                "draft_override_count": 0,
                "students":             students,
            })

        # Compute status per student
        status_map = {sid: "absent" for sid in roster_ids}
        for sid in scanned_set:
            if sid in status_map:
                status_map[sid] = "present"
        for sid, st in overrides.items():
            if sid in status_map:
                status_map[sid] = st

        present_count = sum(1 for sid in roster_ids if status_map.get(sid) == "present")
        absent_count  = len(roster_ids) - present_count

        students = []
        for i, sid in enumerate(roster_ids, start=1):
            students.append({
                "no":         i,
                "student_id": sid,
                "name":       roster_map.get(sid, ""),
                "status":     status_map.get(sid, "absent"),
                "source":     "scan+draft",
            })

        return resp(200, {
            "found":               True,
            "course_id":           course_id,
            "section_id":          section_id,
            "date":                today,
            "mode":                "DRAFT",
            "has_final":           False,
            "meeting_id":          latest_meeting_id,
            "session_id":          latest_session_id,
            "present_count":       present_count,
            "absent_count":        absent_count,
            "scan_count":          len(scanned_set),
            "draft_override_count": len(overrides),
            "students":            students,
        })

    except Exception as e:
        return resp(500, {"message": "Internal Server Error", "error": str(e)})
