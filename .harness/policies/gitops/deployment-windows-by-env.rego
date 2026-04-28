# Policy: GitOps Deployment Windows by Environment
# Different deployment windows for each environment tier
#
# Timezone: Mexico Central Time (CST = UTC-6)
#
# DEV: 24/7 (always allowed)
# STAGING: Business hours (9 AM - 6 PM Mexico, Mon-Fri)
# PROD: Restricted window (10 AM - 4 PM Mexico, Tue-Thu only)
#
# Event: On Sync
# Severity: Error and Exit

package gitopsApplication

import future.keywords.if
import future.keywords.in

# Environment deployment windows (UTC)
# Mexico Central Time (CST) = UTC-6
# Example: 9 AM Mexico = 15:00 UTC, 6 PM Mexico = 00:00 UTC
deployment_windows := {
    "dev": {
        "start": 0,
        "end": 24,
        "days": [0, 1, 2, 3, 4, 5, 6],
        "description": "24/7",
        "mexico_desc": "24/7"
    },
    "staging": {
        "start": 15,
        "end": 24,
        "days": [1, 2, 3, 4, 5],
        "description": "15:00-00:00 UTC",
        "mexico_desc": "9 AM - 6 PM Mexico (Mon-Fri)"
    },
    "prod": {
        "start": 16,
        "end": 22,
        "days": [2, 3, 4],
        "description": "16:00-22:00 UTC",
        "mexico_desc": "10 AM - 4 PM Mexico (Tue-Thu)"
    },
    "production": {
        "start": 16,
        "end": 22,
        "days": [2, 3, 4],
        "description": "16:00-22:00 UTC",
        "mexico_desc": "10 AM - 4 PM Mexico (Tue-Thu)"
    }
}

# Default window for unknown environments (same as staging)
default_window := {
    "start": 15,
    "end": 24,
    "days": [1, 2, 3, 4, 5],
    "description": "15:00-00:00 UTC",
    "mexico_desc": "9 AM - 6 PM Mexico (Mon-Fri)"
}

# Calculate current hour from Unix timestamp
current_hour := floor(input.metadata.timestamp / 3600) % 24

# Calculate current day of week (0 = Sunday)
current_day := (floor(input.metadata.timestamp / 86400) + 4) % 7

# Extract environment from namespace or labels
get_environment := env if {
    env := input.gitopsApplication.app.metadata.labels["harness.io/envRef"]
} else := env if {
    ns := input.gitopsApplication.app.spec.destination.namespace
    env := extract_env_from_namespace(ns)
} else := "unknown"

# Extract environment tier from namespace name
extract_env_from_namespace(ns) := "dev" if {
    contains(ns, "dev")
} else := "staging" if {
    contains(ns, "staging")
} else := "staging" if {
    contains(ns, "stage")
} else := "prod" if {
    contains(ns, "prod")
} else := "unknown"

# Get deployment window for environment
get_window := window if {
    env := get_environment
    window := deployment_windows[env]
} else := default_window

# Check if deployment is allowed
is_within_hours if {
    window := get_window
    current_hour >= window.start
    current_hour < window.end
}

is_allowed_day if {
    window := get_window
    current_day in window.days
}

# Day name mapping
day_names := {
    0: "Sunday", 1: "Monday", 2: "Tuesday",
    3: "Wednesday", 4: "Thursday", 5: "Friday", 6: "Saturday"
}

# Convert UTC hour to Mexico Central Time
utc_to_mexico(utc_hour) := (utc_hour + 18) % 24

# Deny if outside deployment window
deny[msg] if {
    not is_within_hours
    env := get_environment
    window := get_window
    mexico_hour := utc_to_mexico(current_hour)
    msg := sprintf(
        "Deployment blocked for '%s' (environment: %s). Current time: %d:00 Mexico / %d:00 UTC. Allowed window: %s. Please schedule deployment during permitted hours.",
        [input.gitopsApplication.name, env, mexico_hour, current_hour, window.mexico_desc]
    )
}

deny[msg] if {
    not is_allowed_day
    env := get_environment
    window := get_window
    day_name := day_names[current_day]
    msg := sprintf(
        "Deployment blocked for '%s' (environment: %s). Today is %s, which is outside the allowed deployment days. Allowed: %s.",
        [input.gitopsApplication.name, env, day_name, window.mexico_desc]
    )
}

# Warning for production deployments (even when allowed)
warn[msg] if {
    env := get_environment
    env in ["prod", "production"]
    is_within_hours
    is_allowed_day
    msg := sprintf(
        "Production deployment: '%s' is being synced to production. Ensure all approvals are in place and monitoring is active.",
        [input.gitopsApplication.name]
    )
}
