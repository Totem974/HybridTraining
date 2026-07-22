import { beforeEach, describe, expect, it } from "vitest";

import {
  renderProgram,
  type CycleResponseLike,
} from "../../../src/cycle/program";

const response: CycleResponseLike = {
  weeks: [
    {
      number: 1,
      sessions: Array.from({ length: 4 }, (_, index) => ({
        date: `2026-07-${String(20 + index).padStart(2, "0")}T00:00:00.000Z`,
        movementId: ["press", "deadlift", "bench", "squat"][index]!,
        blocks: [
          {
            role: "main_work",
            movementId: ["press", "deadlift", "bench", "squat"][index]!,
            sets: [
              {
                repetitions: { type: "fixed", count: 5 },
                plannedLoad: { centiUnits: 8250, unit: "kg" },
                platesPerSide: [{ centiUnits: 2000, unit: "kg" }],
              },
            ],
          },
        ],
      })),
    },
  ],
};

const labels = {
  week: "SEMAINE",
  session: "Séance",
  block: "Travail",
  dateLocale: "fr-FR",
  movementNames: {
    press: "Développé militaire",
    deadlift: "Soulevé de terre",
    bench: "Développé couché",
    squat: "Squat",
  },
  blockNames: { main_work: "Travail principal" },
};

describe("renderProgram", () => {
  let target: HTMLElement;

  beforeEach(() => {
    document.body.innerHTML = '<div id="program"></div>';
    target = document.querySelector<HTMLElement>("#program")!;
  });

  it("renders a semantic four-card week without technical identifiers", () => {
    renderProgram(target, response, { labels, showPlating: true });

    expect(target.querySelector("h3")?.textContent).toBe("SEMAINE 1");
    expect(target.querySelectorAll(".session-grid .session-card")).toHaveLength(4);
    expect(target.textContent).toContain("5 × 82,5 kg");
    expect(target.textContent).toContain("20 kg");
    expect(target.textContent).not.toContain("main_work");
    expect(target.textContent).not.toContain("{type:");
  });

  it("omits plate chips when plating display is disabled", () => {
    renderProgram(target, response, { labels, showPlating: false });
    expect(target.querySelectorAll(".plate-chip")).toHaveLength(0);
  });

  it("replaces previous output instead of appending stale snapshots", () => {
    renderProgram(target, response, { labels, showPlating: false });
    renderProgram(target, { weeks: [] }, { labels, showPlating: false });
    expect(target.childElementCount).toBe(0);
  });
});
