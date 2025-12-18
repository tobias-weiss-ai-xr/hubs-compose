# Separation of Concerns: Docker Compose Restructuring

Date: 2025-12-18

## Objective
To improve maintainability and service isolation, the monolithic `docker-compose.test.yml` is being separated into three distinct configuration files:

1.  **`docker-compose.haproxy.yml`**: Infrastructure and routing (HAProxy, Rsyslog).
2.  **`docker-compose.hugo.yml`**: Static content sites (Chemie Lernen, GraphWiz, Tobias Weiss).
3.  **`docker-compose.hubs.yml`**: The core Hubs stack (Reticulum, Client, Spoke, etc.) and the XWiki integration.

## Network Architecture
All services will continue to share the `mozilla-hubs` network to ensure that HAProxy can reach the backends and Hubs services can communicate with each other.

## Impact on Systemd
The `hubs-compose.service` will be updated to point to these multiple files using the `-f` flag.

## Implementation Details
- **`docker-compose.haproxy.yml`**: Contains `haproxy` and `rsyslog`. Defines the `mozilla-hubs` network.
- **`docker-compose.hugo.yml`**: Contains all static site containers.
- **`docker-compose.hubs.yml`**: Contains the full Mozilla Hubs stack and XWiki.
- **Redundancy Fix**: The homepage description was updated to "interaktive Lernräume für Chemie (in VR)" to avoid redundant "VR" mentions.
- **Dependency Resolution**: Node modules for `spoke`, `hubs-client`, and `hubs-admin` were installed via a temporary container to ensure all binaries (like `cross-env`) are available.

## Verification
- Automated tests via `test-hugo-sites.sh` passed all 27 checks.
- Services successfully orchestrated via `systemctl restart hubs-compose`.
- Database migrations for `ret_dev` completed successfully after a clean reset.

