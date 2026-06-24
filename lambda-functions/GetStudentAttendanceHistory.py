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
