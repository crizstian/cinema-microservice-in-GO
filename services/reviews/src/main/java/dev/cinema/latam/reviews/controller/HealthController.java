package dev.cinema.latam.reviews.controller;

import io.micronaut.http.MediaType;
import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Get;
import io.micronaut.http.annotation.Produces;

import java.util.Map;

@Controller
public class HealthController {

    @Get("/health")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String> health() {
        return Map.of("status", "UP", "service", "reviews");
    }

    @Get("/ping")
    @Produces(MediaType.TEXT_PLAIN)
    public String ping() {
        return "pong";
    }
}
