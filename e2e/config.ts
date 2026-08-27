/**
 * Central host/endpoint configuration for the E2E suite.
 *
 * Defaults target the live deployment (hubs.chemie-lernen.org). Override via
 * env vars to run against any environment:
 *   HUBS_BASE_URL    e.g. https://hubs.chemie-lernen.org   (client + API origin)
 *   DIALOG_URL       e.g. https://hubs.chemie-lernen.org:4443
 *
 * Note: the original suite hardcoded localhost:4001/4443/9090 for a dev
 * topology that is not present on the deployed host; the live deployment
 * fronts everything through traefik on 443/4443.
 */
const base = (process.env.HUBS_BASE_URL || "https://hubs.chemie-lernen.org").replace(/\/$/, "");
const dialogBase = (process.env.DIALOG_URL || `${base}:4443`).replace(/\/$/, "");

export const config = {
  /** Base origin for the client + REST API (traefik :443). */
  base,
  /** Dialog (mediasoup / protoo) origin for WebRTC signaling. */
  dialog: dialogBase,
  /** Reticulum REST API base. */
  api: `${base}/api/v1`,
  /** Health endpoint. */
  health: `${base}/health`,
  /** Phoenix WebSocket endpoint (SessionSocket). */
  socket: `${base}/socket/websocket?vsn=2.0.0`,
  /** Element symbol used by many tests (tests must not be order-dependent). */
  testSymbol: process.env.TEST_ELEMENT_SYMBOL || "H",
  /** Rate limit between hub creates (reticulum rate_limit pipeline). */
  rateLimitDelayMs: 1300,
};

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
export { delay };
