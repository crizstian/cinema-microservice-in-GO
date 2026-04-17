package dev.cinema.latam.reviews.service;

import dev.cinema.latam.reviews.model.Review;
import dev.cinema.latam.reviews.model.ReviewRequest;
import dev.cinema.latam.reviews.model.ReviewStats;
import jakarta.inject.Singleton;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Singleton
public class ReviewService {

    private final Map<String, Review> reviews = new ConcurrentHashMap<>();

    public ReviewService() {
        createReview(new ReviewRequest("movie1", "user1", "John Doe", 5, "Amazing!", "Best movie ever"));
        createReview(new ReviewRequest("movie1", "user2", "Jane Smith", 4, "Great film", "Really enjoyed it"));
        createReview(new ReviewRequest("movie2", "user1", "John Doe", 3, "Okay", "Nothing special"));
    }

    public List<Review> getAllReviews() {
        return new ArrayList<>(reviews.values());
    }

    public Optional<Review> getReview(String id) {
        return Optional.ofNullable(reviews.get(id));
    }

    public List<Review> getReviewsByMovie(String movieId) {
        return reviews.values().stream()
                .filter(r -> r.movieId().equals(movieId))
                .sorted(Comparator.comparing(Review::createdAt).reversed())
                .toList();
    }

    public List<Review> getReviewsByUser(String userId) {
        return reviews.values().stream()
                .filter(r -> r.userId().equals(userId))
                .sorted(Comparator.comparing(Review::createdAt).reversed())
                .toList();
    }

    public ReviewStats getMovieStats(String movieId) {
        List<Review> movieReviews = getReviewsByMovie(movieId);

        if (movieReviews.isEmpty()) {
            return new ReviewStats(movieId, 0.0, 0, Map.of());
        }

        double average = movieReviews.stream()
                .mapToInt(Review::rating)
                .average()
                .orElse(0.0);

        Map<Integer, Integer> distribution = movieReviews.stream()
                .collect(Collectors.groupingBy(
                        Review::rating,
                        Collectors.collectingAndThen(Collectors.counting(), Long::intValue)
                ));

        return new ReviewStats(movieId, Math.round(average * 10) / 10.0, movieReviews.size(), distribution);
    }

    public Review createReview(ReviewRequest request) {
        String id = UUID.randomUUID().toString();
        LocalDateTime now = LocalDateTime.now();

        Review review = new Review(
                id,
                request.movieId(),
                request.userId(),
                request.userName(),
                Math.min(5, Math.max(1, request.rating())),
                request.title(),
                request.content(),
                0,
                now,
                now
        );

        reviews.put(id, review);
        return review;
    }

    public Optional<Review> updateReview(String id, ReviewRequest request) {
        Review existing = reviews.get(id);
        if (existing == null) {
            return Optional.empty();
        }

        Review updated = existing.withUpdate(request.title(), request.content(), request.rating());
        reviews.put(id, updated);
        return Optional.of(updated);
    }

    public boolean deleteReview(String id) {
        return reviews.remove(id) != null;
    }

    public Optional<Review> markHelpful(String id) {
        Review existing = reviews.get(id);
        if (existing == null) {
            return Optional.empty();
        }

        Review updated = existing.withHelpfulIncrement();
        reviews.put(id, updated);
        return Optional.of(updated);
    }
}
