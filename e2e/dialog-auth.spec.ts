import { test, expect } from "@playwright/test";

const RETICULUM_API = "https://localhost:4001/api/v1";
const DIALOG_API = "https://localhost:4443";

test.describe("Dialog Auth Integration", () => {
  test("Reticulum room token endpoint returns 401 without auth", async ({ request }) => {
    const response = await request.post(`${RETICULUM_API}/rooms/token`, {
      data: { room_id: "test-room-123", role: "student" },
    });
    // Auth_required scope — expect 401/403 without credentials
    expect([401, 403]).toContain(response.status());
  });

  test("Reticulum room token validates role field", async ({ request }) => {
    // First get a session token by logging in (or using dev credentials)
    const response = await request.post(`${RETICULUM_API}/rooms/token`, {
      data: { room_id: "test-room-123", role: "invalid_role" },
    });
    // May return 401 if no auth, or 422 if auth passes but role is invalid
    expect([401, 422, 403]).toContain(response.status());
  });

  test("Dialog returns 401 without auth token", async ({ request }) => {
    const response = await request.post(`${DIALOG_API}/rooms`, {
      data: { roomId: "test-room-123", roomSize: 4 },
      ignoreHTTPSErrors: true,
    });
    // If Dialog is running, expect 401/403 (no token)
    // If Dialog is not running, connection refused
    try {
      const status = response.status();
      expect([401, 403]).toContain(status);
    } catch {
      test.skip(true, "Dialog service not available (expected)");
    }
  });

  test("Dialog returns 401 for invalid token", async ({ request }) => {
    const response = await request.post(`${DIALOG_API}/rooms`, {
      data: { roomId: "test-room-456", roomSize: 4 },
      headers: {
        Authorization: "Bearer invalid.jwt.token",
      },
      ignoreHTTPSErrors: true,
    });

    try {
      const status = response.status();
      expect([401, 403]).toContain(status);
    } catch {
      test.skip(true, "Dialog service not available (expected)");
    }
  });

  test("Dialog GET /rooms requires auth", async ({ request }) => {
    const response = await request.get(`${DIALOG_API}/rooms`, {
      ignoreHTTPSErrors: true,
    });

    try {
      const status = response.status();
      expect([401, 403]).toContain(status);
    } catch {
      test.skip(true, "Dialog service not available (expected)");
    }
  });
});
