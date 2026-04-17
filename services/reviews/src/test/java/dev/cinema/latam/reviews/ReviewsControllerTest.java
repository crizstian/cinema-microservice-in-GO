package dev.cinema.latam.reviews;

import io.micronaut.http.HttpRequest;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.HttpStatus;
import io.micronaut.http.client.HttpClient;
import io.micronaut.http.client.annotation.Client;
import io.micronaut.test.extensions.junit5.annotation.MicronautTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

@MicronautTest
class ReviewsControllerTest {

    @Inject
    @Client("/")
    HttpClient client;

    @Test
    void testHealthEndpoint() {
        HttpResponse<Map> response = client.toBlocking()
                .exchange(HttpRequest.GET("/health"), Map.class);

        assertEquals(HttpStatus.OK, response.getStatus());
        assertEquals("UP", response.body().get("status"));
        assertEquals("reviews", response.body().get("service"));
    }

    @Test
    void testPingEndpoint() {
        String response = client.toBlocking()
                .retrieve(HttpRequest.GET("/ping"));

        assertEquals("pong", response);
    }

    @Test
    void testGetAllReviews() {
        HttpResponse<List> response = client.toBlocking()
                .exchange(HttpRequest.GET("/api/reviews"), List.class);

        assertEquals(HttpStatus.OK, response.getStatus());
        assertNotNull(response.body());
        assertTrue(response.body().size() >= 0);
    }

    @Test
    void testGetReviewsByMovie() {
        HttpResponse<List> response = client.toBlocking()
                .exchange(HttpRequest.GET("/api/reviews/movie/movie1"), List.class);

        assertEquals(HttpStatus.OK, response.getStatus());
    }

    @Test
    void testGetMovieStats() {
        HttpResponse<Map> response = client.toBlocking()
                .exchange(HttpRequest.GET("/api/reviews/movie/movie1/stats"), Map.class);

        assertEquals(HttpStatus.OK, response.getStatus());
        assertNotNull(response.body().get("movieId"));
        assertNotNull(response.body().get("averageRating"));
    }

    @Test
    void testCreateReview() {
        Map<String, Object> request = Map.of(
                "movieId", "movie3",
                "userId", "user3",
                "userName", "Test User",
                "rating", 4,
                "title", "Test Review",
                "content", "This is a test review"
        );

        HttpResponse<Map> response = client.toBlocking()
                .exchange(HttpRequest.POST("/api/reviews", request), Map.class);

        assertEquals(HttpStatus.OK, response.getStatus());
        assertEquals("movie3", response.body().get("movieId"));
        assertEquals(4, response.body().get("rating"));
    }
}
