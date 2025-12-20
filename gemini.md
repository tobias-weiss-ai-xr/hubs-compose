# Hubs Compose Services Documentation

This document provides details on the services involved in the Hubs Compose stack and how they are orchestrated.

## Service Orchestration Methods

There are two primary ways to run the Hubs Compose stack:

1.  **Manual / Development Mode (`bin/up`)**:
    *   **Configuration**: Uses `docker-compose.yml`.
    *   **Synchronization**: Uses `mutagen-compose` for fast two-way file synchronization between the host and containers.
    *   **Use Case**: Ideal for active development where you are modifying code in the `services/` directory.
    *   **Command**: `bin/up` (starts) and `bin/down` (stops).

2.  **System Service Mode (`hubs-compose.service`)**:
    *   **Configuration**: Uses `docker-compose.test.yml`.
    *   **Synchronization**: Does NOT use Mutagen. Mounts volumes directly or uses standard Docker volumes.
    *   **Use Case**: Continuous integration, testing, or running as a background service on a server.
    *   **Command**: `systemctl start hubs-compose` (starts) and `systemctl stop hubs-compose` (stops).
    *   **Service File**: Located at `hubs-compose.service`.

## HAProxy and SSL Configuration

The stack uses `haproxy` for SSL termination and routing.

*   **Configuration File**: `haproxy/haproxy.cfg`.
*   **Certificates**: Managed by Certbot within the `haproxy` container (`ghcr.io/tomdess/docker-haproxy-certbot`).
*   **Environment Variables**: The `docker-compose.test.yml` file defines which domains to request certificates for (e.g., `CERT1`, `CERT2`, etc.).

### Troubleshooting 502 Bad Gateway

A 502 Bad Gateway error on `chemie-lernen.org` (or other sites) typically indicates that HAProxy cannot connect to the backend service.

**Common Causes & Fixes:**

1.  **Backend Hostname Mismatch**:
    *   Ensure the `server` directive in `haproxy/haproxy.cfg` matches the service name in the docker-compose file.
    *   *Fix*: Updated `haproxy.cfg` to point `hugo-graphwiz-ai` backend to the `hugo-graphwiz-ai` service (was incorrectly `hugo-graphwiz`).

2.  **HAProxy Container Crashing**:
    *   The `docker-haproxy-certbot` container may exit if initial certificate validation fails for *any* configured domain.
    *   *Symptom*: `docker ps` shows `haproxy` as "Exited". Logs show Acme challenge failures (404/Unauthorized).
    *   *Fix*: Temporarily remove failing domains (e.g., `tobias-weiss.org` if DNS is not pointing to the server) from the `CERTx` environment variables in `docker-compose.test.yml` to allow the container to start and serve the working domains.

## Service Descriptions

The following services are part of the Hubs Compose stack:

*   **`haproxy`**: Reverse proxy and SSL termination. Routes traffic to backends based on Host headers and paths.
*   **`rsyslog`**: Centralized logging for HAProxy and other services.
*   **`db`**: PostgreSQL database used by Reticulum to store Hubs data (users, rooms, scenes, etc.).
*   **`dialog`**: Signaling server using Mediasoup for WebRTC communication.
*   **`hubs-client`**: The main Hubs React-based web application.
*   **`hubs-admin`**: The administrative interface for managing the Hubs instance.
*   **`hubs-storybook`**: UI component documentation and testing environment for Hubs.
*   **`postgrest`**: Provides a RESTful API directly over the PostgreSQL database.
*   **`reticulum`**: The core Elixir/Phoenix backend service that orchestrates Hubs.
*   **`spoke`**: The 3D scene editor for creating Hubs environments.
*   **`hugo-chemie-lernen-org`**: Static site generator (Hugo) serving `chemie-lernen.org`.
*   **`hugo-graphwiz-ai`**: Static site generator (Hugo) serving `graphwiz.ai`.
*   **`hugo-tobias-weiss-org`**: Static site generator (Hugo) serving `next.tobias-weiss.org`.
*   **`xwiki`**: Collaborative wiki platform.
*   **`xwiki-db`**: Dedicated PostgreSQL database for XWiki.
*   **`playwright-tests`**: Automated end-to-end tests using the Playwright framework.

## SSL Graceful Fallback

To prevent the `haproxy` container from crashing when a domain's DNS is not yet pointing to the server, a custom `certs.sh` script is used.

*   **Mechanism**: The script attempts to obtain a Let's Encrypt certificate via Certbot for each configured domain (`CERT1`, `CERT2`, etc.).
*   **Fallback**: If Certbot fails (e.g., due to challenge failure), the script automatically generates a **self-signed certificate** for that domain.
*   **Outcome**: HAProxy starts successfully regardless of individual certificate validation failures, ensuring that working domains remain accessible while others wait for DNS propagation.

## Reticulum Service

*   **Dockerfile**: `services/reticulum/TurkeyDockerfile`.
*   **Build Issues**: Ensure the Dockerfile contains the `dev` stage if referenced by `docker-compose.yml`. Use the standard multi-stage build definition for Elixir/Phoenix apps.

## Scripts

*   `bin/up`: Starts the stack using Mutagen. Fixed to correctly detect OS (Linux/macOS) for IP address resolution.
*   `bin/down`: Stops the stack. Fixed to correctly detect OS.
