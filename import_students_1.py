import pandas as pd
import boto3

# =========================
# CONFIG
# =========================
EXCEL_FILE = "AttendanceTools\\students_import_template.xlsx"
TABLE_NAME = "students"
AWS_REGION = "il-central-1"

# NOTE: Never commit real AWS credentials to a public repository.
# Use environment variables, AWS CLI config, or a .env file (gitignored) instead.
AWS_ACCESS_KEY = "YOUR_ACCESS_KEY_HERE"
AWS_SECRET_KEY = "YOUR_SECRET_KEY_HERE"

# =========================
# CONNECT TO DYNAMODB
# =========================
dynamodb = boto3.resource(
    "dynamodb",
    region_name=AWS_REGION,
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY
)

table = dynamodb.Table(TABLE_NAME)

# =========================
# READ EXCEL
# =========================
df = pd.read_excel(EXCEL_FILE, sheet_name="students_import")

required_columns = ["student_id", "name", "email", "major_id", "course_id", "section_id"]
missing_cols = [col for col in required_columns if col not in df.columns]

if missing_cols:
    raise ValueError(f"Missing required columns in Excel: {missing_cols}")

# Remove completely empty rows
df = df.dropna(how="all")

# Convert to string and clean spaces
for col in required_columns:
    df[col] = df[col].astype(str).str.strip()

# Remove rows with missing essential values
df = df[
    (df["student_id"] != "") &
    (df["name"] != "") &
    (df["course_id"] != "") &
    (df["section_id"] != "")
]

# =========================
# GROUP BY STUDENT
# =========================
grouped = df.groupby("student_id")

for student_id, group in grouped:
    first_row = group.iloc[0]

    course_ids = sorted(group["course_id"].dropna().astype(str).str.strip().unique().tolist())
    section_ids = sorted(
        (group["course_id"].astype(str).str.strip() + "#" + group["section_id"].astype(str).str.strip())
        .unique()
        .tolist()
    )

    item = {
        "student_id": student_id,
        "name": first_row["name"],
        "email": first_row["email"],
        "major_id": first_row["major_id"],
        "course_ids": course_ids,
        "section_ids": section_ids
    }

    table.put_item(Item=item)
    print(f"Uploaded: {student_id} -> {len(course_ids)} course(s), {len(section_ids)} section(s)")

print("Done!")
