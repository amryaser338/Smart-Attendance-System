# Smart Attendance System — Lambda Functions Code Reference

All 13 Lambda functions. Python 3.x runtime. Deploy each separately in AWS Lambda.

---

## Tables Used

| Table | Purpose |
|-------|---------|
| `attendance` | SCAN, DRAFT, FINAL, FLAG records |
| `courses` | Course catalog with sections and meeting days |
| `students` | Student enrollment and device binding |
| `qr_sessions` | QR session records — **TTL must be OFF** |

---

## 1. GetDoctorCoursesSections
**Endpoint:** `POST /getDoctorCoursesSections`
Returns courses and sections the doctor teaches today only.

```python
import json
import boto3
from decimal import Decimal
from datetime import datetime
from zoneinfo import ZoneInfo

dynamodb = boto3.resource("dynamodb")
courses_table = dynamodb.Table("courses")
CAIRO = ZoneInfo("Africa/Cairo")

def today_dow_3():
    return datetime.now(CAIRO).strftime("%a").upper()[:3]

def normalize_meeting_days(meeting_days):
    if meeting_days is None:
        return []
    if not isinstance(meeting_days, list):
        meeting_days = [meeting_days]
    return [str(d).upper()[:3] for d in meeting_days if d is not None]

def clean(obj):
    if isinstance(obj, list):
        return [clean(x) for x in obj]
    if isinstance(obj, dict):
        return {k: clean(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj

def resp(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(clean(body))
    }

def lambda_handler(event, context):
    body = {}
    if isinstance(event, dict) and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            return resp(400, {"message": "Invalid JSON body"})

    qs = (event.get("queryStringParameters") or {}) if isinstance(event, dict) else {}
    doctor_id = (body.get("doctor_id") or qs.get("doctor_id"))

    if not doctor_id:
        return resp(400, {"message": "doctor_id is required (in JSON body or ?doctor_id=...)"})

    dow = today_dow_3()
    items = []
    scan_kwargs = {}
    while True:
        r = courses_table.scan(**scan_kwargs)
        items.extend(r.get("Items", []))
        if "LastEvaluatedKey" not in r:
            break
        scan_kwargs["ExclusiveStartKey"] = r["LastEvaluatedKey"]

    result = []
    for course in items:
        course_id = course.get("course_id")
        course_name = course.get("course_name")
        sections = course.get("sections", []) or []
        my_sections_today = []
        for sec in sections:
            sec_id = sec.get("section_id")
            doctor_ids = sec.get("doctor_ids", []) or []
            meeting_days = normalize_meeting_days(sec.get("meeting_days", []))
            if isinstance(doctor_ids, str):
                doctor_ids = [doctor_ids]
            if not sec_id:
                continue
            if doctor_id not in doctor_ids:
                continue
            if dow not in meeting_days:
                continue
            my_sections_today.append(sec_id)
        if my_sections_today:
            result.append({"course_id": course_id, "course_name": course_name, "sections": sorted(set(my_sections_today))})

    return resp(200, {"doctor_id": doctor_id, "today": dow, "count": len(result),
                      "courses": sorted(result, key=lambda x: x["course_id"] or "")})

```

---

## 2. GetStudentsForSection
**Endpoint:** `POST /getStudentsForSection`
Returns the full student roster for a section.

```python
import json
import boto3
from boto3.dynamodb.conditions import Attr

dynamodb = boto3.resource("dynamodb")
students_table = dynamodb.Table("students")

def resp(code, obj):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(obj)
    }

def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            return resp(400, {"message": "Invalid JSON body"})
    else:
        body = event or {}

    course_id = body.get("course_id")
    section_id = body.get("section_id")
    if not course_id or not section_id:
        return resp(400, {"message": "course_id and section_id are required"})

    section_key = f"{course_id}#{section_id}"
    r = students_table.scan(
        FilterExpression=Attr("section_ids").contains(section_key),
        ProjectionExpression="student_id, #n",
        ExpressionAttributeNames={"#n": "name"}
    )
    students = sorted(r.get("Items", []), key=lambda x: x.get("student_id", ""))
    return resp(200, {"students": students, "count": len(students)})

```

---

## 3. GetLatestMeetingForSectionToday
**Endpoint:** `POST /getLatestMeetingForSectionToday`
Core load function. Returns attendance state: FINAL > DRAFT > DEFAULT.
Uses two-source meeting discovery (qr_sessions + attendance fallback).

```python
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

```

---

## 4. GenerateQr
**Endpoint:** `POST /generateQr`
Creates a 60-second QR session. Reuses same meeting_id for all QRs on the same day.

```python
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

```

---

## 5. ScanQr
**Endpoint:** `POST /scanQr`
Validates scan, checks enrollment, binds app_id, records attendance.
Uses ConsistentRead=True to prevent stale-read errors.

```python
import json
import boto3
import time
from datetime import datetime, timezone
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
sessions_table   = dynamodb.Table("qr_sessions")
students_table   = dynamodb.Table("students")
attendance_table = dynamodb.Table("attendance")

def resp(code, obj):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(obj)
    }

def lambda_handler(event, context):
    # Parse input
    if isinstance(event, dict) and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            return resp(400, {"message": "Invalid JSON body"})
    else:
        body = event or {}

    session_id      = body.get("session_id")
    student_id      = body.get("student_id")
    incoming_app_id = body.get("app_id")

    if not session_id or not student_id or not incoming_app_id:
        return resp(400, {"message": "session_id, student_id, and app_id are required"})

    # 1) Load QR session
    s = sessions_table.get_item(Key={"session_id": session_id})
    session = s.get("Item")
    if not session:
        return resp(400, {"message": "QR session not found"})

    # 2) Check expiry
    now        = int(time.time())
    expires_at = int(session.get("expires_at", 0))
    if now > expires_at:
        return resp(400, {"message": "QR code expired"})

    course_id  = session.get("course_id")
    section_id = session.get("section_id")
    meeting_id = session.get("meeting_id")

    if not course_id or not section_id:
        return resp(500, {"message": "Session missing course_id/section_id"})

    if not meeting_id:
        date_str   = datetime.now().strftime("%Y-%m-%d")
        meeting_id = f"{course_id}#{section_id}#{date_str}#legacy"

    # 3) Load student — STRONGLY CONSISTENT to avoid stale reads
    st = students_table.get_item(
        Key={"student_id": student_id},
        ConsistentRead=True
    )
    if "Item" not in st:
        return resp(400, {"message": f"Student {student_id} not found!"})

    student = st["Item"]

    # 4) Enrollment checks
    section_key = f"{course_id}#{section_id}"
    course_ids  = student.get("course_ids", [])
    section_ids = student.get("section_ids", [])

    not_in_course  = not (isinstance(course_ids, list) and course_id in course_ids)
    not_in_section = not (isinstance(section_ids, list) and section_key in section_ids)

    if not_in_course or not_in_section:
        reason = "NOT_ENROLLED_COURSE" if not_in_course else "NOT_ENROLLED_SECTION"
        msg    = "Not enrolled in this course" if not_in_course else "Not enrolled in this section"

        flag_pk = f"FLAG#{meeting_id}"
        try:
            attendance_table.put_item(Item={
                "course_date": flag_pk,
                "student_id":  student_id,
                "course_id":   course_id,
                "section_id":  section_id,
                "meeting_id":  meeting_id,
                "session_id":  session_id,
                "timestamp":   datetime.now(timezone.utc).isoformat(),
                "record_type": "flag",
                "status":      "flagged",
                "flag_reason": reason,
                "message":     msg
            })
        except Exception:
            pass

        return resp(403, {"message": msg, "flag_reason": reason})

    # 5) app_id bind / mismatch
    saved_app_id = student.get("app_id")

    if not saved_app_id:
        # First-time bind — conditional write so only one request wins
        try:
            students_table.update_item(
                Key={"student_id": student_id},
                UpdateExpression="SET app_id = :a, app_id_bound_at = :t",
                ConditionExpression="attribute_not_exists(app_id)",
                ExpressionAttributeValues={
                    ":a": incoming_app_id,
                    ":t": datetime.now(timezone.utc).isoformat()
                }
            )
            saved_app_id = incoming_app_id

        except ClientError as e:
            if e.response["Error"]["Code"] != "ConditionalCheckFailedException":
                return resp(500, {"message": "Server error", "detail": str(e)})

            # Someone else bound it at the same time — re-read with strong consistency
            st2 = students_table.get_item(
                Key={"student_id": student_id},
                ConsistentRead=True        # ← fix: was eventually consistent before
            )
            saved_app_id = st2.get("Item", {}).get("app_id")

            # If still empty after strong read → genuine server error
            if not saved_app_id:
                return resp(500, {"message": "Could not bind app_id — please try again"})

    # 6) Check mismatch
    if saved_app_id != incoming_app_id:
        flag_pk = f"FLAG#{meeting_id}"
        try:
            attendance_table.put_item(Item={
                "course_date":       flag_pk,
                "student_id":        student_id,
                "course_id":         course_id,
                "section_id":        section_id,
                "meeting_id":        meeting_id,
                "session_id":        session_id,
                "timestamp":         datetime.now(timezone.utc).isoformat(),
                "record_type":       "flag",
                "status":            "flagged",
                "flag_reason":       "APP_ID_MISMATCH",
                "expected_app_id":   saved_app_id,
                "received_app_id":   incoming_app_id,
                "message":           "Student tried to take attendance from a different device/app_id"
            })
        except Exception:
            pass

        return resp(403, {
            "message":     "Device mismatch. Scan rejected.",
            "flag_reason": "APP_ID_MISMATCH"
        })

    # 7) Record QR scan — conditional to prevent duplicates
    scan_pk = f"SCAN#{meeting_id}"
    try:
        attendance_table.put_item(
            Item={
                "course_date": scan_pk,
                "student_id":  student_id,
                "course_id":   course_id,
                "section_id":  section_id,
                "meeting_id":  meeting_id,
                "session_id":  session_id,
                "timestamp":   datetime.now(timezone.utc).isoformat(),
                "record_type": "scan",
                "status":      "scanned"
            },
            ConditionExpression="attribute_not_exists(course_date) AND attribute_not_exists(student_id)"
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return resp(200, {"message": "Already scanned", "meeting_id": meeting_id})
        return resp(500, {"message": "Server error", "detail": str(e)})

    return resp(200, {
        "message":    "Scan recorded",
        "meeting_id": meeting_id,
        "course_id":  course_id,
        "section_id": section_id
    })

```

---

## 6. GetScansForMeeting
**Endpoint:** `POST /getScansForMeeting` — Debug only
Returns all students who scanned for a meeting.

```python
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

```

---

## 7. GetAbsentForMeeting
**Endpoint:** `POST /getAbsentForMeeting`
Returns absent students. Powers the Not Scanned screen.
Uses two-source meeting discovery (qr_sessions + attendance fallback).

```python
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

```

---

## 8. MarkDraftForMeeting
**Endpoint:** `POST /markDraftForMeeting`
Saves manual attendance override. Validates meeting_id exists before writing.

```python
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

```

---

## 9. GetDraftForMeeting
**Endpoint:** `POST /getDraftForMeeting` — Debug only
Returns all draft overrides for a meeting.

```python
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

```

---

## 10. SaveFinalAttendance
**Endpoint:** `POST /saveFinalAttendance`
Locks attendance permanently. Idempotent — re-saving overwrites previous FINAL.

```python
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

```

---

## 11. GetFlagsForSession
**Endpoint:** `POST /getFlagsForSession`
Returns all security flags raised during a QR session.

```python
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

```

---

## 12. GetStudentAttendanceHistory
**Endpoint:** `POST /studentAttendanceHistory`
Returns student attendance history grouped by section.
Priority: FINAL (300) > DRAFT (200) > SCAN (100).

```python
import json
import boto3
from boto3.dynamodb.conditions import Attr
from datetime import datetime
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

def resp(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(clean(body))
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

def _safe_str(x):
    return str(x) if x is not None else ""

def _priority(record_type):
    if record_type == "final":          return 300
    if record_type == "draft_override": return 200
    if record_type == "scan":           return 100
    return 0

def _pick_time(it):
    for k in ["saved_at", "updated_at", "timestamp", "created_at"]:
        v = it.get(k)
        if v is None:
            continue
        if isinstance(v, (int, float, Decimal)):
            return str(int(v))
        return _safe_str(v)
    return ""

def _extract_from_final_pk(pk):
    parts = pk.split("#")
    if len(parts) >= 4:
        return parts[1], parts[2], parts[3]
    return None, None, None

def _extract_from_meeting_id(meeting_id):
    parts = meeting_id.split("#")
    if len(parts) >= 3:
        return parts[0], parts[1], parts[2]
    return None, None, None

def _normalize_item(it):
    pk = _safe_str(it.get("course_date"))
    if not pk:
        return None

    course_id  = it.get("course_id")
    section_id = it.get("section_id")
    date       = it.get("date")

    if pk.startswith("FINAL#"):
        c, s, d = _extract_from_final_pk(pk)
        course_id  = course_id  or c
        section_id = section_id or s
        date       = date       or d
        status = _safe_str(it.get("status")).lower()
        if status not in ["present", "absent"]:
            return None
        return {"course_id": course_id, "section_id": section_id, "date": date,
                "record_type": "final", "status": status, "time_key": _pick_time(it)}

    if pk.startswith("DRAFT#"):
        meeting_id = pk.replace("DRAFT#", "", 1)
        c, s, d = _extract_from_meeting_id(meeting_id)
        course_id  = course_id  or c
        section_id = section_id or s
        date       = date       or d
        status = _safe_str(it.get("status")).lower()
        if status not in ["present", "absent"]:
            return None
        return {"course_id": course_id, "section_id": section_id, "date": date,
                "record_type": "draft_override", "status": status, "time_key": _pick_time(it)}

    if pk.startswith("SCAN#"):
        meeting_id = pk.replace("SCAN#", "", 1)
        c, s, d = _extract_from_meeting_id(meeting_id)
        course_id  = course_id  or c
        section_id = section_id or s
        date       = date       or d
        return {"course_id": course_id, "section_id": section_id, "date": date,
                "record_type": "scan", "status": "present", "time_key": _pick_time(it)}

    return None

def _better(a, b):
    if a is None: return b
    if b is None: return a
    pa = _priority(a["record_type"])
    pb = _priority(b["record_type"])
    if pb > pa: return b
    if pa > pb: return a
    if _safe_str(b.get("time_key")) > _safe_str(a.get("time_key")):
        return b
    return a

def lambda_handler(event, context):
    body = parse_body(event)
    if body is None:
        return resp(400, {"message": "Invalid JSON body"})

    student_id = body.get("student_id")
    limit      = int(body.get("limit") or 100)
    if not student_id:
        return resp(400, {"message": "student_id is required"})

    items = []
    last_key = None
    while True:
        kwargs = {"FilterExpression": Attr("student_id").eq(student_id)}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = attendance_table.scan(**kwargs)
        items.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
        if len(items) > 8000:
            break

    best_by_day = {}
    for it in items:
        norm = _normalize_item(it)
        if not norm:
            continue
        c = norm.get("course_id")
        s = norm.get("section_id")
        d = norm.get("date")
        if not c or not s or not d:
            continue
        key = f"{c}#{s}#{d}"
        best_by_day[key] = _better(best_by_day.get(key), norm)

    rows = []
    for key, norm in best_by_day.items():
        rows.append({
            "course_id":  norm["course_id"],
            "section_id": norm["section_id"],
            "date":       norm["date"],
            "status":     norm["status"],
            "source":     norm["record_type"],
            "time_key":   norm.get("time_key", "")
        })

    rows.sort(key=lambda x: (x["date"], x.get("time_key", "")), reverse=True)
    rows = rows[:max(1, limit)]

    grouped = {}
    for r in rows:
        k = f'{r["course_id"]}#{r["section_id"]}'
        grouped.setdefault(k, {"course_id": r["course_id"], "section_id": r["section_id"], "days": []})
        grouped[k]["days"].append({"date": r["date"], "status": r["status"], "source": r["source"]})

    sections     = sorted(grouped.values(), key=lambda x: (x["course_id"], x["section_id"]))
    total_days   = len(rows)
    present_days = sum(1 for r in rows if r["status"] == "present")

    return resp(200, {
        "student_id":     student_id,
        "days_count":     total_days,
        "present_days":   present_days,
        "absent_days":    total_days - present_days,
        "sections_count": len(sections),
        "sections":       sections,
        "flat_days":      rows
    })

```

---

## 13. AutoFinalizeDailyAttendance
**Trigger:** EventBridge — every day 23:59 Cairo time
Auto-finalizes sections with no FINAL record. Marks all students present.

```python
import json
import boto3
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from boto3.dynamodb.conditions import Attr, Key

dynamodb = boto3.resource("dynamodb")
courses_table    = dynamodb.Table("courses")
students_table   = dynamodb.Table("students")
attendance_table = dynamodb.Table("attendance")
CAIRO = ZoneInfo("Africa/Cairo")

def today_date_str():
    return datetime.now(CAIRO).strftime("%Y-%m-%d")

def today_dow():
    return datetime.now(CAIRO).strftime("%a").upper()[:3]

def scan_students_for_section(section_key):
    roster = []
    last_key = None
    while True:
        kwargs = {"FilterExpression": Attr("section_ids").contains(section_key)}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = students_table.scan(**kwargs)
        roster.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
    return roster

def final_exists(pk):
    r = attendance_table.query(KeyConditionExpression=Key("course_date").eq(pk), Limit=1)
    return r.get("Count", 0) > 0

def get_scan_records(course_id, section_id, date_str):
    scans = []
    last_key = None
    needle = f"{course_id}#{section_id}#{date_str}#"
    while True:
        kwargs = {}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = attendance_table.scan(**kwargs)
        for it in r.get("Items", []):
            pk = it.get("course_date", "")
            if isinstance(pk, str) and pk.startswith("SCAN#") and needle in pk:
                scans.append(it)
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
    return scans

def get_draft_records(course_id, section_id, date_str):
    drafts = []
    last_key = None
    needle = f"{course_id}#{section_id}#{date_str}#"
    while True:
        kwargs = {}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = attendance_table.scan(**kwargs)
        for it in r.get("Items", []):
            pk = it.get("course_date", "")
            if isinstance(pk, str) and pk.startswith("DRAFT#") and needle in pk:
                drafts.append(it)
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break
    return drafts

def lambda_handler(event, context):
    date_str = today_date_str()
    dow      = today_dow()
    now      = datetime.now(timezone.utc).isoformat()

    courses  = []
    last_key = None
    while True:
        kwargs = {}
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key
        r = courses_table.scan(**kwargs)
        courses.extend(r.get("Items", []))
        last_key = r.get("LastEvaluatedKey")
        if not last_key:
            break

    for course in courses:
        course_id = course.get("course_id")
        sections  = course.get("sections", [])
        for sec in sections:
            section_id   = sec.get("section_id")
            meeting_days = sec.get("meeting_days", [])
            if not isinstance(meeting_days, list):
                meeting_days = [meeting_days]
            meeting_days = [str(x).upper()[:3] for x in meeting_days]
            if dow not in meeting_days:
                continue

            final_pk = f"FINAL#{course_id}#{section_id}#{date_str}"
            if final_exists(final_pk):
                continue

            roster     = scan_students_for_section(f"{course_id}#{section_id}")
            roster_ids = [s["student_id"] for s in roster]
            if not roster_ids:
                continue

            scans      = get_scan_records(course_id, section_id, date_str)
            drafts     = get_draft_records(course_id, section_id, date_str)
            scan_ids   = {s.get("student_id") for s in scans}
            draft_map  = {d["student_id"]: d.get("status") for d in drafts}

            final_map = {}
            if len(scan_ids) == 0 and len(draft_map) == 0:
                for sid in roster_ids:
                    final_map[sid] = "present"
            else:
                for sid in roster_ids:
                    final_map[sid] = "absent"
                for sid in scan_ids:
                    final_map[sid] = "present"
                for sid, status in draft_map.items():
                    final_map[sid] = status

            present_count = 0
            absent_count  = 0
            with attendance_table.batch_writer() as batch:
                for sid, status in final_map.items():
                    if status == "present":
                        present_count += 1
                    else:
                        absent_count += 1
                    batch.put_item(Item={
                        "course_date": final_pk, "student_id": sid,
                        "course_id": course_id, "section_id": section_id,
                        "date": date_str, "status": status,
                        "updated_at": now, "record_type": "final", "auto_finalized": True
                    })
                batch.put_item(Item={
                    "course_date": final_pk, "student_id": "_META_",
                    "record_type": "final_meta", "course_id": course_id,
                    "section_id": section_id, "date": date_str,
                    "present_count": present_count, "absent_count": absent_count,
                    "auto_finalized": True, "updated_at": now
                })

    return {"statusCode": 200, "body": json.dumps({"message": "auto finalize completed", "date": date_str})}

```

---

## 14. MarkAttendance (Legacy — Not Used)
**Endpoint:** `POST /markAttendance`
Old prototype. Not integrated with FINAL/DRAFT/SCAN system. Not called by either app.

```python
import json
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    dynamodb = boto3.resource("dynamodb")
    attendance_table = dynamodb.Table("attendance")
    students_table   = dynamodb.Table("students")

    if "body" in event and event["body"]:
        body = json.loads(event["body"])
    else:
        body = event

    student_id = body.get("student_id")
    course_id  = body.get("course_id")

    if not student_id or not course_id:
        return {"statusCode": 400, "body": json.dumps({"message": "student_id and course_id are required"})}

    date_str    = datetime.now().strftime("%Y-%m-%d")
    course_date = f"{course_id}#{date_str}"

    response = students_table.get_item(Key={"student_id": student_id})
    if "Item" not in response:
        return {"statusCode": 400, "body": json.dumps({"message": f"Student {student_id} not found!"})}

    try:
        attendance_table.put_item(
            Item={
                "course_date": course_date, "student_id": student_id,
                "course_id": course_id, "timestamp": datetime.now().isoformat(), "status": "present"
            },
            ConditionExpression="attribute_not_exists(course_date) AND attribute_not_exists(student_id)"
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return {"statusCode": 200, "body": json.dumps({"message": f"Attendance already marked for {student_id} in {course_id} on {date_str}"})}
        raise

    return {"statusCode": 200, "body": json.dumps({"message": f"Attendance recorded for {student_id} in {course_id} on {date_str}"})}

```
