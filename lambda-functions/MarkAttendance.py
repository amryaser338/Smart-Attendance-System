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
