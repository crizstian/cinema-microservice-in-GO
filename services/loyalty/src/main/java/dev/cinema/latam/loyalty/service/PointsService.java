package dev.cinema.latam.loyalty.service;

import dev.cinema.latam.loyalty.model.*;
import jakarta.enterprise.context.ApplicationScoped;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class PointsService {

    private final Map<String, LoyaltyAccount> accounts = new ConcurrentHashMap<>();
    private final Map<String, List<PointsTransaction>> transactions = new ConcurrentHashMap<>();

    public List<LoyaltyAccount> getAllAccounts() {
        return new ArrayList<>(accounts.values());
    }

    public Optional<LoyaltyAccount> getAccount(String userId) {
        return Optional.ofNullable(accounts.get(userId));
    }

    public LoyaltyAccount createAccount(String userId) {
        LoyaltyAccount account = new LoyaltyAccount(
                UUID.randomUUID().toString(),
                userId,
                0,
                0,
                LoyaltyTier.BRONZE,
                LocalDateTime.now(),
                LocalDateTime.now()
        );
        accounts.put(userId, account);
        transactions.put(userId, new ArrayList<>());
        return account;
    }

    public LoyaltyAccount earnPoints(String userId, int points, String description) {
        LoyaltyAccount account = accounts.computeIfAbsent(userId, this::createAccountInternal);

        int earnedPoints = (int) (points * account.tier().getMultiplier());
        LoyaltyAccount updated = account.withPoints(
                account.currentPoints() + earnedPoints,
                account.totalPoints() + earnedPoints
        );
        accounts.put(userId, updated);

        addTransaction(userId, TransactionType.EARN, earnedPoints, description);

        return updated;
    }

    public Optional<LoyaltyAccount> redeemPoints(String userId, int points, String description) {
        LoyaltyAccount account = accounts.get(userId);
        if (account == null || account.currentPoints() < points) {
            return Optional.empty();
        }

        LoyaltyAccount updated = account.withPoints(
                account.currentPoints() - points,
                account.totalPoints()
        );
        accounts.put(userId, updated);

        addTransaction(userId, TransactionType.REDEEM, -points, description);

        return Optional.of(updated);
    }

    public List<PointsTransaction> getTransactions(String userId) {
        return transactions.getOrDefault(userId, List.of());
    }

    private LoyaltyAccount createAccountInternal(String userId) {
        transactions.put(userId, new ArrayList<>());
        return new LoyaltyAccount(
                UUID.randomUUID().toString(),
                userId,
                0,
                0,
                LoyaltyTier.BRONZE,
                LocalDateTime.now(),
                LocalDateTime.now()
        );
    }

    private void addTransaction(String userId, TransactionType type, int points, String description) {
        PointsTransaction tx = new PointsTransaction(
                UUID.randomUUID().toString(),
                userId,
                type,
                points,
                description,
                LocalDateTime.now()
        );
        transactions.computeIfAbsent(userId, k -> new ArrayList<>()).add(tx);
    }
}
