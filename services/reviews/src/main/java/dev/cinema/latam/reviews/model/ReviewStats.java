package dev.cinema.latam.reviews.model;

import io.micronaut.serde.annotation.Serdeable;

import java.util.Map;

@Serdeable
public record ReviewStats(
        String movieId,
        double averageRating,
        int totalReviews,
        Map<Integer, Integer> ratingDistribution
) {
}
