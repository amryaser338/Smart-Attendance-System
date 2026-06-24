import boto3
import pandas as pd

# ── CONFIG ────────────────────────────────────────────────────────────────────
EXCEL_FILE = "AttendanceTools\\courses_import.xlsx"
TABLE_NAME   = "courses"
AWS_REGION   = "il-central-1"
# ─────────────────────────────────────────────────────────────────────────────

# NOTE: Never commit real AWS credentials to a public repository.
# Use environment variables, AWS CLI config, or a .env file (gitignored) instead.
dynamodb = boto3.resource(
    "dynamodb",
    region_name=AWS_REGION,
    aws_access_key_id="YOUR_ACCESS_KEY_HERE",
    aws_secret_access_key="YOUR_SECRET_KEY_HERE"
)
table    = dynamodb.Table(TABLE_NAME)

df = pd.read_excel(EXCEL_FILE, dtype=str)
df = df.fillna("")

# Group rows by course_id (one course can have multiple section rows)
courses = {}
for _, row in df.iterrows():
    course_id   = row["course_id"].strip()
    course_name = row["course_name"].strip()
    section_id  = row["section_id"].strip()
    doctor_ids  = [d.strip() for d in row["doctor_ids"].split(",") if d.strip()]
    meeting_days= [m.strip().upper()[:3] for m in row["meeting_days"].split(",") if m.strip()]

    if course_id not in courses:
        courses[course_id] = {
            "course_id":   course_id,
            "course_name": course_name,
            "sections":    []
        }

    courses[course_id]["sections"].append({
        "section_id":   section_id,
        "doctor_ids":   doctor_ids,
        "meeting_days": meeting_days
    })

# Upload each course to DynamoDB
for course_id, item in courses.items():
    table.put_item(Item=item)
    print(f"Uploaded: {course_id} — {len(item['sections'])} section(s)")

print("\nDone!")
