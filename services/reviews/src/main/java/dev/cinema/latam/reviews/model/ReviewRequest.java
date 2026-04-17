package dev.cinema.latam.reviews.model;

import io.micronaut.serde.annotation.Serdeable;

@Serdeable
public record ReviewRequest(
        String movieId,
        String userId,
        String userName,
        int rating,
        String title,
        String content
) {
}
