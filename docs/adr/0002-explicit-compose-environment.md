# ADR 0002: load local settings explicitly

- Status: Accepted
- Date: 2026-10-29

## Why this decision was needed

Compose commands can run from different folders. If we leave environment-file
selection implicit, people may load the wrong settings. Database passwords must
not be silently guessed or committed.

## Decision

Run `docker compose --env-file .env -f docker/docker-compose.yml` from the
repository root. Leave the example password blank. Reject missing or blank
required values. The backend also reports a clear missing `DATABASE_URL` error.

## What this means

Create a private `.env` before starting. Use matching database credentials.
Terminal environment variables can still override the file, so clear conflicts.
This small change is easier to understand than adding a configuration framework.
