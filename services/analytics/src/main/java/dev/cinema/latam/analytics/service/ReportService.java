package dev.cinema.latam.analytics.service;

import dev.cinema.latam.analytics.model.Report;
import dev.cinema.latam.analytics.model.ReportType;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class ReportService {

    private final Map<String, Report> reports = new ConcurrentHashMap<>();

    public ReportService() {
        generateReport(ReportType.DAILY_SALES);
        generateReport(ReportType.TOP_MOVIES);
    }

    public List<Report> getAllReports() {
        return new ArrayList<>(reports.values());
    }

    public Optional<Report> getReport(String id) {
        return Optional.ofNullable(reports.get(id));
    }

    public List<Report> getReportsByType(ReportType type) {
        return reports.values().stream()
                .filter(r -> r.type() == type)
                .toList();
    }

    public Report generateReport(ReportType type) {
        String id = UUID.randomUUID().toString();
        Map<String, Object> data = generateMockData(type);

        Report report = new Report(
                id,
                type,
                formatTitle(type),
                data,
                LocalDateTime.now()
        );

        reports.put(id, report);
        return report;
    }

    private Map<String, Object> generateMockData(ReportType type) {
        Random random = new Random();
        return switch (type) {
            case DAILY_SALES -> Map.of(
                    "totalSales", random.nextInt(5000) + 1000,
                    "ticketsSold", random.nextInt(500) + 100,
                    "averageTicketPrice", 12.50
            );
            case WEEKLY_SALES -> Map.of(
                    "totalSales", random.nextInt(30000) + 10000,
                    "ticketsSold", random.nextInt(3000) + 500,
                    "growthRate", random.nextDouble() * 10
            );
            case MONTHLY_SALES -> Map.of(
                    "totalSales", random.nextInt(100000) + 50000,
                    "ticketsSold", random.nextInt(10000) + 2000,
                    "topDay", "Saturday"
            );
            case TOP_MOVIES -> Map.of(
                    "movies", List.of(
                            Map.of("title", "Inception", "sales", 15000),
                            Map.of("title", "The Matrix", "sales", 12000),
                            Map.of("title", "Interstellar", "sales", 10000)
                    )
            );
            case OCCUPANCY_RATE -> Map.of(
                    "averageOccupancy", random.nextDouble() * 40 + 50,
                    "peakHours", List.of("19:00", "21:00"),
                    "lowestDay", "Tuesday"
            );
            case REVENUE_BY_CINEMA -> Map.of(
                    "cinemas", List.of(
                            Map.of("name", "Cinema Centro", "revenue", 45000),
                            Map.of("name", "Cinema Norte", "revenue", 38000),
                            Map.of("name", "Cinema Sur", "revenue", 32000)
                    )
            );
        };
    }

    private String formatTitle(ReportType type) {
        return type.name().replace("_", " ") + " Report";
    }
}
