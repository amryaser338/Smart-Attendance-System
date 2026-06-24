# Smart Attendance System — Full Technical Documentation

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [AWS Infrastructure](#3-aws-infrastructure)
4. [DynamoDB Tables — Full Schema](#4-dynamodb-tables--full-schema)
5. [Lambda Functions — Complete Reference](#5-lambda-functions--complete-reference)
6. [API Gateway Endpoints](#6-api-gateway-endpoints)
7. [EventBridge Scheduler — Auto-Finalize](#7-eventbridge-scheduler--auto-finalize)
8. [Attendance State Machine & Priority Logic](#8-attendance-state-machine--priority-logic)
9. [Instructor App — Screens & Flow](#9-instructor-app--screens--flow)
10. [Student App — Screens & Flow](#10-student-app--screens--flow)
11. [Security & Device Binding (app_id)](#11-security--device-binding-app_id)
12. [Flag System](#12-flag-system)
13. [Complete Attendance Scenarios](#13-complete-attendance-scenarios)
14. [Lambda Functions NOT Used in the App (Debug Only)](#14-lambda-functions-not-used-in-the-app-debug-only)
15. [Timezone & Date Handling](#15-timezone--date-handling)
16. [Future Improvements](#16-future-improvements)

---

## 1. Project Overview

**Smart Attendance** is a cloud-based, serverless attendance system built as a graduation project. It serves two types of users:

- **Instructors (Doctors):** Use a Flutter desktop/laptop app to take attendance for their courses and sections.
- **Students:** Use a Flutter mobile app to scan QR codes and view their attendance history.

The system supports three attendance modes that can be combined:

| Mode | Description |
|------|-------------|
| **Manual** | Instructor manually checks/unchecks each student |
| **QR Scan** | Instructor generates a QR code; students scan it with their phones |
| **Auto-Finalize** | End-of-day automation marks everyone present if no attendance was taken |

**Current state:** Prototype — no real login page exists yet. The instructor types their `doctor_id` manually; the student types their `student_id` manually. Real authentication (Cognito/JWT) is planned for the future.

---

## 2. System Architecture

```
┌─────────────────────────────┐       ┌──────────────────────────────┐
│     Instructor Flutter App  │       │      Student Flutter App     │
│       (Desktop / Laptop)    │       │         (Mobile)             │
└────────────┬────────────────┘       └──────────────┬───────────────┘
             │  HTTPS POST                           │  HTTPS POST
             ▼                                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS API Gateway (HTTP API)                        │
│                  Name: SmartAttendanceAPI                           │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ Invoke
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Lambda Functions (Python 3.x)                 │
└──────┬──────────────┬────────────────┬───────────────┬─────────────┘
       │              │                │               │
       ▼              ▼                ▼               ▼
┌──────────┐  ┌─────────────┐  ┌───────────┐  ┌────────────────┐
│attendance│  │   courses   │  │qr_sessions│  │    students    │
│(DynamoDB)│  │(DynamoDB)   │  │(DynamoDB) │  │  (DynamoDB)    │
└──────────┘  └─────────────┘  └───────────┘  └────────────────┘

                               ▲
                               │ Scheduled trigger (daily)
┌──────────────────────────────┴──────────────────────────────────────┐
│               Amazon EventBridge Scheduler                           │
│        Name: smart-attendance-auto-finalize                          │
│        Cron: 59 23 * * ? *  (23:59 Cairo time every day)           │
└─────────────────────────────────────────────────────────────────────┘
```

**AWS Region:** il-central-1 (Israel / Tel Aviv)

---

## 3. AWS Infrastructure

| Service | Resource Name | Purpose |
|---------|--------------|---------|
| DynamoDB | `attendance` | All attendance records (SCAN, DRAFT, FINAL, FLAG) |
| DynamoDB | `courses` | Course catalog with sections and meeting days |
| DynamoDB | `students` | Student enrollment, device binding |
| DynamoDB | `qr_sessions` | QR session records (60-second windows) |
| Lambda | (12 functions) | All business logic — see Section 5 |
| API Gateway | SmartAttendanceAPI | Single HTTP API exposing all Lambda endpoints |
| EventBridge Scheduler | smart-attendance-auto-finalize | Nightly auto-finalization job |

---

## 4. DynamoDB Tables — Full Schema

### 4.1 `attendance` Table

This is the **core table**. It stores every type of attendance record using a prefix pattern on the partition key to separate record types.

**Keys:**
- Partition Key (PK): `course_date` (String)
- Sort Key (SK): `student_id` (String)
- Capacity mode: On-demand

**Partition Key Prefix Patterns:**

| Prefix | Format | Purpose |
|--------|--------|---------|
| `FINAL#` | `FINAL#{course_id}#{section_id}#{date}` | Final locked attendance for a session |
| `SCAN#` | `SCAN#{meeting_id}` | Raw QR scan records |
| `DRAFT#` | `DRAFT#{meeting_id}` | Instructor manual overrides during a QR session |
| `FLAG#` | `FLAG#{meeting_id}` | Security flag records (wrong device, not enrolled) |

**Example PKs:**
```
FINAL#CSE101#SEC1#2026-03-02
SCAN#CSE101#SEC1#2026-03-02#a1b2c3d4
DRAFT#CSE101#SEC1#2026-03-02#a1b2c3d4
FLAG#CSE101#SEC1#2026-03-02#a1b2c3d4
```

**Full list of fields per record type:**

**FINAL record:**
```json
{
  "course_date": "FINAL#CSE101#SEC1#2026-03-02",
  "student_id":  "S001",
  "status":      "present" | "absent",
  "record_type": "final",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "date":        "2026-03-02",
  "saved_at":    "2026-03-02T10:30:00+00:00"
}
```

**FINAL _META_ record** (one per FINAL partition, used as a marker):
```json
{
  "course_date": "FINAL#CSE101#SEC1#2026-03-02",
  "student_id":  "_META_",
  "record_type": "final_meta",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "date":        "2026-03-02",
  "saved_at":    "2026-03-02T10:30:00+00:00"
}
```

**FINAL record (auto-finalized by EventBridge):**
```json
{
  "course_date":      "FINAL#CSE101#SEC1#2026-03-02",
  "student_id":       "S001",
  "status":           "present",
  "record_type":      "final",
  "course_id":        "CSE101",
  "section_id":       "SEC1",
  "date":             "2026-03-02",
  "updated_at":       "2026-03-02T21:59:00+00:00",
  "auto_finalized":   true
}
```

**SCAN record:**
```json
{
  "course_date": "SCAN#CSE101#SEC1#2026-03-02#a1b2c3d4",
  "student_id":  "S001",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "meeting_id":  "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "session_id":  "uuid-of-qr-session",
  "timestamp":   "2026-03-02T08:15:00+00:00",
  "record_type": "scan",
  "status":      "scanned"
}
```

**DRAFT record:**
```json
{
  "course_date": "DRAFT#CSE101#SEC1#2026-03-02#a1b2c3d4",
  "student_id":  "S003",
  "status":      "present" | "absent",
  "record_type": "draft_override",
  "updated_at":  "2026-03-02T08:20:00+00:00"
}
```

**FLAG record:**
```json
{
  "course_date":       "FLAG#CSE101#SEC1#2026-03-02#a1b2c3d4",
  "student_id":        "S999",
  "course_id":         "CSE101",
  "section_id":        "SEC1",
  "meeting_id":        "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "session_id":        "uuid-of-qr-session",
  "timestamp":         "2026-03-02T08:16:00+00:00",
  "record_type":       "flag",
  "status":            "flagged",
  "flag_reason":       "APP_ID_MISMATCH" | "NOT_ENROLLED_COURSE" | "NOT_ENROLLED_SECTION",
  "message":           "Student tried to take attendance from a different device/app_id",
  "expected_app_id":   "original-uuid",
  "received_app_id":   "different-uuid"
}
```

---

### 4.2 `courses` Table

Stores the full course catalog. Each item is one course with all its sections embedded as a list.

**Keys:**
- Partition Key: `course_id` (String)
- No sort key
- Capacity mode: On-demand

**Item structure (example: CSE101):**
```json
{
  "course_id":   "CSE101",
  "course_name": "electronics",
  "sections": [
    {
      "section_id":   "SEC1",
      "doctor_ids":   ["D001"],
      "meeting_days": ["SUN", "MON", "FRI", "TUE", "WED", "THU"]
    },
    {
      "section_id":   "SEC2",
      "doctor_ids":   ["D001", "D002"],
      "meeting_days": ["TUE", "WED"]
    }
  ]
}
```

**Field notes:**
- `meeting_days`: List of 3-letter uppercase day abbreviations: `SUN`, `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`
- `doctor_ids`: A section can have more than one doctor assigned
- A doctor sees only sections where their `doctor_id` appears in `doctor_ids` AND the section meets today

---

### 4.3 `students` Table

Stores one record per student. Enrollment is stored as lists on the student record.

**Keys:**
- Partition Key: `student_id` (String)
- No sort key
- Capacity mode: On-demand

**Item structure (example: S001):**
```json
{
  "student_id":  "S001",
  "name":        "Amr Yasser",
  "email":       "amr2106377@miuegypt.edu.eg",
  "major_id":    "ENG01",
  "course_ids":  ["CSE101"],
  "section_ids": ["CSE101#SEC1"],
  "app_id":      "999"
}
```

**Field notes:**
- `section_ids`: Stored as `"{course_id}#{section_id}"` compound strings. This is the lookup key used across the system.
- `course_ids`: Just the plain `course_id` strings.
- `app_id`: The unique identifier of the student's phone/app installation. Set on first QR scan and never changed unless student reinstalls the app. Used for anti-proxy device binding.
- `app_id_bound_at`: ISO timestamp of when `app_id` was first bound (set alongside `app_id`).

---

### 4.4 `qr_sessions` Table

Each QR code generation creates one record here.

**Keys:**
- Partition Key: `session_id` (String)
- No sort key
- Capacity mode: On-demand

**Item structure:**
```json
{
  "session_id":  "550e8400-e29b-41d4-a716-446655440000",
  "meeting_id":  "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "created_at":  1771858600,
  "expires_at":  1771858660
}
```

**Field notes:**
- `created_at` and `expires_at` are **Unix epoch timestamps** (integer seconds, not milliseconds).
- `expires_at = created_at + 60` (60 seconds window).
- `session_id` is a UUID v4.
- `meeting_id` format: `{course_id}#{section_id}#{date}#{8-char hex UUID fragment}` — example: `CSE101#SEC1#2026-03-02#a1b2c3d4`

---

## 5. Lambda Functions — Complete Reference

All Lambda functions are written in Python 3.x and use `boto3` to access DynamoDB. All responses include CORS headers (`Access-Control-Allow-Origin: *`). All time-sensitive operations use the `Africa/Cairo` timezone.

---

### 5.1 `GetDoctorCoursesSections`

**API Endpoint:** `POST /getDoctorCoursesSections`

**Purpose:** The first call the instructor app makes after the doctor enters their ID. Returns only the courses and sections that (a) have this doctor assigned, AND (b) are scheduled to meet **today** (based on Cairo timezone). This means a doctor will only see their Monday sections on Mondays, their Tuesday sections on Tuesdays, etc.

**Input (JSON body):**
```json
{
  "doctor_id": "D001"
}
```

**How it works:**
1. Scans the entire `courses` table (paginated, safe for large tables).
2. Calculates today's day-of-week in Cairo time as a 3-letter abbreviation (e.g., `MON`).
3. For each course, iterates through all sections.
4. Keeps only sections where: `doctor_id` is in the section's `doctor_ids` list, AND today's DOW is in the section's `meeting_days` list.
5. Returns only courses that have at least one matching section.

**Output (200):**
```json
{
  "doctor_id": "D001",
  "today": "MON",
  "count": 1,
  "courses": [
    {
      "course_id": "CSE101",
      "course_name": "electronics",
      "sections": ["SEC1", "SEC2"]
    }
  ]
}
```

**Output (400):** Missing `doctor_id`
```json
{ "message": "doctor_id is required (in JSON body or ?doctor_id=...)" }
```

**Notes:**
- `doctor_id` can also be passed as a URL query parameter (`?doctor_id=D001`) instead of in the JSON body.
- If a doctor has no courses meeting today, `courses` will be an empty list and `count` will be 0.
- Sections within a course result are sorted alphabetically.

---

### 5.2 `GetStudentsForSection`

**API Endpoint:** `POST /getStudentsForSection`

**Purpose:** Returns the full roster of students enrolled in a specific course section. Called when the instructor opens a section to take attendance.

**Input (JSON body):**
```json
{
  "course_id": "CSE101",
  "section_id": "SEC1"
}
```

**How it works:**
1. Builds a `section_key` = `"CSE101#SEC1"`.
2. Scans the `students` table filtering for students whose `section_ids` list contains this `section_key`.
3. Only returns `student_id` and `name` fields (projection).
4. Returns students sorted by `student_id`.

**Output (200):**
```json
{
  "students": [
    { "student_id": "S001", "name": "Amr Yasser" },
    { "student_id": "S002", "name": "Sara Ahmed" }
  ],
  "count": 2
}
```

**Output (400):** Missing fields
```json
{ "message": "course_id and section_id are required" }
```

---

### 5.3 `GetLatestMeetingForSectionToday`

**API Endpoint:** `POST /getLatestMeetingForSectionToday`

**Purpose:** The most important "load" function. Called every time the instructor opens a section. It checks existing records and returns the current attendance state with a strict priority order. This prevents the instructor from accidentally overwriting existing attendance.

**Input (JSON body):**
```json
{
  "course_id": "CSE101",
  "section_id": "SEC1"
}
```

**Priority logic (in order):**

**Priority 1 — FINAL exists:**
If a `FINAL#CSE101#SEC1#2026-03-02` partition exists in the attendance table, load all those records and return them. The instructor sees the locked attendance list. No further checks needed.

**Priority 2 — Any QR session happened today (SCAN or DRAFT records exist):**
If no FINAL exists, scan `qr_sessions` to find **ALL** sessions for this course+section created today (by checking `meeting_id` contains today's date). SCAN and DRAFT records are accumulated across **all** meetings today, not just the latest one. Compute each student's status:
- Base: student is **absent**
- If student appears in any SCAN record from any meeting today → **present**
- If student has a DRAFT record from any meeting today → DRAFT **overrides** SCAN. If the same student has drafts in multiple meetings, the newest meeting's draft wins.

If QR sessions exist but zero activity across all of them → fall through to Priority 3.

**Priority 3 — Default (no QR was ever generated today):**
No FINAL, no QR sessions at all → return all students as **present** with `source: "default_no_meeting"` or `source: "default_meeting_no_activity"`.

**Output (200) — FINAL mode:**
```json
{
  "found": true,
  "course_id": "CSE101",
  "section_id": "SEC1",
  "date": "2026-03-02",
  "mode": "FINAL",
  "has_final": true,
  "meeting_id": null,
  "session_id": null,
  "present_count": 2,
  "absent_count": 1,
  "students": [
    { "no": 1, "student_id": "S001", "status": "present", "source": "final" },
    { "no": 2, "student_id": "S002", "status": "absent",  "source": "final" },
    { "no": 3, "student_id": "S003", "status": "present", "source": "final" }
  ]
}
```

**Output (200) — DRAFT mode (QR session happened):**
```json
{
  "found": true,
  "course_id": "CSE101",
  "section_id": "SEC1",
  "date": "2026-03-02",
  "mode": "DRAFT",
  "has_final": false,
  "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "session_id": "550e8400-...",
  "present_count": 2,
  "absent_count": 1,
  "scan_count": 2,
  "draft_override_count": 1,
  "students": [
    { "no": 1, "student_id": "S001", "name": "Amr Yasser", "status": "present", "source": "scan+draft" },
    { "no": 2, "student_id": "S002", "name": "Sara Ahmed",  "status": "absent",  "source": "scan+draft" }
  ],
  "debug": {
    "scan_pk":  "SCAN#CSE101#SEC1#2026-03-02#a1b2c3d4",
    "draft_pk": "DRAFT#CSE101#SEC1#2026-03-02#a1b2c3d4"
  }
}
```

**Output (200) — DEFAULT mode:**
```json
{
  "found": true,
  "course_id": "CSE101",
  "section_id": "SEC1",
  "date": "2026-03-02",
  "mode": "DEFAULT",
  "has_final": false,
  "meeting_id": null,
  "session_id": null,
  "present_count": 3,
  "absent_count": 0,
  "students": [
    { "no": 1, "student_id": "S001", "name": "Amr Yasser", "status": "present", "source": "default_no_meeting" }
  ]
}
```

**Notes:**
- `_META_` records in FINAL partitions are filtered out and never included in the student list.
- The `mode` field tells the app exactly what state was found: `"FINAL"`, `"DRAFT"`, or `"DEFAULT"`.
- `meeting_id` and `session_id` returned in DRAFT mode are the **latest** session's values (for reference only — all meetings today were already merged).
- The old `debug` block with `scan_pk`/`draft_pk` is removed since multiple meetings are now merged.

---

### 5.4 `GenerateQr`

**API Endpoint:** `POST /generateQr`

**Purpose:** Creates a new QR session valid for 60 seconds. The instructor app calls this when the doctor clicks "Generate QR". The returned `session_id` is encoded into a QR code displayed on the projector screen.

**Input (JSON body):**
```json
{
  "course_id":  "CSE101",
  "section_id": "SEC1"
}
```

**How it works:**
1. Gets today's day-of-week in Cairo time.
2. Looks up the course in `courses` table.
3. Finds the specific section within the course.
4. Checks if today's DOW is in `meeting_days`. If not → reject with 403.
5. Calls `get_or_create_meeting_id`: scans `qr_sessions` for any existing session for this `course+section+date`. If one exists → **reuses the same `meeting_id`** from the earliest session today. If none exists → generates a new `meeting_id` as `{course_id}#{section_id}#{date}#{8-char-hex}`.
6. Generates a new `session_id` (UUID v4) — each QR gets a fresh `session_id` for expiry tracking.
7. Sets `expires_at = now + 60` seconds (Unix epoch).
8. Writes the new session record to `qr_sessions`.
9. Returns the session data.

**Output (200):**
```json
{
  "session_id":  "550e8400-e29b-41d4-a716-446655440000",
  "meeting_id":  "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "expires_at":  1771858660
}
```

**Output (403) — Not a scheduled meeting day:**
```json
{
  "message":      "Attendance not allowed today for this section",
  "today":        "SUN",
  "meeting_days": ["TUE", "WED"]
}
```

**Output (400) — Course/section not found:**
```json
{ "message": "Course CSE101 not found" }
```

**Important notes:**
- Each call to `/generateQr` creates a new `session_id` (for expiry tracking) but **reuses the same `meeting_id`** if a QR was already generated today for this course+section. This means all QR sessions on the same day share one `meeting_id`, so all scans accumulate under `SCAN#same_meeting_id`.
- The QR code encodes the `session_id` value.
- `expires_at` is Unix epoch in **seconds** (not milliseconds).
- After 60 seconds, the session is considered expired and student scans will be rejected.

---

### 5.5 `ScanQr`

**API Endpoint:** `POST /scanQr`

**Purpose:** Called by the student app when a student scans a QR code. Validates the session, checks enrollment, binds the device, and records the scan as a DRAFT record.

**Input (JSON body):**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "student_id": "S001",
  "app_id":     "unique-app-installation-uuid"
}
```

**How it works (step by step):**

**Step 1 — Load QR session:**
Fetch the session from `qr_sessions` by `session_id`. If not found → 400 error.

**Step 2 — Check expiry:**
Compare current Unix time against `expires_at`. If expired → 400 error. (Does NOT rely on DynamoDB TTL timing as that can be delayed.)

**Step 3 — Load student:**
Fetch student from `students` table by `student_id`. If not found → 400 error.

**Step 4 — Enrollment check:**
- Check if `course_id` is in the student's `course_ids` list.
- Check if `"{course_id}#{section_id}"` is in the student's `section_ids` list.
- If either check fails → write a FLAG record to `FLAG#{meeting_id}` with reason `NOT_ENROLLED_COURSE` or `NOT_ENROLLED_SECTION`, then return 403.

**Step 5 — Device binding (app_id):**
- Read the student's `app_id` from the `students` table.
- If no `app_id` is stored yet: bind `incoming_app_id` to the student using a conditional write (`attribute_not_exists(app_id)`). This ensures only the first scan ever sets the `app_id`.
- If `app_id` is already stored and does NOT match `incoming_app_id` → write a FLAG record with reason `APP_ID_MISMATCH` and return 403.

**Step 6 — Record the scan:**
Write a `SCAN#{meeting_id}` record. Uses a conditional write to prevent duplicate scans (same student can't scan twice for the same meeting).

**Output (200) — Successful scan:**
```json
{
  "message":    "Scan recorded (draft)",
  "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "course_id":  "CSE101",
  "section_id": "SEC1"
}
```

**Output (200) — Already scanned:**
```json
{ "message": "Already scanned (draft)", "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4" }
```

**Output (400) — QR expired:**
```json
{ "message": "QR code expired" }
```

**Output (403) — Device mismatch:**
```json
{ "message": "Device mismatch. Scan rejected.", "flag_reason": "APP_ID_MISMATCH" }
```

**Output (403) — Not enrolled:**
```json
{ "message": "Not enrolled in this section", "flag_reason": "NOT_ENROLLED_SECTION" }
```

**Important notes:**
- A scan is recorded as a **DRAFT** record, not a FINAL record. It only becomes part of the official record when the instructor clicks "Save Final Attendance."
- The `app_id` is the unique identifier of the student's mobile app installation, sent by the Flutter app.

---

### 5.6 `GetScansForMeeting`

**API Endpoint:** `POST /getScansForMeeting`

**Purpose:** Returns the list of all students who successfully scanned the QR code for a specific meeting. Used by the instructor app to know who has scanned so far.

**Input:**
```json
{ "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4" }
```

**How it works:**
Queries the `attendance` table with `course_date = "SCAN#{meeting_id}"`. Collects all `student_id` values. Deduplicates and sorts.

**Output (200):**
```json
{
  "meeting_id":          "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "scan_pk":             "SCAN#CSE101#SEC1#2026-03-02#a1b2c3d4",
  "scanned_student_ids": ["S001", "S002"],
  "count": 2
}
```

---

### 5.7 `GetAbsentForMeeting`

**API Endpoint:** `POST /getAbsentForMeeting`

**Purpose:** Returns the list of students who are currently **absent** for a meeting — meaning they did NOT scan the QR and were NOT manually overridden to present. This is what powers the "Not Scanned" screen in the instructor app after the QR session closes.

**Input:**
```json
{
  "course_id":  "CSE101",
  "section_id": "SEC1",
  "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4"
}
```

**How it works:**
1. Scans roster from `students` table for students in `CSE101#SEC1`.
2. Extracts the date from `meeting_id` (format: `course#section#date#hex`) then scans `qr_sessions` to find **all** meeting_ids for this `course+section+date` — not just the one passed in.
3. Accumulates SCAN records across all meetings today → one unified set of scanned student IDs.
4. Accumulates DRAFT records across all meetings today, sorted oldest→newest so newer drafts win.
5. For each student in the roster:
   - Start with: present if scanned in **any** meeting today, absent if not.
   - If a DRAFT override exists from **any** meeting today → override wins.
6. Returns only students whose final computed status is **absent**.

**Output (200):**
```json
{
  "course_id":        "CSE101",
  "section_id":       "SEC1",
  "meeting_id":       "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "meetings_today":   ["CSE101#SEC1#2026-03-02#a1b2c3d4"],
  "absent_count":     1,
  "absent_students":  [
    { "student_id": "S003", "name": "Nour Ali" }
  ]
}
```

**`meetings_today`** is the list of all meeting_ids found for this course+section today. Useful for debugging.

---

### 5.8 `MarkDraftForMeeting`

**API Endpoint:** `POST /markDraftForMeeting`

**Purpose:** Saves a manual attendance override for one student during an active QR session. This is called automatically (without a save button) when the instructor taps on a student in the "Not Scanned" screen to mark them present. Also used when the instructor manually marks someone absent.

**Input:**
```json
{
  "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "student_id": "S003",
  "status":     "present"
}
```

`status` must be either `"present"` or `"absent"` (case-insensitive, normalized to lowercase).

**How it works:**
Writes a single record to `DRAFT#{meeting_id}` for the given student. Uses `put_item` so calling again with a different status simply overwrites the previous override.

**Output (200):**
```json
{
  "message":    "Draft override saved",
  "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "student_id": "S003",
  "status":     "present"
}
```

**Notes:**
- This function is called with NO explicit save button — the marking is automatic when the instructor taps a student checkbox in the unscanned list.
- Overwrites any previous draft override for the same student in the same meeting.

---

### 5.9 `GetDraftForMeeting`

**API Endpoint:** `POST /getDraftForMeeting`

**Purpose:** Returns all draft overrides that exist for a specific meeting. Primarily a utility/debug function, but also used by the instructor app to restore manual overrides if the screen is re-entered.

**Input:**
```json
{ "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4" }
```

**How it works:**
Queries `DRAFT#{meeting_id}` and returns all records.

**Output (200):**
```json
{
  "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "count": 1,
  "overrides": [
    {
      "student_id": "S003",
      "status":     "present",
      "updated_at": "2026-03-02T08:20:00+00:00"
    }
  ]
}
```

---

### 5.10 `SaveFinalAttendance`

**API Endpoint:** `POST /saveFinalAttendance`

**Purpose:** Locks attendance permanently for a course section on a specific date. This is the final step — once saved, the FINAL record takes priority over everything else and this is what counts as the official attendance record.

**Input:**
```json
{
  "course_id":           "CSE101",
  "section_id":          "SEC1",
  "date":                "2026-03-02",
  "present_student_ids": ["S001", "S003"]
}
```

`present_student_ids` is the list of students who are **present**. Everyone else in the roster is marked **absent**.

**How it works:**
1. Scans the full roster from `students` table for `CSE101#SEC1`.
2. Builds a set from `present_student_ids`.
3. Writes a `_META_` marker record to `FINAL#{course_id}#{section_id}#{date}`.
4. Uses `batch_writer` to write one record per student in the roster:
   - `status = "present"` if in `present_student_ids`
   - `status = "absent"` otherwise.
5. Because `put_item` is used, calling this again on the same date completely overwrites all previous FINAL records (idempotent re-save).

**Output (200):**
```json
{
  "message":       "Final attendance saved",
  "pk":            "FINAL#CSE101#SEC1#2026-03-02",
  "roster_count":  3,
  "present_count": 2,
  "absent_count":  1
}
```

**Output (400) — Missing fields:**
```json
{ "message": "course_id, section_id, date are required" }
```

**Important notes:**
- The `date` field must be passed by the app (format: `YYYY-MM-DD`). The Lambda does NOT auto-detect today's date.
- The roster is the source of truth. Even if a student is in `present_student_ids` but not actually enrolled in the section, they won't be written (since the roster scan is the base).
- After saving, `GetLatestMeetingForSectionToday` will return this FINAL data.

---

### 5.11 `GetFlagsForSession`

**API Endpoint:** `POST /getFlagsForSession`

**Purpose:** Returns all security flags raised during a QR session. This lets the instructor see if anyone tried to scan from a different device or if a non-enrolled student tried to scan.

**Input:**
```json
{ "session_id": "550e8400-e29b-41d4-a716-446655440000" }
```

**How it works:**
1. Fetches the session from `qr_sessions` to get the `meeting_id`.
2. Queries `FLAG#{meeting_id}` from the `attendance` table.
3. Returns all flag records.

**Output (200):**
```json
{
  "meeting_id": "CSE101#SEC1#2026-03-02#a1b2c3d4",
  "course_id":  "CSE101",
  "section_id": "SEC1",
  "expires_at": 1771858660,
  "flags_count": 1,
  "flags": [
    {
      "student_id":       "S999",
      "flag_reason":      "APP_ID_MISMATCH",
      "message":          "Student tried to take attendance from a different device/app_id",
      "expected_app_id":  "original-uuid",
      "received_app_id":  "different-uuid",
      "timestamp":        "2026-03-02T08:16:00+00:00",
      "session_id":       "550e8400-..."
    }
  ]
}
```

---

### 5.12 `GetStudentAttendanceHistory`

**API Endpoint:** `POST /studentAttendanceHistory`

**Purpose:** Used by the student app to display a student's full attendance history. Shows all days with their status (present or absent), grouped by course and section. This function considers FINAL, DRAFT, and SCAN records — always picking the highest-priority record per day.

**Input:**
```json
{
  "student_id": "S001",
  "limit": 100
}
```

`limit` is optional and defaults to 100. Controls how many day-records are returned at most.

**How it works:**
1. Scans the entire `attendance` table filtering by `student_id`.
2. For each raw record, normalizes it by parsing the `course_date` prefix:
   - `FINAL#` → extracts `course_id`, `section_id`, `date` from the PK. Status is `present` or `absent`. Skips `_META_` rows (no status field).
   - `DRAFT#` → extracts `course_id`, `section_id`, `date` from the embedded `meeting_id`. Status is `present` or `absent`.
   - `SCAN#` → extracts `course_id`, `section_id`, `date` from the embedded `meeting_id`. Status is always `present`.
   - `FLAG#` → ignored entirely.
3. For each unique `(course_id, section_id, date)` combination, keeps the **best** record using this priority:
   - FINAL (priority 300) beats DRAFT (priority 200) beats SCAN (priority 100).
   - If two records have the same priority, the one with the newer timestamp wins.
4. Sorts all resulting day-records newest first by date then timestamp.
5. Applies the `limit`.
6. Groups by `course_id + section_id` for the output.

**Priority resolution example:** If a student has both a SCAN record and a FINAL record for the same day, the FINAL record always wins — so if the instructor marked them absent in the final save, that overrides the QR scan.

**Output (200):**
```json
{
  "student_id":     "S001",
  "days_count":     3,
  "present_days":   2,
  "absent_days":    1,
  "sections_count": 1,
  "sections": [
    {
      "course_id":  "CSE101",
      "section_id": "SEC1",
      "days": [
        { "date": "2026-03-02", "status": "present", "source": "final" },
        { "date": "2026-03-01", "status": "absent",  "source": "final" },
        { "date": "2026-02-28", "status": "present", "source": "scan"  }
      ]
    }
  ],
  "flat_days": [
    {
      "course_id": "CSE101", "section_id": "SEC1",
      "date": "2026-03-02", "status": "present",
      "source": "final", "time_key": "2026-03-02T10:30:00+00:00"
    }
  ]
}
```

**`source` field values:**
| Value | Meaning |
|-------|---------|
| `final` | Official locked attendance saved by instructor or auto-finalized |
| `draft_override` | Instructor manually marked during QR session (not yet finalized) |
| `scan` | Student scanned QR code (not yet finalized) |

**Notes:**
- `flat_days` is included in the response for debugging purposes — it is the raw flat list before grouping.
- The student sees both present and absent days (unlike the old version which only showed present days).
- Records are sorted newest first within each section's `days` list.

---

### 5.13 `MarkAttendance` *(Legacy / Not Used in Current App)*

**API Endpoint:** `POST /markAttendance`

**Purpose:** An early prototype function for directly marking one student as present for a course on the current date. Does **not** use the FINAL/DRAFT/SCAN prefix system.

**Input:**
```json
{
  "student_id": "S001",
  "course_id":  "CSE101"
}
```

**Output (200):**
```json
{ "message": "Attendance recorded for S001 in CSE101 on 2026-03-02" }
```

**Note:** This function uses an older `course_date` format (`{course_id}#{date}`) and is **not integrated** with the rest of the system. It exists for early testing only.

---

### 5.14 `AutoFinalizeDailyAttendance` *(EventBridge Triggered — Not an API Endpoint)*

**Purpose:** Runs automatically at 23:59 Cairo time every day via EventBridge Scheduler. For every course section scheduled to meet today, if no instructor has saved a FINAL record, this function auto-creates one marking all students as **present**.

**How it works:**
1. Determines today's date and day-of-week in Cairo time.
2. Scans the entire `courses` table.
3. For each course → for each section → checks if `meeting_days` contains today's DOW.
4. For sections meeting today: checks if `FINAL#{course_id}#{section_id}#{date}` already has any records.
5. If FINAL already exists → skip (instructor already handled this section).
6. If no FINAL → load the student roster for that section.
7. If roster is empty → skip (no students enrolled).
8. Writes FINAL records for all students with `status = "present"` and `auto_finalized = true`.

**Output (logged to CloudWatch):**
```json
{
  "date":                      "2026-03-02",
  "dow":                       "MON",
  "processed_sections_today":  3,
  "auto_finalized_sections":   1,
  "skipped_already_final":     2,
  "skipped_no_roster":         0,
  "details": [
    {
      "course_id":  "CSE101",
      "section_id": "SEC2",
      "pk":         "FINAL#CSE101#SEC2#2026-03-02",
      "action":     "auto_finalized_all_present",
      "roster_count": 3
    }
  ]
}
```

**Action types in `details`:**
| Action | Meaning |
|--------|---------|
| `auto_finalized_all_present` | Section was finalized with all students present |
| `skip_final_exists` | Instructor already saved attendance, skipped |
| `skip_no_roster` | No students enrolled in section, skipped |

---

## 6. API Gateway Endpoints

**API Name:** SmartAttendanceAPI
**Type:** HTTP API (AWS API Gateway v2)
**All routes:** `POST` method

| Route | Lambda Function | Used By |
|-------|----------------|---------|
| `POST /generateQr` | GenerateQrSessionFunction | Instructor App |
| `POST /getAbsentForMeeting` | GetAbsentForMeetingFunction | Instructor App |
| `POST /getDoctorCoursesSections` | GetDoctorCoursesSections | Instructor App |
| `POST /getDraftForMeeting` | GetDraftForMeetingFunction | Debug / Instructor App |
| `POST /getFlagsForSession` | GetFlagsForSessionFunction | Instructor App |
| `POST /getLatestMeetingForSectionToday` | GetLatestMeetingForSectionTodayFunction | Instructor App |
| `POST /getScansForMeeting` | GetScansForMeetingFunction | Debug |
| `POST /getStudentsForSection` | GetStudentsForSectionFunction | Instructor App |
| `POST /markAttendance` | MarkAttendanceFunction | Legacy / Not used |
| `POST /markDraftForMeeting` | MarkDraftForMeetingFunction | Instructor App |
| `POST /saveFinalAttendance` | SaveFinalAttendanceFunction | Instructor App |
| `POST /scanQr` | ScanQrFunction | Student App |
| `POST /studentAttendanceHistory` | GetStudentAttendanceHistoryFunction | Student App |

---

## 7. EventBridge Scheduler — Auto-Finalize

**Schedule name:** `smart-attendance-auto-finalize`
**Cron expression:** `59 23 * * ? *`
**Execution timezone:** Africa/Cairo
**Trigger time:** Every day at 23:59:00 Cairo time
**Target:** `AutoFinalizeDailyAttendance` Lambda function
**Current status:** Disabled (to be enabled for production)

**Purpose:** At the end of each day, if an instructor forgot to (or chose not to) save attendance for a section that was scheduled to meet today, the system automatically records everyone as present. This ensures no student ever has a missing record.

---

## 8. Attendance State Machine & Priority Logic

Understanding the priority hierarchy is critical to understanding how the system works.

**Important:** DRAFT records (marks from the "Not Scanned" screen) can ONLY exist if a QR session was generated first, because the "Not Scanned" screen only appears after a QR session ends. It is impossible to have DRAFT records without a QR session.

```
When instructor opens a section:

Does FINAL#{course}#{section}#{today} exist?
├── YES → Load and display FINAL records (LOCKED STATE)
│         mode = "FINAL"
│         has_final = true
│
└── NO → Did the instructor generate a QR session today?
          │
          ├── YES → Load SCAN records + DRAFT records together
          │         (both can only exist if QR was generated)
          │         Scanned students               → PRESENT
          │         Marked from "Not Scanned" list → PRESENT
          │         Everyone else                  → ABSENT
          │         mode = "DRAFT"
          │         has_final = false
          │
          └── NO → No QR was ever generated today
                   Default: everyone = PRESENT
                   (instructor has not opened or touched this section)
                   mode = "DEFAULT"
                   has_final = false
```

**Priority (highest to lowest):**
1. **FINAL** — saved by instructor clicking "Save Final Attendance", or auto-finalized by EventBridge. Permanent and locked.
2. **SCAN + DRAFT combined** — only exists if a QR was generated. Scanned students and manually marked students from the "Not Scanned" screen are both equally present. Everyone else is absent.
3. **Default** — no QR was ever generated today. Everyone is present.

---

## 9. Instructor App — Screens & Flow

### Screen 1: Doctor ID Entry Page
- Doctor types their `doctor_id` manually (e.g., `D001`).
- App calls `POST /getDoctorCoursesSections` with `{ "doctor_id": "D001" }`.
- Navigates to Courses & Sections screen.
- **Future:** This screen will be replaced by a real login page where the `doctor_id` is extracted automatically from the authenticated account.

### Screen 2: Courses & Sections Page
- Lists all courses and sections that the doctor teaches **today only**.
- If no sections are scheduled today, an empty state is shown.
- Doctor taps a section → navigates to Section Dashboard.

### Screen 3: Section Dashboard / Attendance List
- App calls `POST /getLatestMeetingForSectionToday` to load current state.
- Displays the full student roster with a checkbox next to each student.
- **Default behavior:** All students are checked (present).
- If FINAL data was found → display that data; instructor can still see it.
- Doctor can manually check/uncheck any student.
- Buttons available:
  - **Generate QR** → opens QR screen.
  - **Save Final Attendance** → calls `/saveFinalAttendance` with the current checkbox state.

### Screen 4: QR Code Screen
- App calls `POST /generateQr` → receives `session_id` and `expires_at`.
- Displays the QR code (encoded `session_id`) full-screen, meant for the projector.
- Shows a countdown timer (60 seconds).
- Instructor can click **Close Early / Finish** before 60 seconds expire.
- When timer expires OR instructor closes early → navigates to "Not Scanned" screen.

### Screen 5: Not Scanned / Unscanned Screen
- App calls `POST /getAbsentForMeeting` to get the list of absent students.
- Shows only students who have NOT scanned AND are not already manually marked present.
- Each student has an empty checkbox.
- When the instructor taps a checkbox to mark a student present:
  - App immediately calls `POST /markDraftForMeeting` with `status: "present"`.
  - **No save button needed** — the mark is saved automatically.
  - The student disappears from this list.
- When the instructor is done → arrow back to the full attendance list (Screen 3).
  - The full list now reflects: scanned students (present) + manually marked students (present) + unmarked students (absent).

### Screen 6: Final Attendance List (Back from Screen 5)
- The full roster with updated statuses.
- Instructor can still manually adjust any student (check/uncheck).
- Must click **Save Final Attendance** to lock the record.
- Calls `POST /saveFinalAttendance` with `{ "course_id", "section_id", "date", "present_student_ids": [...] }`.

---

## 10. Student App — Screens & Flow

### App ID (device binding)
- When the Flutter app is installed, it generates a unique `app_id` (UUID).
- This `app_id` persists as long as the app is installed.
- If the student uninstalls and reinstalls, a new `app_id` is generated, and the binding in the `students` table must be reset manually (future: support request flow).

### Screen 1: Student ID Entry Page
- Student types their `student_id` manually (e.g., `S001`).
- **Future:** This will be a real login page with automatic `student_id` retrieval.

### Screen 2: QR Scan Page
- Student scans the QR code displayed on the projector.
- App extracts `session_id` from the QR code.
- App calls `POST /scanQr` with `{ "session_id", "student_id", "app_id" }`.
- If successful → shows confirmation message.
- If failed → shows error (expired, not enrolled, device mismatch, etc.).

### Screen 3: Attendance History Page
- App calls `POST /studentAttendanceHistory` with `{ "student_id": "S001", "limit": 100 }`.
- Displays a list of courses/sections with each day's status (present or absent), sorted newest first.
- Shows FINAL, DRAFT, and SCAN records — always displaying the highest-priority record per day (FINAL wins over DRAFT wins over SCAN).

---

## 11. Security & Device Binding (app_id)

### How device binding works:
1. Student installs the app → Flutter generates a unique `app_id`.
2. First time the student scans any QR code:
   - `ScanQr` Lambda finds no `app_id` in the student's record.
   - Writes `app_id` to the student record using a conditional write (`attribute_not_exists(app_id)`).
   - The conditional write ensures that even if two concurrent requests arrive simultaneously, only one can bind the `app_id`.
3. All subsequent scans: the incoming `app_id` is compared to the stored one.
4. Mismatch → scan rejected + FLAG record written.

### Flag reasons:
| Flag Reason | Trigger |
|-------------|---------|
| `APP_ID_MISMATCH` | Student scanned from a different phone/app installation |
| `NOT_ENROLLED_COURSE` | Student is not enrolled in the course at all |
| `NOT_ENROLLED_SECTION` | Student is enrolled in the course but not this specific section |

### Future security (planned):
- Replace `doctor_id` in request body with JWT token (Cognito).
- API Gateway authorizers to restrict student vs instructor endpoints.
- QR session validation improvements.
- Proper authentication and authorization flow.

---

## 12. Flag System

Flags are written to the `attendance` table under the `FLAG#{meeting_id}` partition key. They are **non-blocking logging records** — the scan is still rejected, but the instructor can review what happened.

The instructor app can call `POST /getFlagsForSession` with a `session_id` to see all suspicious activity during a QR session, including:
- Which students tried to scan from a different device.
- Which non-enrolled students tried to scan.

---

## 13. Complete Attendance Scenarios

### Scenario A: Manual Attendance Only
1. Doctor opens section → `getLatestMeetingForSectionToday` returns DEFAULT (all present).
2. Doctor unchecks absent students manually.
3. Doctor clicks Save → `saveFinalAttendance` called with checked students.
4. Done. FINAL record locked.

### Scenario B: QR Only
1. Doctor opens section → DEFAULT (all present).
2. Doctor clicks Generate QR → QR shown on projector for 60 seconds.
3. Students scan → each scan hits `/scanQr` → SCAN records created.
4. Timer expires → Not Scanned screen shows absent students.
5. Doctor clicks Save on the full list → `saveFinalAttendance` called.
6. FINAL: scanned = present, unscanned = absent.

### Scenario C: QR + Manual for non-phone students
1. Doctor generates QR.
2. Most students scan. Student S3 has no phone.
3. Not Scanned screen: S3 appears.
4. Doctor taps S3's checkbox → `markDraftForMeeting` called automatically (S3 now has `DRAFT#... status: present`).
5. S3 disappears from Not Scanned list.
6. Doctor goes back to full list → S3 shows present (from DRAFT), scanned students show present (from SCAN).
7. Doctor clicks Save → FINAL includes S3 as present.

### Scenario D: Re-entering a section
1. Doctor saved attendance → FINAL exists.
2. Doctor re-opens same section → `getLatestMeetingForSectionToday` returns FINAL data.
3. Doctor sees the locked attendance list.
4. Doctor can still adjust and click Save again → overwrites FINAL.

### Scenario E: Auto-finalize (end of day)
1. Doctor didn't open the section at all.
2. EventBridge fires at 23:59 Cairo time.
3. `AutoFinalizeDailyAttendance` checks CSE101#SEC2 meets today → no FINAL exists.
4. Writes FINAL for all roster students with `status: present`, `auto_finalized: true`.
5. Next day, if doctor checks — record shows all present with auto-finalized flag.

### Scenario F: Multiple QR sessions (instructor regenerates)
1. Doctor generates QR #1 → S1 and S2 scan → `SCAN#meeting_id_1` records written.
2. Doctor closes early and generates QR #2.
3. `generateQr` scans `qr_sessions` → finds today's existing `meeting_id_1` → **reuses it**. QR #2 gets a new `session_id` but the same `meeting_id_1`.
4. Nobody scans QR #2.
5. Not Scanned screen calls `getAbsentForMeeting` → finds all meetings today → merges SCAN records from `meeting_id_1` → S1 and S2 are present → **do not appear in absent list**. ✅
6. Doctor closes and reopens section → `getLatestMeetingForSectionToday` finds all meetings today → merges all SCAN records → S1 and S2 still show present. ✅
7. Any draft marks made during QR #1's unscanned screen are still under `DRAFT#meeting_id_1` and are still found and applied. ✅

---

## 14. Lambda Functions NOT Used in the App (Debug Only)

| Function | Endpoint | Notes |
|----------|----------|-------|
| `MarkAttendanceFunction` | `POST /markAttendance` | Legacy prototype function with old PK format. Not integrated with FINAL/DRAFT/SCAN system. |
| `GetScansForMeetingFunction` | `POST /getScansForMeeting` | Useful for debugging to see raw scan records. Not called in normal app flow. |
| `GetDraftForMeetingFunction` | `POST /getDraftForMeeting` | Useful for debugging to see raw draft overrides. Not called in normal app flow. |

---

## 15. Timezone & Date Handling

- All date and day-of-week calculations use **Africa/Cairo** timezone (UTC+2, no DST).
- The `ZoneInfo("Africa/Cairo")` is used in all Lambda functions that need the current date/time.
- `created_at` and `expires_at` in `qr_sessions` are **Unix epoch seconds** (integer).
- All other timestamps (`updated_at`, `saved_at`, `timestamp`, `app_id_bound_at`) are **ISO 8601 strings** in UTC.
- Date strings in attendance keys and `date` fields use format: `YYYY-MM-DD` (e.g., `2026-03-02`).
- Day-of-week abbreviations are always 3 uppercase letters: `SUN`, `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`.

---

## 16. Future Improvements

### Security (Priority)
- Replace manual `doctor_id` entry with Cognito authentication + JWT tokens
- Extract `doctor_id` from JWT claims automatically (no user input needed)
- API Gateway authorizers to separate instructor and student endpoint access
- Secure `app_id` reset flow for students who change phones

### Features
- Student app login page (Cognito-based)
- Web admin panel for managing courses, sections, student enrollment
- Attendance analytics and statistics dashboard
- Export to CSV / Excel
- Late arrival logic (mark as "late" if scan happens after N minutes)
- GPS validation (only allow scans within campus area)
- Bluetooth proximity validation
- Multi-session per day support (morning + afternoon classes)

### Infrastructure
- Enable DynamoDB TTL on `qr_sessions` for automatic cleanup
- CloudWatch structured logging
- EventBridge cleanup jobs for old SCAN/DRAFT records
- GSI (Global Secondary Index) on `attendance` for efficient student-based queries (replace full scan in `GetStudentAttendanceHistory`)
- GSI on `students` table for section-based queries (replace full scan in roster lookups)
