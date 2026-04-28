# Policy: GitOps Deployment Freeze
# Blocks sync operations during off-hours
#
# Blocked: 11:00 PM - 8:00 AM Mexico Central Time
# Allowed: 8:00 AM - 11:00 PM Mexico Central Time
#
# In UTC (Mexico CST = UTC-6):
# Blocked: 05:00 - 14:00 UTC
# Allowed: 14:00 - 05:00 UTC (crosses midnight)
#
# Event: On Sync
# Severity: Error and Exit
#
# Note: This policy does NOT apply to:
# - ArgoCD auto-syncs (only manual syncs via Harness UI/API)
# - Syncs triggered directly on cluster (argocd CLI)

package gitopsApplication

import future.keywords.if
import future.keywords.in

# Deployment window configuration
# Mexico Central Time (CST) = UTC-6
# 8 AM Mexico = 14:00 UTC
# 11 PM Mexico = 05:00 UTC (next day)
#
# Since the allowed window crosses midnight UTC, we define the BLOCKED window instead
blocked_start_hour := 5   # 11 PM Mexico = 05:00 UTC
blocked_end_hour := 14    # 8 AM Mexico = 14:00 UTC

# Allowed days (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
allowed_days := [1, 2, 3, 4, 5]  # Monday to Friday

# Environments that bypass the freeze (emergency deployments)
bypass_environments := ["hotfix", "emergency"]

# Calculate current hour from Unix timestamp
current_hour := hour if {
    hour := floor(input.metadata.timestamp / 3600) % 24
}

# Calculate current day of week from Unix timestamp
# Unix epoch (Jan 1, 1970) was a Thursday (day 4)
current_day := day if {
    days_since_epoch := floor(input.metadata.timestamp / 86400)
    day := (days_since_epoch + 4) % 7
}

# Check if current time is in BLOCKED window (05:00 - 14:00 UTC)
is_blocked_hour if {
    current_hour >= blocked_start_hour
    current_hour < blocked_end_hour
}

# Allowed = NOT in blocked window
is_allowed_hour if {
    not is_blocked_hour
}

# Check if current day is an allowed day
is_allowed_day if {
    current_day in allowed_days
}

# Check if environment bypasses the freeze
is_bypass_environment if {
    env := input.gitopsApplication.app.metadata.labels["harness.io/envRef"]
    env in bypass_environments
}

is_bypass_environment if {
    env := input.gitopsApplication.app.spec.destination.namespace
    contains(env, "hotfix")
}

# Deny if in blocked hours (and not a bypass environment)
deny[msg] if {
    is_blocked_hour
    not is_bypass_environment
    mexico_hour := (current_hour + 18) % 24  # UTC to Mexico (UTC-6)
    msg := sprintf(
        "Deployment blocked: Sync operations for '%s' are not allowed between 11:00 PM and 8:00 AM Mexico Central Time. Current time: %d:00 Mexico / %d:00 UTC. Deployments resume at 8:00 AM Mexico. For emergency deployments, use the 'hotfix' environment.",
        [input.gitopsApplication.name, mexico_hour, current_hour]
    )
}

# Deny if on weekend (and not a bypass environment)
deny[msg] if {
    not is_allowed_day
    not is_bypass_environment
    day_name := day_names[current_day]
    msg := sprintf(
        "Deployment blocked: Sync operations for '%s' are not allowed on weekends (%s). Deployments are permitted Monday through Friday. For emergency deployments, use the 'hotfix' environment.",
        [input.gitopsApplication.name, day_name]
    )
}

# Day name mapping for readable messages
day_names := {
    0: "Sunday",
    1: "Monday",
    2: "Tuesday",
    3: "Wednesday",
    4: "Thursday",
    5: "Friday",
    6: "Saturday"
}

# Warn if deploying close to freeze window (10 PM - 11 PM Mexico = 04:00 - 05:00 UTC)
warn[msg] if {
    is_allowed_hour
    is_allowed_day
    current_hour >= 4
    current_hour < 5
    msg := sprintf(
        "Warning: Deploying '%s' close to freeze window. Deployments will be blocked at 11:00 PM Mexico (05:00 UTC). Current time: 10:00 PM Mexico. Ensure deployment completes soon.",
        [input.gitopsApplication.name]
    )
}
