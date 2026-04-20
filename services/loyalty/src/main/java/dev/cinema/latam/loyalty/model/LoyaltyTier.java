package dev.cinema.latam.loyalty.model;

public enum LoyaltyTier {
    BRONZE(0, 1.0),
    SILVER(1000, 1.25),
    GOLD(5000, 1.5),
    PLATINUM(15000, 2.0);

    private final int minPoints;
    private final double multiplier;

    LoyaltyTier(int minPoints, double multiplier) {
        this.minPoints = minPoints;
        this.multiplier = multiplier;
    }

    public int getMinPoints() {
        return minPoints;
    }

    public double getMultiplier() {
        return multiplier;
    }

    public static LoyaltyTier fromPoints(int totalPoints) {
        LoyaltyTier result = BRONZE;
        for (LoyaltyTier tier : values()) {
            if (totalPoints >= tier.minPoints) {
                result = tier;
            }
        }
        return result;
    }
}
