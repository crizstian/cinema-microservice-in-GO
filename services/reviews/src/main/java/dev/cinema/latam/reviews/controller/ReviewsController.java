package dev.cinema.latam.reviews.controller;

import dev.cinema.latam.reviews.model.Review;
import dev.cinema.latam.reviews.model.ReviewRequest;
import dev.cinema.latam.reviews.model.ReviewStats;
import dev.cinema.latam.reviews.service.ReviewService;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.*;

import java.util.List;

@Controller("/api/reviews")
public class ReviewsController {

    private final ReviewService reviewService;

    public ReviewsController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    @Get
    public List<Review> getAllReviews() {
        return reviewService.getAllReviews();
    }

    @Get("/{id}")
    public HttpResponse<Review> getReview(String id) {
        return reviewService.getReview(id)
                .map(HttpResponse::ok)
                .orElse(HttpResponse.notFound());
    }

    @Get("/movie/{movieId}")
    public List<Review> getReviewsByMovie(String movieId) {
        return reviewService.getReviewsByMovie(movieId);
    }

    @Get("/movie/{movieId}/stats")
    public ReviewStats getMovieStats(String movieId) {
        return reviewService.getMovieStats(movieId);
    }

    @Get("/user/{userId}")
    public List<Review> getReviewsByUser(String userId) {
        return reviewService.getReviewsByUser(userId);
    }

    @Post
    public Review createReview(@Body ReviewRequest request) {
        return reviewService.createReview(request);
    }

    @Put("/{id}")
    public HttpResponse<Review> updateReview(String id, @Body ReviewRequest request) {
        return reviewService.updateReview(id, request)
                .map(HttpResponse::ok)
                .orElse(HttpResponse.notFound());
    }

    @Delete("/{id}")
    public HttpResponse<Void> deleteReview(String id) {
        if (reviewService.deleteReview(id)) {
            return HttpResponse.noContent();
        }
        return HttpResponse.notFound();
    }

    @Post("/{id}/helpful")
    public HttpResponse<Review> markHelpful(String id) {
        return reviewService.markHelpful(id)
                .map(HttpResponse::ok)
                .orElse(HttpResponse.notFound());
    }
}
