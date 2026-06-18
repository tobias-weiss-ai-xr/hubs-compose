import { test, expect } from "@playwright/test";

const RETICULUM_API = "http://localhost:4001/api/v1";

test.describe("PSE VR Integration", () => {
  test("API creates hub with chemistry data and returns pse_url", async ({ request }) => {
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

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.hub_id).toBeTruthy();
    expect(body.url).toBeTruthy();
  });

  test("API returns pse_url for hub with chemistry symbol", async ({ request }) => {
    const createRes = await request.post(`${RETICULUM_API}/hubs`, {
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
    expect(createRes.status()).toBe(201);
    const hub = await createRes.json();

    const showRes = await request.get(`${RETICULUM_API}/hubs/${hub.hub_id}`);
    expect(showRes.status()).toBe(200);
    const showBody = await showRes.json();

    const returnedHub = showBody.hubs[0];
    expect(returnedHub.pse_url).toBe("https://pse.chemie-lernen.org?element=Au");
    expect(returnedHub.user_data.chemistry.symbol).toBe("Au");
  });

  test("API returns null pse_url for hub without chemistry data", async ({ request }) => {
    const response = await request.post(`${RETICULUM_API}/hubs`, {
      data: {
        hub: {
          name: "E2E Test No Chemistry",
        },
      },
    });
    expect(response.status()).toBe(201);
    const hub = await response.json();

    const showRes = await request.get(`${RETICULUM_API}/hubs/${hub.hub_id}`);
    expect(showRes.status()).toBe(200);
    const showBody = await showRes.json();

    const returnedHub = showBody.hubs[0];
    expect(returnedHub.pse_url).toBeNull();
  });
});
