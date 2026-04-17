package dev.cinema.latam.loyalty;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.notNullValue;

@QuarkusTest
class PointsResourceTest {

    @Test
    void testHealthEndpoint() {
        given()
            .when().get("/health")
            .then()
                .statusCode(200)
                .body("status", is("UP"))
                .body("service", is("loyalty"));
    }

    @Test
    void testPingEndpoint() {
        given()
            .when().get("/ping")
            .then()
                .statusCode(200)
                .body(is("pong"));
    }

    @Test
    void testGetAllAccountsEmpty() {
        given()
            .when().get("/api/loyalty/accounts")
            .then()
                .statusCode(200);
    }

    @Test
    void testCreateAccount() {
        given()
            .when().post("/api/loyalty/accounts/user123")
            .then()
                .statusCode(200)
                .body("userId", is("user123"))
                .body("currentPoints", is(0))
                .body("tier", is("BRONZE"));
    }

    @Test
    void testEarnPoints() {
        // Create account first
        given()
            .when().post("/api/loyalty/accounts/user456")
            .then()
                .statusCode(200);

        // Earn points
        given()
            .queryParam("points", 100)
            .queryParam("description", "Ticket purchase")
            .when().post("/api/loyalty/accounts/user456/earn")
            .then()
                .statusCode(200)
                .body("currentPoints", is(100))
                .body("totalPoints", is(100));
    }

    @Test
    void testGetTransactions() {
        given()
            .when().get("/api/loyalty/accounts/user456/transactions")
            .then()
                .statusCode(200);
    }
}
