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
