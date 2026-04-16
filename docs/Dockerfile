# Dockerfile - Build Rust host in Linux/Windows containers

FROM rust:1.78-slim-bookworm AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy manifest
COPY host-windows/Cargo.toml host-windows/Cargo.lock ./

# Copy source
COPY host-windows/src ./src

# Build release binary
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /app/target/release/host-windows /app/host-windows

# Expose port
EXPOSE 9001

# Health check (optional)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD nc -zv localhost 9001 || exit 1

# Environment variables
ENV TABLET_MONITOR_LISTEN=0.0.0.0
ENV TABLET_MONITOR_FPS=60
ENV TABLET_MONITOR_BITRATE=3500

# Run
CMD ["/app/host-windows"]
