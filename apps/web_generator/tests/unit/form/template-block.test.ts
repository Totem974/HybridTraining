// @vitest-environment jsdom
import { describe, expect, it, vi } from "vitest";

import { renderTemplateBlock } from "../../../src/cycle/form/blocks/template";
import type { CycleBlockRenderContext } from "../../../src/cycle/form/types";

function context(): CycleBlockRenderContext {
  return {
    locale: "en",
    schemaId: "editor",
    dispatch: vi.fn(),
    values: {
      generationId: "classic",
      templateId: "classic",
      variantId: "four-day",
    },
    renderDefault: () => document.createDocumentFragment(),
    fields: [
      {
        id: "generation",
        path: "generationId",
        region: "template",
        kind: "choice",
        label: "Generation",
        value: "classic",
        choices: [
          { value: "classic", label: "Classic" },
          { value: "beyond", label: "Beyond" },
        ],
      },
      {
        id: "template",
        path: "templateId",
        region: "template",
        kind: "choice",
        label: "Template",
        value: "classic",
        choices: [{ value: "classic", label: "5/3/1" }],
      },
      {
        id: "variant",
        path: "variantId",
        region: "template",
        kind: "choice",
        label: "Variant",
        value: "four-day",
        choices: [
          { value: "four-day", label: "Four days" },
          { value: "two-day", label: "Two days" },
        ],
      },
      {
        id: "warm-up",
        path: "options.warmUp",
        region: "template",
        kind: "boolean",
        label: "Warm-up",
        value: true,
      },
      {
        id: "phase",
        path: "options.fullBody.phase",
        region: "template",
        kind: "choice",
        label: "Phase",
        value: "phase_one",
        choices: [{ value: "phase_one", label: "Phase one" }],
      },
    ],
  };
}

describe("renderTemplateBlock", () => {
  it("renders catalogue choices as separated value rows with chevrons", () => {
    const host = document.createElement("div");
    host.append(renderTemplateBlock(context()));
    expect(
      host.querySelectorAll(
        ".template-selection-rows > .template-selection-row",
      ),
    ).toHaveLength(3);
    expect(
      host.querySelectorAll(
        ".template-selection-rows .template-selection-chevron",
      ),
    ).toHaveLength(3);
    expect(host.querySelector(".template-selection-rows")?.getAttribute("role"))
      .toBe("group");
    expect(
      host.querySelector(".template-selection-chevron")?.getAttribute("aria-hidden"),
    ).toBe("true");
    expect(host.querySelector(".template-selection-chevron")?.textContent).toBe("›");
    expect(host.querySelector("[data-testid=generation] option")?.textContent)
      .toBe("Classic");
    expect(host.querySelector("[data-testid=variant] option")?.textContent).toBe(
      "Four days",
    );
  });

  it("places schema-declared dynamic options below the selection rows", () => {
    const host = document.createElement("div");
    host.append(renderTemplateBlock(context()));
    const rows = host.querySelector(".template-selection-rows");
    const options = host.querySelector(".template-dynamic-options");
    const group = rows?.nextElementSibling;
    expect(group?.classList.contains("template-options-group")).toBe(true);
    expect(group?.querySelector(".template-options-heading")?.textContent)
      .toBe("Template options");
    expect(group?.getAttribute("aria-labelledby")).toBe(
      group?.querySelector(".template-options-heading")?.id,
    );
    expect(group?.querySelector(".template-dynamic-options")).toBe(options);
    expect(group?.querySelector("input[type=checkbox]")).not.toBeNull();
    expect(group?.querySelector("[data-testid=phase]")).not.toBeNull();
  });

  it("dispatches the selected schema value without template rules", () => {
    const renderContext = context();
    const host = document.createElement("div");
    host.append(renderTemplateBlock(renderContext));
    const select = host.querySelector("[data-testid=variant]") as HTMLSelectElement;
    select.value = JSON.stringify("two-day");
    select.dispatchEvent(new Event("change"));
    expect(renderContext.dispatch).toHaveBeenCalledWith({
      type: "cycle.field.changed",
      schemaId: "editor",
      fieldId: "variant",
      path: "variantId",
      value: "two-day",
    });
  });

  it("localizes accessible group labels without changing schema choices", () => {
    const renderContext = { ...context(), locale: "fr" };
    const host = document.createElement("div");
    host.append(renderTemplateBlock(renderContext));

    expect(
      host.querySelector(".template-selection-rows")?.getAttribute("aria-label"),
    ).toBe("Sélection du programme");
    expect(host.querySelector(".template-options-heading")?.textContent)
      .toBe("Options du modèle");
    expect(host.querySelector("[data-testid=generation] option")?.textContent)
      .toBe("Classic");
  });
});
