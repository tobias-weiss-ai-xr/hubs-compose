# syntax=docker/dockerfile:1
#
# Optimized multi-stage build for the Hubs client (hubs.chemie-lernen.org).
#
# Stage 1 builds the webpack bundle (services/hubs -> dist/) with persistent
# BuildKit cache mounts so incremental CI builds on the legion runner are fast.
# Stage 2 is a slim runtime that serves the built dist via static-server.py
# (Python), including the SPA rewrite that maps room URLs to hub.html.
ARG NODE_VERSION=22

# ---------- Build the Hubs client (webpack) ----------
FROM --platform=linux/amd64 node:${NODE_VERSION} AS client-build
WORKDIR /src

# Install dependencies first so this layer is cached unless package files change.
COPY services/hubs/package.json services/hubs/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund

# Build sources. webpack.config.js uses cache: { type: "filesystem" } into
# node_modules/.cache/webpack; the BuildKit cache mount persists it across runs
# on the same runner, giving fast incremental rebuilds.
COPY services/hubs/ ./
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/src/node_modules/.cache/webpack \
    npm run build

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
