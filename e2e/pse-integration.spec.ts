import { test, expect } from "@playwright/test";

const RETICULUM_API = "https://localhost:4001/api/v1";

const RATE_LIMIT_DELAY_MS = 1300;
const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

test.describe("PSE VR Integration", () => {
  test("API creates hub with chemistry data and returns hub_id", async ({ request }) => {
    const response = await request.post(`${RETICULUM_API}/hubs`, {
      data: {
        hub: {
          name: "E2E Test Natrium Room",
          user_data: {
            chemistry: {
              symbol: "Na",
            },
          },
        },
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.hub_id).toBeTruthy();
    expect(body.url).toBeTruthy();
    expect(body.status).toBe("ok");
  });

  test("API returns hub with chemistry data and confirm create response", async ({ request }) => {
    await delay(RATE_LIMIT_DELAY_MS);

    const response = await request.post(`${RETICULUM_API}/hubs`, {
      data: {
        hub: {
          name: "E2E Test Gold Room",
          user_data: {
            chemistry: {
              symbol: "Au",
            },
          },
        },
      },
    });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.hub_id).toBeTruthy();
    expect(body.url).toBeTruthy();
    expect(body.status).toBe("ok");
  });

  test("API creates hub without chemistry data", async ({ request }) => {
    await delay(RATE_LIMIT_DELAY_MS);

    const response = await request.post(`${RETICULUM_API}/hubs`, {
      data: {
        hub: {
          name: "E2E Test No Chemistry",
        },
      },
    });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.hub_id).toBeTruthy();
    expect(body.status).toBe("ok");
  });
});
