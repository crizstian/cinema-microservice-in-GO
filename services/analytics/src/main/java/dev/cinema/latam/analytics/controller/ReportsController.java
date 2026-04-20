package dev.cinema.latam.analytics.controller;

import dev.cinema.latam.analytics.model.Report;
import dev.cinema.latam.analytics.model.ReportType;
import dev.cinema.latam.analytics.service.ReportService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/reports")
public class ReportsController {

    private final ReportService reportService;

    public ReportsController(ReportService reportService) {
        this.reportService = reportService;
    }

    @GetMapping
    public ResponseEntity<List<Report>> getAllReports() {
        return ResponseEntity.ok(reportService.getAllReports());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Report> getReport(@PathVariable String id) {
        return reportService.getReport(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/type/{type}")
    public ResponseEntity<List<Report>> getReportsByType(@PathVariable ReportType type) {
        return ResponseEntity.ok(reportService.getReportsByType(type));
    }

    @PostMapping("/generate")
    public ResponseEntity<Report> generateReport(@RequestParam ReportType type) {
        return ResponseEntity.ok(reportService.generateReport(type));
    }
}
