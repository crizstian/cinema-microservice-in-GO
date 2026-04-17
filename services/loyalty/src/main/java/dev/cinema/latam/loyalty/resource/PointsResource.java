package dev.cinema.latam.loyalty.resource;

import dev.cinema.latam.loyalty.model.LoyaltyAccount;
import dev.cinema.latam.loyalty.model.PointsTransaction;
import dev.cinema.latam.loyalty.service.PointsService;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;

@Path("/api/loyalty")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class PointsResource {

    @Inject
    PointsService pointsService;

    @GET
    @Path("/accounts")
    public List<LoyaltyAccount> getAllAccounts() {
        return pointsService.getAllAccounts();
    }

    @GET
    @Path("/accounts/{userId}")
    public Response getAccount(@PathParam("userId") String userId) {
        return pointsService.getAccount(userId)
                .map(account -> Response.ok(account).build())
                .orElse(Response.status(Response.Status.NOT_FOUND).build());
    }

    @POST
    @Path("/accounts/{userId}")
    public LoyaltyAccount createAccount(@PathParam("userId") String userId) {
        return pointsService.createAccount(userId);
    }

    @POST
    @Path("/accounts/{userId}/earn")
    public LoyaltyAccount earnPoints(
            @PathParam("userId") String userId,
            @QueryParam("points") int points,
            @QueryParam("description") String description) {
        return pointsService.earnPoints(userId, points, description);
    }

    @POST
    @Path("/accounts/{userId}/redeem")
    public Response redeemPoints(
            @PathParam("userId") String userId,
            @QueryParam("points") int points,
            @QueryParam("description") String description) {
        return pointsService.redeemPoints(userId, points, description)
                .map(account -> Response.ok(account).build())
                .orElse(Response.status(Response.Status.BAD_REQUEST)
                        .entity(java.util.Map.of("error", "Insufficient points"))
                        .build());
    }

    @GET
    @Path("/accounts/{userId}/transactions")
    public List<PointsTransaction> getTransactions(@PathParam("userId") String userId) {
        return pointsService.getTransactions(userId);
    }

    @GET
    @Path("/accounts/{userId}/tier")
    public Response getTier(@PathParam("userId") String userId) {
        return pointsService.getAccount(userId)
                .map(account -> Response.ok(java.util.Map.of(
                        "userId", userId,
                        "tier", account.tier(),
                        "totalPoints", account.totalPoints()
                )).build())
                .orElse(Response.status(Response.Status.NOT_FOUND).build());
    }
}
