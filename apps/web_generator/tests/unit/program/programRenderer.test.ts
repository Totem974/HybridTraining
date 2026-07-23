import { beforeEach, describe, expect, it } from "vitest";

import {
  renderProgram,
  type CycleResponseLike,
} from "../../../src/cycle/program";

const response: CycleResponseLike = {
  weeks: [{
    number: 1,
    sessions: Array.from({ length: 4 }, (_, index) => ({
      date: `2026-07-${String(20 + index).padStart(2, "0")}T00:00:00.000Z`,
      movementId: ["press", "deadlift", "bench", "squat"][index]!,
      blocks: [{
        role: "main_work",
        movementId: ["press", "deadlift", "bench", "squat"][index]!,
        sets: [{
          repetitions: { type: "fixed", count: 5 },
          plannedLoad: { centiUnits: 8250, unit: "kg" },
          platesPerSide: [{ centiUnits: 2000, unit: "kg" }],
        }],
      }],
    })),
  }],
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
    expect(target.querySelector(".session-grid")?.getAttribute("role")).toBe("list");
    expect(target.querySelectorAll(".set-list > .set-row")).toHaveLength(4);
    expect(target.querySelector("time")?.getAttribute("datetime")).toBe(
      "2026-07-20T00:00:00.000Z",
    );
  });

  it("omits plate chips when plating display is disabled", () => {
    renderProgram(target, response, { labels, showPlating: false });
    expect(target.querySelectorAll(".plate-chip")).toHaveLength(0);
  });

  it("formats ranges and AMRAP without leaking repetition objects", () => {
    const varied: CycleResponseLike = {
      weeks: [{
        number: 2,
        sessions: [{
          movementId: "press",
          blocks: [{
            role: "main_work",
            sets: [
              { repetitions: { minimum: 3, maximum: 5 }, plannedLoad: null },
              {
                repetitions: { type: "amrap" },
                plannedLoad: { centiUnits: 10025, unit: "kg" },
              },
            ],
          }],
        }],
      }],
    };
    renderProgram(target, varied, { labels, showPlating: true });

    expect(target.textContent).toContain("3–5 × —");
    expect(target.textContent).toContain("AMRAP × 100,25 kg");
    expect(target.textContent).not.toContain("[object Object]");
  });

  it("uses neutral labels rather than unknown technical identifiers", () => {
    renderProgram(target, {
      weeks: [{
        number: 1,
        sessions: [{
          movementId: "private_movement_id",
          blocks: [{ role: "internal_role", sets: [] }],
        }],
      }],
    }, { labels, showPlating: false });

    expect(target.textContent).toContain("Séance");
    expect(target.textContent).toContain("Travail");
    expect(target.textContent).not.toContain("private_movement_id");
    expect(target.textContent).not.toContain("internal_role");
  });

  it("announces one plate group while keeping visual chips decorative", () => {
    renderProgram(target, response, { labels, showPlating: true });
    const group = target.querySelector(".set-row__plates");
    expect(group?.getAttribute("aria-label")).toBe("20 kg");
    expect(group?.querySelector(".plate-chip")?.getAttribute("aria-hidden"))
      .toBe("true");
  });

  it("replaces previous output instead of appending stale snapshots", () => {
    renderProgram(target, response, { labels, showPlating: false });
    renderProgram(target, { weeks: [] }, { labels, showPlating: false });
    expect(target.childElementCount).toBe(0);
  });
});
