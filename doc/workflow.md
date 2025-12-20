# Development Workflow: Targeted Restarts

Date: 2025-12-18

## Strategy
To optimize development speed, we transition from restarting the entire `hubs-compose` systemd service to using targeted `docker-compose` commands. This allows for updating specific components (e.g., just the Hugo sites) without affecting the entire stack (e.g., keeping the database and reticulum running).

## Usage
When making changes to a specific area, use the corresponding compose file:

- **Hugo Sites**: `docker-compose -f docker-compose.hugo.yml up -d --build`
- **HAProxy**: `docker-compose -f docker-compose.haproxy.yml up -d`
- **Hubs Core**: `docker-compose -f docker-compose.hubs.yml up -d --build`

## Benefits
- Reduced downtime for unrelated services.
- Faster feedback loop during frontend development.
- Lower resource consumption during rebuilds.
