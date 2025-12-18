# syntax=docker/dockerfile:1
ARG NODE_VERSION=16.16

FROM --platform=linux/amd64 node:${NODE_VERSION}
WORKDIR /code
COPY files/conditional-npm-ci /usr/local/bin/conditional-npm-ci
RUN chmod +x /usr/local/bin/conditional-npm-ci
# No pre-install here as we bind mount /code, but we need to ensure npm ci runs if modules are missing
