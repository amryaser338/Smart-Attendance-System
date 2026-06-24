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
