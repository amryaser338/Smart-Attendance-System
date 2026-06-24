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
