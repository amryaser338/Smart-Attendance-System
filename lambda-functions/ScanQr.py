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
