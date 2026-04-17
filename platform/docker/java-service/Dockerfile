# ============================================================
# Common Dockerfile for all Java microservices
# Context: project root
# Usage: docker build -f platform/docker/java-service/Dockerfile \
#        --build-arg SERVICE_NAME=analytics --build-arg BUILD_TOOL=maven .
# ============================================================

ARG JAVA_VERSION=21

# ============================================================
# Stage 1: Builder
# ============================================================
FROM eclipse-temurin:${JAVA_VERSION}-jdk-alpine AS builder

ARG SERVICE_NAME
ARG BUILD_TOOL=maven
ARG VERSION=0.0.0-dev

WORKDIR /build

# Install build tools
RUN apk add --no-cache maven

# For Gradle projects, use wrapper from project
COPY services/${SERVICE_NAME}/ ./

# Build based on tool type
RUN if [ "$BUILD_TOOL" = "gradle" ]; then \
      chmod +x ./gradlew && \
      ./gradlew build -x test --no-daemon; \
    else \
      mvn package -DskipTests -Drevision=${VERSION} -q; \
    fi

# ============================================================
# Stage 2: Runtime (Final Image)
# ============================================================
FROM eclipse-temurin:${JAVA_VERSION}-jre-alpine

ARG SERVICE_NAME
ARG SERVICE_PORT=8000
ARG BUILD_TOOL=maven
ARG VERSION=0.0.0-dev
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

# OCI Standard Labels
LABEL org.opencontainers.image.title="cinema-${SERVICE_NAME}"
LABEL org.opencontainers.image.description="Cinema ${SERVICE_NAME} microservice (Java)"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${COMMIT_SHA}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.source="https://github.com/crizstian/cinema-microservices"
LABEL org.opencontainers.image.vendor="Cinema App"
LABEL org.opencontainers.image.authors="Cristian Ramirez <cristian@cinema.dev>"

# Install wget for healthcheck
RUN apk add --no-cache wget

# Create non-root user for security
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

WORKDIR /app

# Copy JAR from builder (handle both Maven and Gradle output paths)
COPY --from=builder /build/target/*.jar /tmp/maven-jar/ 2>/dev/null || true
COPY --from=builder /build/build/libs/*.jar /tmp/gradle-jar/ 2>/dev/null || true

RUN if [ "$BUILD_TOOL" = "gradle" ]; then \
      cp /tmp/gradle-jar/*.jar /app/service.jar 2>/dev/null || \
      cp /tmp/gradle-jar/*-all.jar /app/service.jar 2>/dev/null; \
    else \
      cp /tmp/maven-jar/*.jar /app/service.jar; \
    fi && \
    rm -rf /tmp/maven-jar /tmp/gradle-jar

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE ${SERVICE_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:${SERVICE_PORT}/health || exit 1

# JVM optimizations for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Run application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/service.jar"]
