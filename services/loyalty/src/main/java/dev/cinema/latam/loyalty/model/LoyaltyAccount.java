package dev.cinema.latam.loyalty.model;

import java.time.LocalDateTime;

public record LoyaltyAccount(
        String id,
        String userId,
        int currentPoints,
        int totalPoints,
        LoyaltyTier tier,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
    public LoyaltyAccount withPoints(int current, int total) {
        return new LoyaltyAccount(
                id, userId, current, total,
                LoyaltyTier.fromPoints(total),
                createdAt, LocalDateTime.now()
        );
    }
}
