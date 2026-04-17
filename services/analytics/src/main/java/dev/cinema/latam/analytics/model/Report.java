package dev.cinema.latam.analytics.model;

import java.time.LocalDateTime;
import java.util.Map;

public record Report(
        String id,
        ReportType type,
        String title,
        Map<String, Object> data,
        LocalDateTime generatedAt
) {
}
