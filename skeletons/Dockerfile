# Dockerfile — security best practices
# Use a specific, minimal base image (never :latest)
FROM python:3.12-alpine AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/app/deps -r requirements.txt

# Multi-stage build — smaller attack surface
FROM python:3.12-alpine

# Don't run as root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=builder /app/deps /app/deps
COPY . .

ENV PYTHONPATH=/app/deps
# No COPY of secrets, keys, or .env files
# Use .dockerignore to exclude: .git, __pycache__, *.env, *.key

USER appuser
EXPOSE 8080
ENTRYPOINT ["python", "app.py"]
