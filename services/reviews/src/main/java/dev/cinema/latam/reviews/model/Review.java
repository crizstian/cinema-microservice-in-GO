package dev.cinema.latam.reviews.model;

import io.micronaut.serde.annotation.Serdeable;

import java.time.LocalDateTime;

@Serdeable
public record Review(
        String id,
        String movieId,
        String userId,
        String userName,
        int rating,
        String title,
        String content,
        int helpfulCount,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
    public Review withHelpfulIncrement() {
        return new Review(
                id, movieId, userId, userName, rating, title, content,
                helpfulCount + 1, createdAt, LocalDateTime.now()
        );
    }

    public Review withUpdate(String newTitle, String newContent, int newRating) {
        return new Review(
                id, movieId, userId, userName, newRating, newTitle, newContent,
                helpfulCount, createdAt, LocalDateTime.now()
        );
    }
}
