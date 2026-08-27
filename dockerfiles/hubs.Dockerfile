# syntax=docker/dockerfile:1
#
# Optimized multi-stage build for the Hubs client (hubs.chemie-lernen.org).
#
# - deps:         install npm dependencies (cached layer)
# - client-build: webpack build of services/hubs -> dist/ (BuildKit cache mounts
#                 make incremental CI builds on the legion runner fast)
# - storybook:    dev-only stage with node_modules for the Storybook server
# - runtime:      slim runtime serving dist/ via static-server.py (incl. the
#                 room-URL -> hub.html SPA rewrite). Fully baked, no host bind-mount.
ARG NODE_VERSION=22

# ---------- Dependencies (cached unless package files change) ----------
FROM --platform=linux/amd64 node:${NODE_VERSION} AS deps
WORKDIR /src
COPY services/hubs/package.json services/hubs/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund

# ---------- Build the Hubs client (webpack) ----------
FROM deps AS client-build
COPY services/hubs/ ./
# webpack.config.js uses cache: { type: "filesystem" } into node_modules/.cache/webpack;
# the BuildKit cache mount persists it across runs on the same runner.
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/src/node_modules/.cache/webpack \
    npm run build

# ---------- Dev-only: Storybook server (keeps node_modules + source) ----------
FROM deps AS storybook
COPY services/hubs/ ./
EXPOSE 6006
CMD ["npm", "run", "storybook", "--", "--no-open"]

# ---------- Runtime: static file server ----------
FROM --platform=linux/amd64 node:${NODE_VERSION}-slim AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /code
COPY --from=client-build /src/dist ./dist
COPY services/hubs/static-server.py ./static-server.py

ENV HUBS_DIST=/code/dist
EXPOSE 8080
CMD ["python3", "/code/static-server.py"]
