# Policy: Deployment Window Check (Custom Policy Step)
# Blocks deployments during business hours
#
# Timezone: Mexico Central Time (CST = UTC-6)
# Blocked: 9:00 AM - 6:00 PM Mexico (15:00 - 00:00 UTC)
# Allowed: 6:00 PM - 9:00 AM Mexico (00:00 - 15:00 UTC)
#
# Type: Custom
# Event: On Step (Policy Step in Pipeline)

package policy

import future.keywords.if
import future.keywords.in

# =============================================================================
# CONFIGURATION
# =============================================================================

# Deployment window configuration (UTC)
# Mexico Central Time (CST) = UTC-6
blocked_start_hour := 15  # 9 AM Mexico = 15:00 UTC
blocked_end_hour := 24    # 6 PM Mexico = 00:00 UTC (end of day)

# Allowed days (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
allowed_days := [1, 2, 3, 4, 5]  # Monday to Friday

# Environments that bypass the freeze
bypass_environments := ["hotfix", "emergency"]

# =============================================================================
# INPUT EXTRACTION (with multiple fallback paths)
# =============================================================================

# Raw timestamp from input (may be string like "1777360373481 / 1000" or number)
raw_timestamp := input.metadata.timestamp if input.metadata.timestamp
raw_timestamp := input.timestamp if input.timestamp

# Parse timestamp - handle string format "1777360373481 / 1000" from Harness
# Extract the milliseconds part before " / " and convert to seconds
parse_timestamp_string := ts if {
    is_string(raw_timestamp)
    parts := split(raw_timestamp, " / ")
    ms := to_number(trim_space(parts[0]))
    ts := floor(ms / 1000)  # Convert ms to seconds
}

# If timestamp is already a number (seconds)
parse_timestamp_number := ts if {
    is_number(raw_timestamp)
    raw_timestamp > 1000000000000  # It's in milliseconds
    ts := floor(raw_timestamp / 1000)
}

parse_timestamp_number := raw_timestamp if {
    is_number(raw_timestamp)
    raw_timestamp <= 1000000000000  # It's already in seconds
}

# Final timestamp in seconds
get_timestamp := parse_timestamp_string if parse_timestamp_string
get_timestamp := parse_timestamp_number if parse_timestamp_number

# Get environment from GitOps application labels
get_environment := input.gitopsApplication.app.metadata.labels["harness.io/envRef"] if {
    input.gitopsApplication.app.metadata.labels["harness.io/envRef"]
}
get_environment := "unknown" if {
    not input.gitopsApplication.app.metadata.labels["harness.io/envRef"]
}

# Get application name
get_app_name := input.gitopsApplication.name if input.gitopsApplication.name
get_app_name := "unknown-app" if not input.gitopsApplication.name

# =============================================================================
# TIME CALCULATIONS
# =============================================================================

# Calculate current hour from Unix timestamp (seconds)
current_hour := floor(get_timestamp / 3600) % 24

# Calculate current day of week from Unix timestamp
current_day := (floor(get_timestamp / 86400) + 4) % 7

# Convert UTC hour to Mexico Central Time for messages
utc_to_mexico(utc_hour) := (utc_hour + 18) % 24

# Day name mapping
day_names := {
    0: "Sunday",
    1: "Monday",
    2: "Tuesday",
    3: "Wednesday",
    4: "Thursday",
    5: "Friday",
    6: "Saturday"
}

# =============================================================================
# DENY RULES - Main Logic
# =============================================================================

# DENY: No timestamp in input (cannot evaluate time-based rules)
deny[msg] if {
    not get_timestamp
    msg := sprintf(
        "DEPLOYMENT BLOCKED: Cannot evaluate deployment window - no timestamp found in input. App: '%s', Env: '%s'. Input keys: %v",
        [get_app_name, get_environment, object.keys(input)]
    )
}

# DENY: Deployment during blocked hours (9AM - 6PM Mexico = 15:00 - 00:00 UTC)
deny[msg] if {
    get_timestamp
    current_hour >= blocked_start_hour
    not get_environment in bypass_environments
    mexico_hour := utc_to_mexico(current_hour)
    msg := sprintf(
        "DEPLOYMENT BLOCKED: App '%s' (env: %s) cannot deploy between 9AM-6PM Mexico time (business hours). Current: %d:00 Mexico (%d:00 UTC). Resumes at 6PM Mexico (00:00 UTC).",
        [get_app_name, get_environment, mexico_hour, current_hour]
    )
}

# DENY: Deployment on weekends
deny[msg] if {
    get_timestamp
    not current_day in allowed_days
    not get_environment in bypass_environments
    day_name := day_names[current_day]
    msg := sprintf(
        "DEPLOYMENT BLOCKED: App '%s' (env: %s) cannot deploy on %s. Only Monday-Friday allowed.",
        [get_app_name, get_environment, day_name]
    )
}

# =============================================================================
# WARN RULES
# =============================================================================

# WARN: Close to freeze window (8AM - 9AM Mexico = 14:00 - 15:00 UTC)
warn[msg] if {
    get_timestamp
    current_hour >= 14
    current_hour < 15
    current_day in allowed_days
    msg := sprintf(
        "WARNING: App '%s' deploying near freeze window. Blocked at 9AM Mexico (15:00 UTC).",
        [get_app_name]
    )
}
