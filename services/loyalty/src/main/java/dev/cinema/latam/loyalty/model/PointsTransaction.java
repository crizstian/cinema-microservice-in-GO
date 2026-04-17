package dev.cinema.latam.loyalty.model;

import java.time.LocalDateTime;

public record PointsTransaction(
        String id,
        String userId,
        TransactionType type,
        int points,
        String description,
        LocalDateTime timestamp
) {
}
