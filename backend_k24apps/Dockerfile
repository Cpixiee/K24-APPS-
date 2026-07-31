# Stage 1: Build Go Backend Binary
FROM golang:1.22-alpine AS builder

WORKDIR /app

ENV GOTOOLCHAIN=auto

# Install certificates
RUN apk add --no-cache ca-certificates git

# Download Go dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source files
COPY . .

# Build static Linux binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o k24-backend main.go

# Stage 2: Final Runtime Image
FROM alpine:3.19

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata
ENV TZ=Asia/Jakarta

# Copy binary and migrations from builder
COPY --from=builder /app/k24-backend .
COPY --from=builder /app/migrations ./migrations

EXPOSE 8087

CMD ["./k24-backend"]
