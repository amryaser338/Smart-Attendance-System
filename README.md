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
16. [Known Gotchas & Important Notes](#16-known-gotchas--important-notes)
17. [Course Import Tool (Excel to DynamoDB)](#17-course-import-tool-excel-to-dynamodb)
18. [Future Improvements](#18-future-improvements)

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

**Current state:** Both apps have a login page. Authentication is handled on the Flutter side by validating the university email domain (`@miuegypt.edu.eg`) and extracting the user identifier from the email. No backend authentication service is used — the extracted identifier is sent directly as the key in API calls. Full cloud-based authentication (Cognito/JWT) is planned for the future.

---

## 2. System Architecture

```
+---------------------------------+       +------------------------------+
|     Instructor Flutter App      |       |    Student Flutter App       |
|       (Desktop / Laptop)        |       |         (Mobile)             |
+----------------+----------------+       +--------------+---------------+
                 |  HTTPS POST                           |  HTTPS POST
                 v                                       v
+---------------------------------------------------------------------+
|                    AWS API Gateway (HTTP API)                        |
|                  Name: SmartAttendanceAPI                           |
+------------------------------+--------------------------------------+
                               | Invoke
                               v
+---------------------------------------------------------------------+
|                    AWS Lambda Functions (Python 3.x)                 |
+------+------------------+----------------+---------------+-----------+
       |                  |                |               |
       v                  v                v               v
+----------+  +-------------+  +-----------+  +----------------+
|attendance|  |   courses   |  |qr_sessions|  |    students    |
|(DynamoDB)|  |(DynamoDB)   |  |(DynamoDB) |  |  (DynamoDB)    |
+----------+  +-------------+  +-----------+  +----------------+

                               ^
                               | Scheduled trigger (daily)
+------------------------------+--------------------------------------+
|               Amazon EventBridge Scheduler                           |
|        Name: smart-attendance-auto-finalize                          |
|        Cron: 59 23 * * ? *  (23:59 Cairo time every day)           |
+---------------------------------------------------------------------+
```

**AWS Region:** il-central-1 (Israel / Tel Aviv)

---

## 3. AWS Infrastructure

| Service | Resource Name | Purpose |
|---------|--------------|---------|
| DynamoDB | `attendance` | All attendance records (SCAN, DRAFT, FINAL, FLAG) |
| DynamoDB | `courses` | Course catalog with sections and meeting days |
| DynamoDB | `students` | Student enrollment, device binding |
| DynamoDB | `qr_sessions` | QR session records (60-second validity windows) |
| Lambda | (13 functions) | All business logic — see Section 5 |
| API Gateway | SmartAttendanceAPI | Single HTTP API exposing all Lambda endpoints |
| EventBridge Scheduler | smart-attendance-auto-finalize | Nightly auto-finalization job |

### Critical DynamoDB Configuration

**`qr_sessions` table — TTL must be OFF:**
- TTL on `qr_sessions` was originally enabled on the `expires_at` field.
- This caused sessions to be deleted after 60 seconds, making `GetLatestMeetingForSectionToday` and `GetAbsentForMeeting` unable to find the day's meeting_ids and incorrectly returning wrong results after every QR session expired.
- The QR expiry is enforced entirely in code (`ScanQr` checks `now > expires_at`). TTL is not needed and must remain **disabled**.
- Current status: **TTL is OFF**

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
FINAL#CSE101#SEC1#2026-03-07
SCAN#CSE101#SEC1#2026-03-07#a1b2c3d4
DRAFT#CSE101#SEC1#2026-03-07#a1b2c3d4
FLAG#CSE101#SEC1#2026-03-07#a1b2c3d4
```

**FINAL record:**
```json
{
  "course_date": "FINAL#CSE101#SEC1#2026-03-07",
  "student_id":  "06377",
  "status":      "present",
  "record_type": "final",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "date":        "2026-03-07",
  "saved_at":    "2026-03-07T10:30:00+00:00"
}
```

**FINAL _META_ record** (one per FINAL partition, used as a marker):
```json
{
  "course_date": "FINAL#CSE101#SEC1#2026-03-07",
  "student_id":  "_META_",
  "record_type": "final_meta",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "date":        "2026-03-07",
  "saved_at":    "2026-03-07T10:30:00+00:00"
}
```

**FINAL record (auto-finalized by EventBridge):**
```json
{
  "course_date":    "FINAL#CSE101#SEC1#2026-03-07",
  "student_id":     "S001",
  "status":         "present",
  "record_type":    "final",
  "auto_finalized": true,
  "updated_at":     "2026-03-07T21:59:00+00:00"
}
```

**SCAN record:**
```json
{
  "course_date": "SCAN#CSE101#SEC1#2026-03-07#a1b2c3d4",
  "student_id":  "06377",
  "course_id":   "CSE101",
  "section_id":  "SEC1",
  "meeting_id":  "CSE101#SEC1#2026-03-07#a1b2c3d4",
  "session_id":  "uuid-of-qr-session",
  "timestamp":   "2026-03-07T08:15:00+00:00",
  "record_type": "scan",
  "status":      "scanned"
}
```

**DRAFT record:**
```json
{
  "course_date": "DRAFT#CSE101#SEC1#2026-03-07#a1b2c3d4",
  "student_id":  "S003",
  "status":      "present",
  "record_type": "draft_override",
  "updated_at":  "2026-03-07T08:20:00+00:00"
}
```

**FLAG record:**
```json
{
  "course_date":     "FLAG#CSE101#SEC1#2026-03-07#a1b2c3d4",
  "student_id":      "S999",
  "course_id":       "CSE101",
  "section_id":      "SEC1",
  "meeting_id":      "CSE101#SEC1#2026-03-07#a1b2c3d4",
  "session_id":      "uuid-of-qr-session",
  "timestamp":       "2026-03-07T08:16:00+00:00",
  "record_type":     "flag",
  "status":          "flagged",
  "flag_reason":     "APP_ID_MISMATCH",
  "message":         "Student tried to take attendance from a different device/app_id",
  "expected_app_id": "original-uuid",
  "received_app_id": "different-uuid"
}
```

---

### 4.2 `courses` Table

**Keys:** Partition Key: `course_id` (String), no sort key, on-demand.

```json
{
  "course_id":   "CSE101",
  "course_name": "electronics",
  "sections": [
    {
      "section_id":   "SEC1",
      "doctor_ids":   ["lamia"],
      "meeting_days": ["SUN", "MON", "TUE", "WED", "THU"]
    },
    {
      "section_id":   "SEC2",
      "doctor_ids":   ["lamia", "ahmed"],
      "meeting_days": ["TUE", "WED"]
    }
  ]
}
```

- `meeting_days`: 3-letter uppercase: `SUN`, `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`
- A section can have multiple `doctor_ids`

---

### 4.3 `students` Table

**Keys:** Partition Key: `student_id` (String), no sort key, on-demand.

```json
{
  "student_id":      "06377",
  "name":            "Amr Yasser",
  "email":           "amr@miuegypt.edu.eg",
  "major_id":        "ENG01",
  "course_ids":      ["CSE101"],
  "section_ids":     ["CSE101#SEC1"],
  "app_id":          "unique-flutter-app-uuid",
  "app_id_bound_at": "2026-01-20T15:09:00+00:00"
}
```

- `section_ids`: Compound `"{course_id}#{section_id}"` strings.
- `app_id`: Set on first QR scan via conditional write. Must be absent or a valid UUID — never an empty string (see Section 16).

---

### 4.4 `qr_sessions` Table

**Keys:** Partition Key: `session_id` (String), no sort key, on-demand. **TTL: DISABLED.**

```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "meeting_id": "CSE101#SEC1#2026-03-07#a1b2c3d4",
  "course_id":  "CSE101",
  "section_id": "SEC1",
  "created_at": 1771858600,
  "expires_at": 1771858660
}
```

- `created_at` and `expires_at` are Unix epoch seconds (not milliseconds).
- `expires_at = created_at + 60`
- `meeting_id` format: `{course_id}#{section_id}#{date}#{8-char-hex}`
- Multiple sessions per day share the same `meeting_id` (if instructor regenerates QR).

---

## 5. Lambda Functions — Complete Reference

All Lambda functions are Python 3.x, use `boto3`, include CORS headers, and use `Africa/Cairo` timezone.

---

### 5.1 `GetDoctorCoursesSections`

**Endpoint:** `POST /getDoctorCoursesSections`

**Purpose:** Returns courses and sections the doctor teaches today.

**Input:** `{ "doctor_id": "D001" }`

**How it works:** Scans `courses` table, filters sections where `doctor_id` in `doctor_ids` AND today's DOW in `meeting_days`.

**Output (200):**
```json
{
  "doctor_id": "D001",
  "today":     "MON",
  "count":     1,
  "courses": [
    { "course_id": "CSE101", "course_name": "electronics", "sections": ["SEC1"] }
  ]
}
```

Note: `doctor_id` can also be passed as URL query param `?doctor_id=D001`.

---

### 5.2 `GetStudentsForSection`

**Endpoint:** `POST /getStudentsForSection`

**Purpose:** Returns the full student roster for a section.

**Input:** `{ "course_id": "CSE101", "section_id": "SEC1" }`

**How it works:** Scans `students` table filtering where `section_ids` contains `"CSE101#SEC1"`. Returns `student_id` + `name`, sorted by `student_id`.

**Output (200):**
```json
{
  "students": [
    { "student_id": "S001", "name": "Amr Yasser" },
    { "student_id": "S003", "name": "Zoz ASAKR" }
  ],
  "count": 2
}
```

---

### 5.3 `GetLatestMeetingForSectionToday`

**Endpoint:** `POST /getLatestMeetingForSectionToday`

**Purpose:** The core "load" function. Called every time the instructor opens a section. Returns current attendance state with strict priority ordering.

**Input:** `{ "course_id": "CSE101", "section_id": "SEC1" }`

**Priority logic:**

**Priority 1 — FINAL exists:** Load and return FINAL records. Done.

**Priority 2 — QR sessions today with activity:** `find_all_meetings_today` discovers ALL meeting_ids for today using two sources:
- **Source 1:** Scans `qr_sessions` for sessions matching `course_id`, `section_id`, and `meeting_id` containing today's date.
- **Source 2 (fallback):** Scans `attendance` table directly for any `SCAN#` or `DRAFT#` records with today's date for this course+section. Catches orphaned meeting_ids not in `qr_sessions` (e.g. from before TTL was disabled).

SCAN and DRAFT records accumulated across all meetings. Status per student: absent by default, present if scanned, DRAFT overrides SCAN (newest meeting's draft wins).

**Priority 3 — Default:** No QR or no activity → all students present.

**Output (200) — FINAL mode:**
```json
{
  "found": true, "mode": "FINAL", "has_final": true,
  "meeting_id": null, "session_id": null,
  "present_count": 2, "absent_count": 1,
  "students": [
    { "no": 1, "student_id": "S001", "status": "present", "source": "final" }
  ]
}
```

**Output (200) — DRAFT mode:**
```json
{
  "found": true, "mode": "DRAFT", "has_final": false,
  "meeting_id": "CSE101#SEC1#2026-03-07#a1b2c3d4",
  "session_id": "550e8400-...",
  "present_count": 2, "absent_count": 0,
  "scan_count": 2, "draft_override_count": 0,
  "students": [
    { "no": 1, "student_id": "S001", "name": "Amr Yasser", "status": "present", "source": "scan+draft" },
    { "no": 2, "student_id": "S003", "name": "Zoz ASAKR",  "status": "present", "source": "scan+draft" }
  ]
}
```

**Output (200) — DEFAULT mode:**
```json
{
  "found": true, "mode": "DEFAULT", "has_final": false,
  "meeting_id": null, "session_id": null,
  "present_count": 2, "absent_count": 0,
  "students": [
    { "no": 1, "student_id": "S001", "name": "Amr Yasser", "status": "present", "source": "default_no_meeting" }
  ]
}
```

**Notes:**
- `_META_` records in FINAL partitions are always filtered out.
- `meeting_id` and `session_id` in DRAFT mode are the latest session's values — all meetings today are already merged.
- The Flutter app must call this endpoint again when returning from the Not Scanned screen to the full list, to get the correct merged state across all QR sessions today.

---

### 5.4 `GenerateQr`

**Endpoint:** `POST /generateQr`

**Purpose:** Creates a new QR session valid for 60 seconds.

**Input:** `{ "course_id": "CSE101", "section_id": "SEC1" }`

**How it works:**
1. Checks today's DOW is in `meeting_days`. If not → 403.
2. `get_or_create_meeting_id`: scans `qr_sessions` for today → reuses earliest `meeting_id` if found, creates new one if not.
3. Generates new `session_id` (UUID v4) for expiry tracking.
4. Sets `expires_at = now + 60`.
5. Writes to `qr_sessions` and returns.

**Output (200):**
```json
{
  "session_id":       "550e8400-...",
  "meeting_id":       "CSE101#SEC1#2026-03-07#a1b2c3d4",
  "course_id":        "CSE101",
  "section_id":       "SEC1",
  "created_at":       1771858600,
  "expires_at":       1771858660,
  "duration_seconds": 60
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

**Important notes:**
- All QR sessions on the same day share one `meeting_id` so all scans accumulate under `SCAN#same_meeting_id`.
- QR expiry is enforced in `ScanQr` code, not by DynamoDB TTL (TTL is disabled).
- Flutter app should use `duration_seconds` for the countdown timer — not `expires_at - phone_time` — to avoid phone/server clock mismatch.

---

### 5.5 `ScanQr`

**Endpoint:** `POST /scanQr`

**Purpose:** Validates a QR scan, checks enrollment, binds device, records attendance.

**Input:** `{ "session_id": "...", "student_id": "S001", "app_id": "uuid" }`

**Steps:**
1. Load QR session from `qr_sessions`. Not found → 400.
2. Check `now > expires_at`. Expired → 400.
3. Load student with `ConsistentRead=True`. Not found → 400.
4. Check enrollment (`course_ids`, `section_ids`). Not enrolled → FLAG + 403.
5. Check `app_id`: No `app_id` stored → bind via `attribute_not_exists` conditional write. Conditional write fails (race) → re-read with `ConsistentRead=True`. Mismatch → Step 6.
6. `app_id` mismatch → FLAG + 403.
7. Write `SCAN#{meeting_id}` record with conditional write (no duplicates).

**Outputs:**
```json
{ "message": "Scan recorded", "meeting_id": "...", "course_id": "...", "section_id": "..." }
{ "message": "Already scanned", "meeting_id": "..." }
{ "message": "QR code expired" }
{ "message": "Device mismatch. Scan rejected.", "flag_reason": "APP_ID_MISMATCH" }
{ "message": "Not enrolled in this section", "flag_reason": "NOT_ENROLLED_SECTION" }
```

**Important notes:**
- Both student reads use `ConsistentRead=True` to prevent stale-read 500 errors.
- `app_id` must be absent or a valid UUID — never empty string `""`.

---

### 5.6 `GetScansForMeeting`

**Endpoint:** `POST /getScansForMeeting` — **Debug only**

Returns all students who scanned for a specific `meeting_id`. Queries `SCAN#{meeting_id}`.

---

### 5.7 `GetAbsentForMeeting`

**Endpoint:** `POST /getAbsentForMeeting`

**Purpose:** Returns absent students for a meeting. Powers the "Not Scanned" screen.

**Input:** `{ "course_id": "CSE101", "section_id": "SEC1", "meeting_id": "..." }`

**How it works:**
1. Scans roster from `students`.
2. Extracts date from `meeting_id`, then calls `find_all_meetings_today` which uses **two sources** to discover all meeting_ids for today:
   - **Source 1:** Scans `qr_sessions` for matching sessions.
   - **Source 2 (fallback):** Scans `attendance` table directly for any `SCAN#` or `DRAFT#` records with today's date for this course+section. Catches orphaned meeting_ids not in `qr_sessions`.
3. Merges SCAN records across all meetings today → unified present set.
4. Merges DRAFT records across all meetings today (newest meeting's draft wins).
5. Returns only students whose final status is absent.

**Output (200):**
```json
{
  "course_id":       "CSE101",
  "section_id":      "SEC1",
  "meeting_id":      "CSE101#SEC1#2026-03-07#a1b2c3d4",
  "meetings_today":  ["CSE101#SEC1#2026-03-07#a1b2c3d4"],
  "absent_count":    0,
  "absent_students": []
}
```

`meetings_today` lists all meeting_ids found today across both sources. Useful for debugging.

---

### 5.8 `MarkDraftForMeeting`

**Endpoint:** `POST /markDraftForMeeting`

**Purpose:** Saves a manual attendance override for one student. Called automatically (no save button) when instructor taps a student in the Not Scanned screen.

**Input:** `{ "meeting_id": "...", "student_id": "S003", "status": "present" }`

**How it works:**
1. Validates `meeting_id` exists in `qr_sessions`. If not → 400. Prevents orphaned drafts.
2. Writes `DRAFT#{meeting_id}` record using `put_item` (overwrites previous draft for this student).

**Output (200):**
```json
{ "message": "Draft override saved", "meeting_id": "...", "student_id": "S003", "status": "present" }
```

**Output (400) — invalid meeting_id:**
```json
{ "message": "meeting_id '...' not found in qr_sessions. Draft rejected." }
```

---

### 5.9 `GetDraftForMeeting`

**Endpoint:** `POST /getDraftForMeeting` — **Debug only**

Returns all draft overrides for a specific `meeting_id`. Queries `DRAFT#{meeting_id}`.

---

### 5.10 `SaveFinalAttendance`

**Endpoint:** `POST /saveFinalAttendance`

**Purpose:** Locks attendance permanently for a course section on a specific date.

**Input:**
```json
{
  "course_id":           "CSE101",
  "section_id":          "SEC1",
  "date":                "2026-03-07",
  "present_student_ids": ["S001", "S003"]
}
```

**How it works:** Scans roster, writes `_META_` marker + one FINAL record per student. Present if in `present_student_ids`, absent otherwise. Idempotent — re-saving overwrites previous FINAL.

**Output (200):**
```json
{
  "message":       "Final attendance saved",
  "pk":            "FINAL#CSE101#SEC1#2026-03-07",
  "roster_count":  2,
  "present_count": 2,
  "absent_count":  0
}
```

Note: `date` must be passed by the app in `YYYY-MM-DD` format. Lambda does not auto-detect today.

---

### 5.11 `GetFlagsForSession`

**Endpoint:** `POST /getFlagsForSession`

**Purpose:** Returns all security flags raised during a QR session.

**Input:** `{ "session_id": "..." }`

**How it works:** Fetches session from `qr_sessions` to get `meeting_id`, then queries `FLAG#{meeting_id}`.

**Output (200):**
```json
{
  "meeting_id":  "CSE101#SEC1#2026-03-07#a1b2c3d4",
  "flags_count": 1,
  "flags": [
    {
      "student_id":      "S999",
      "flag_reason":     "APP_ID_MISMATCH",
      "expected_app_id": "original-uuid",
      "received_app_id": "different-uuid",
      "timestamp":       "2026-03-07T08:16:00+00:00"
    }
  ]
}
```

To view all flags in DynamoDB console: `attendance` → Scan → filter `course_date` begins_with `FLAG#`.

---

### 5.12 `GetStudentAttendanceHistory`

**Endpoint:** `POST /studentAttendanceHistory`

**Purpose:** Student's full attendance history grouped by course/section.

**Input:** `{ "student_id": "S001", "limit": 100 }`

**How it works:**
1. Scans `attendance` table filtering by `student_id`.
2. Parses each record: FINAL/DRAFT/SCAN normalized. FLAG ignored. `_META_` skipped.
3. Per `(course_id, section_id, date)`: keeps best record. FINAL (300) > DRAFT (200) > SCAN (100). Newer timestamp breaks ties.
4. Sorts newest first, applies limit, groups by section.

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
        { "date": "2026-03-07", "status": "present", "source": "scan"  },
        { "date": "2026-03-04", "status": "absent",  "source": "final" }
      ]
    }
  ],
  "flat_days": [ "..." ]
}
```

`source` values: `final`, `draft_override`, `scan`.

---

### 5.13 `MarkAttendance` (Legacy / Not Used)

**Endpoint:** `POST /markAttendance`

Early prototype using old PK format. Not integrated with FINAL/DRAFT/SCAN system. Not called by either app.

---

### 5.14 `AutoFinalizeDailyAttendance` (EventBridge Triggered)

**Purpose:** Runs at 23:59 Cairo time daily. For each section meeting today with no FINAL record, writes all students present with `auto_finalized: true`.

**How it works:**
1. Determines today's date and DOW in Cairo time.
2. Scans entire `courses` table.
3. For each section meeting today: checks if FINAL already exists.
4. If FINAL exists → skip. If no FINAL → write all roster students as present with `auto_finalized: true`.

---

## 6. API Gateway Endpoints

**API Name:** SmartAttendanceAPI — HTTP API — All routes POST

| Route | Lambda Function | Used By |
|-------|----------------|---------|
| `POST /generateQr` | GenerateQrSessionFunction | Instructor App |
| `POST /getAbsentForMeeting` | GetAbsentForMeetingFunction | Instructor App |
| `POST /getDoctorCoursesSections` | GetDoctorCoursesSections | Instructor App |
| `POST /getDraftForMeeting` | GetDraftForMeetingFunction | Debug |
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

**Name:** `smart-attendance-auto-finalize`
**Cron:** `59 23 * * ? *` — every day 23:59 Cairo time
**Target:** `AutoFinalizeDailyAttendance` Lambda
**Status:** Disabled (enable for production)

---

## 8. Attendance State Machine & Priority Logic

```
When instructor opens a section:

Does FINAL#{course}#{section}#{today} exist?
  YES -> Load FINAL records. mode = "FINAL", has_final = true

  NO  -> find_all_meetings_today (qr_sessions + attendance fallback)
         Any activity (scans or drafts)?

           YES -> Merge all SCAN + DRAFT across all meetings today
                  Scanned = PRESENT
                  Draft present = PRESENT
                  Draft absent  = ABSENT
                  Everyone else = ABSENT
                  mode = "DRAFT", has_final = false

           NO  -> Default: everyone PRESENT
                  mode = "DEFAULT", has_final = false
```

**Priority:** FINAL > SCAN+DRAFT combined > Default

---

## 9. Instructor App — Screens & Flow

**Screen 1 — Login Page:**
- Instructor enters their MIU email (e.g. `lamia@miuegypt.edu.eg`)
- Flutter validates the domain is `@miuegypt.edu.eg`. If not → login rejected.
- The part before `@` is extracted as the `doctor_id` (e.g. `lamia`).
- This `doctor_id` is used in all subsequent API calls.

**Screen 2:** Courses & Sections list → app calls `POST /getDoctorCoursesSections` with the extracted `doctor_id` → shows only courses and sections meeting today.

**Screen 3:** Section Dashboard → `POST /getLatestMeetingForSectionToday` → roster with checkboxes. Buttons: Generate QR, Save Final Attendance.

**Screen 4:** QR Code Screen → `POST /generateQr` → full-screen QR, countdown using `duration_seconds` (60s). Close Early button.

**Screen 5:** Not Scanned Screen → `POST /getAbsentForMeeting` → absent students listed. Tap student → `POST /markDraftForMeeting` auto-called with `status: present`. Student disappears. No save button.

**Screen 6 (return to full list):** When navigating back from Screen 5 to Screen 3, the app must call `POST /getLatestMeetingForSectionToday` again to reload the correct merged state. Using stale local state will show incorrect attendance if students scanned in a previous QR session that is different from the current one. This refresh must happen on every return from the Not Scanned screen.

**Screen 7:** Save Final Attendance → `POST /saveFinalAttendance` with `{ course_id, section_id, date, present_student_ids[] }`.

---

## 10. Student App — Screens & Flow

**app_id:** Generated by Flutter on install. Bound on first scan via conditional write. Uninstall/reinstall requires manual binding reset.

**Screen 1 — Login Page:**
- Student enters their MIU email (e.g. `amr2106377@miuegypt.edu.eg`)
- Flutter validates the domain is `@miuegypt.edu.eg`. If not → login rejected.
- The student ID is extracted from the email — specifically the numeric part after the year prefix (e.g. from `amr2106377` → extracts `06377` as the `student_id`).
- This `student_id` is used in all subsequent API calls.

**Screen 2:** QR Scan → `POST /scanQr` with `{ session_id, student_id, app_id }`.

**Screen 3:** Attendance History → `POST /studentAttendanceHistory` → days grouped by section, newest first.

---

## 11. Security & Device Binding (app_id)

1. Flutter generates unique `app_id` UUID on install.
2. First scan: `ScanQr` binds `app_id` via `attribute_not_exists` conditional write. Only the first request ever can set it.
3. All subsequent scans: incoming `app_id` compared to stored. Mismatch → FLAG + 403.
4. First scan always trusted by design — whoever scans first owns the binding.

| Flag Reason | Trigger |
|-------------|---------|
| `APP_ID_MISMATCH` | Scanned from different phone/app installation |
| `NOT_ENROLLED_COURSE` | Student not enrolled in the course |
| `NOT_ENROLLED_SECTION` | Student enrolled in course but not this section |

---

## 12. Flag System

Flags written to `attendance` under `FLAG#{meeting_id}`. Non-blocking — scan is rejected but record stays for instructor review.

**View all flags in DynamoDB:** `attendance` → Scan → filter `course_date` begins_with `FLAG#`

**View flags for a session:** `POST /getFlagsForSession` with `session_id`

---

## 13. Complete Attendance Scenarios

### Scenario A: Manual Only
Doctor opens → DEFAULT → unchecks absent students → Save → FINAL locked.

### Scenario B: QR Only
Doctor generates QR → students scan → timer expires → Not Scanned screen → Save → FINAL (scanned=present, unscanned=absent).

### Scenario C: QR + Manual (student without phone)
Doctor generates QR → most scan → S3 has no phone → appears in Not Scanned → doctor taps S3 → `markDraftForMeeting` called automatically → S3 present → doctor saves → S3 in FINAL as present.

### Scenario D: Re-entering a section
Doctor re-opens section after saving → sees FINAL data → can adjust and save again (overwrites).

### Scenario E: Auto-finalize
Doctor doesn't open section → EventBridge at 23:59 → writes all students present with `auto_finalized: true`.

### Scenario F: Multiple QR sessions (instructor regenerates)
1. Doctor generates QR #1 → S1 and S2 scan → `SCAN#meeting_id_1` written.
2. Doctor closes early, generates QR #2.
3. `generateQr` finds today's existing `meeting_id_1` → reuses it. QR #2 gets new `session_id` but same `meeting_id_1`.
4. Nobody scans QR #2.
5. Not Scanned screen → both sources merge SCAN from `meeting_id_1` → S1 and S2 present → not in absent list.
6. Doctor returns to full list → app calls `getLatestMeetingForSectionToday` → S1 and S2 still present.
7. Draft marks from QR #1 still found and applied.

### Scenario G: Student scanned in earlier QR, instructor generates new QR
1. S1 and S2 scanned during QR #1 → `SCAN#meeting_id_1`.
2. Instructor generates QR #2 (same day) → same `meeting_id_1` reused.
3. Nobody scans QR #2.
4. Not Scanned screen: `getAbsentForMeeting` uses two-source discovery → finds `meeting_id_1` via attendance fallback even if not in `qr_sessions` → S1 and S2 present → empty absent list.
5. Doctor returns to full list → app calls `getLatestMeetingForSectionToday` → both students correctly shown present.

---

## 14. Lambda Functions NOT Used in the App (Debug Only)

| Function | Endpoint | Notes |
|----------|----------|-------|
| `MarkAttendanceFunction` | `POST /markAttendance` | Legacy prototype. Old PK format. Not integrated. |
| `GetScansForMeetingFunction` | `POST /getScansForMeeting` | Raw scan records for a meeting. |
| `GetDraftForMeetingFunction` | `POST /getDraftForMeeting` | Raw draft overrides for a meeting. |

---

## 15. Timezone & Date Handling

- All date/DOW calculations use `Africa/Cairo` (UTC+2, no DST) via `ZoneInfo("Africa/Cairo")`.
- `created_at` and `expires_at` in `qr_sessions` are Unix epoch **seconds** (integers).
- All other timestamps (`updated_at`, `saved_at`, `timestamp`, `app_id_bound_at`) are ISO 8601 UTC strings.
- Date strings: `YYYY-MM-DD` format.
- DOW abbreviations: 3 uppercase letters — `SUN`, `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`.
- A record saved at `2026-03-06T23:55 UTC` is `2026-03-07T01:55 Cairo time`. The `meeting_id` will contain `2026-03-07` (Cairo date) but `updated_at` shows `2026-03-06` (UTC). This is expected and correct.

---

## 16. Known Gotchas & Important Notes

### TTL on `qr_sessions` must be OFF
TTL was originally enabled on `expires_at`. This deleted sessions after 60 seconds, causing `GetLatestMeetingForSectionToday` and `GetAbsentForMeeting` to return wrong results after every QR expired. The QR expiry is handled entirely in code. TTL must remain disabled.

### `app_id` must be absent or a valid UUID — never empty string
If `app_id = ""` in a student record, `ScanQr` returns a 500 error. The empty string is falsy in Python, so the code enters the bind path, the conditional write fails (attribute exists), and the re-read returns `""` again. Fix: remove the `app_id` attribute entirely from the student record in DynamoDB.

### `MarkDraftForMeeting` validates meeting_id
Rejects any `meeting_id` not found in `qr_sessions`. Never call this endpoint via Postman with a custom `meeting_id` that was not generated by `generateQr`.

### Two-source meeting discovery in `GetLatestMeeting` and `GetAbsentForMeeting`
Both functions use `find_all_meetings_today` which checks `qr_sessions` first, then scans `attendance` directly as a fallback. This makes both functions resilient to orphaned meeting_ids and to any `qr_sessions` records being missing.

### Flutter must refresh after returning from Not Scanned screen
When the instructor returns from the Not Scanned screen to the full attendance list, the app must call `getLatestMeetingForSectionToday` again. Without this refresh, the app shows stale local state which may be missing students who scanned in a different QR session earlier in the day.

### DynamoDB Scan vs Query
- **Query:** Direct lookup by partition key. Fast, cheap.
- **Scan:** Reads every item in the table then filters. Slow, expensive.
- Roster lookups and QR session discovery are scans (no suitable index). GSIs are a future improvement.

### Phone clock vs server clock
Use `duration_seconds` from the API response (always 60) for the Flutter countdown timer — not `expires_at - DateTime.now()`. A phone clock ahead of the server would otherwise show more seconds than actually remain.

---

## 17. Course Import Tool (Excel to DynamoDB)

Instead of manually adding courses to DynamoDB one by one, you can use the Excel import tool to bulk-upload courses and sections in one step.

### Excel File Format

The file is named `courses_import.xlsx` and has one sheet with these columns:

| Column | Description | Example |
|--------|-------------|---------|
| `course_id` | Unique course identifier | `CSE102` |
| `course_name` | Human-readable course name | `CMOS` |
| `section_id` | Section identifier (can repeat across courses) | `SEC1` |
| `doctor_ids` | Comma-separated doctor IDs | `D001` or `D001,D002` |
| `meeting_days` | Comma-separated 3-letter day codes | `SUN,MON` or `TUE,WED` |

**Rules:**
- One row per section. If a course has 2 sections, it needs 2 rows with the same `course_id`.
- `meeting_days` must use 3-letter uppercase codes: `SUN`, `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`.
- Multiple `doctor_ids` separated by comma: `D001,D002`.
- Same `section_id` (e.g. `SEC1`) can be used in different courses — they never conflict because the system always uses `course_id#section_id` as the key.

**Example rows:**
```
course_id | course_name | section_id | doctor_ids | meeting_days
CSE102    | CMOS        | SEC1       | D001       | SUN,MON
CSE102    | CMOS        | SEC2       | D002       | TUE,WED
```

### Python Script

The script is named `import_courses.py`. Place it in the same parent folder as `courses_import.xlsx` (or update the `EXCEL_FILE` path inside it).

**Script configuration (top of file):**
```python
EXCEL_FILE = "AttendanceTools\\courses_import.xlsx"  # path to Excel file
TABLE_NAME = "courses"                                # DynamoDB table name
AWS_REGION = "il-central-1"                          # AWS region
```

**AWS credentials** are embedded directly in the script:
```python
dynamodb = boto3.resource(
    "dynamodb",
    region_name=AWS_REGION,
    aws_access_key_id="YOUR_ACCESS_KEY",
    aws_secret_access_key="YOUR_SECRET_KEY"
)
```

### How to Run

1. Open Command Prompt
2. Navigate to the folder containing `import_courses.py`:
```
D:
cd grad
```
3. Run the script:
```
python import_courses.py
```
4. You should see output like:
```
Uploaded: CSE102 — 2 section(s)
Done!
```
5. Verify in DynamoDB console → `courses` table → Explore items → confirm the course appears with correct sections.

### Adding More Courses in the Future

Just add more rows to `courses_import.xlsx` and run the script again. The script uses `put_item` so it will overwrite any existing course with the same `course_id`. This means if you add a new section to an existing course, just add the new row and re-run — it will update correctly.

### Required Python Packages

```
pip install boto3 pandas openpyxl
```

---

### Students Import Tool

The same Excel import approach works for bulk-uploading students.

**Excel file format** (`students_import.xlsx`):

| Column | Description | Example |
|--------|-------------|---------|
| `student_id` | Unique student identifier | `S001` |
| `name` | Student full name | `Amr Yasser` |
| `email` | Student email | `amr@miuegypt.edu.eg` |
| `major_id` | Major/department ID | `ENG01` |
| `course_ids` | Comma-separated course IDs | `CSE101,CSE102` |
| `section_ids` | Comma-separated compound section keys | `CSE101#SEC1,CSE102#SEC1` |

**Rules:**
- `section_ids` must use compound format: `{course_id}#{section_id}`
- Multiple courses/sections separated by comma
- Do NOT include `app_id` or `app_id_bound_at` — these are set automatically on first QR scan

**Python script** (`import_students.py`):
```python
import boto3
import pandas as pd

EXCEL_FILE = "AttendanceTools\\students_import.xlsx"
TABLE_NAME = "students"
AWS_REGION = "il-central-1"

dynamodb = boto3.resource(
    "dynamodb",
    region_name=AWS_REGION,
    aws_access_key_id="YOUR_ACCESS_KEY",
    aws_secret_access_key="YOUR_SECRET_KEY"
)
table = dynamodb.Table(TABLE_NAME)

df = pd.read_excel(EXCEL_FILE, dtype=str)
df = df.fillna("")

for _, row in df.iterrows():
    student_id = row["student_id"].strip()
    name       = row["name"].strip()
    email      = row["email"].strip()
    major_id   = row["major_id"].strip()
    course_ids = [c.strip() for c in row["course_ids"].split(",") if c.strip()]
    section_ids= [s.strip() for s in row["section_ids"].split(",") if s.strip()]

    table.put_item(Item={
        "student_id":  student_id,
        "name":        name,
        "email":       email,
        "major_id":    major_id,
        "course_ids":  course_ids,
        "section_ids": section_ids
    })
    print(f"Uploaded: {student_id} — {name}")

print("\nDone!")
```

Run the same way as courses import:
```
python import_students.py
```

---

## 18. Future Improvements

### Deployment & Scale
- **Deploy college-wide** — Apply the system to the entire college with all courses, sections, students, and instructors for real production use

### Security
- Replace manual `doctor_id` entry with Cognito authentication + JWT tokens
- API Gateway authorizers to separate instructor and student endpoints
- Secure `app_id` reset flow for students who change phones

### Features
- Student app real login (Cognito)
- Web admin panel for managing courses, sections, enrollment
- Attendance analytics and export to CSV/Excel
- Late arrival logic (mark as "late" after N minutes)
- GPS validation (only allow scans within campus)
- Multi-session per day support (morning + afternoon classes)

### Infrastructure
- CloudWatch structured logging
- EventBridge cleanup jobs for old SCAN/DRAFT records (since TTL is disabled)
- GSI on `attendance` for efficient student-based queries
- GSI on `students` for section-based queries
