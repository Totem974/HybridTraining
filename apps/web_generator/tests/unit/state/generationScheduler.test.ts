import { afterEach, describe, expect, it, vi } from "vitest";
import { createCycleGenerationScheduler } from "../../../src/cycle/state/generationScheduler";

afterEach(() => {
  vi.useRealTimers();
});

describe("createCycleGenerationScheduler", () => {
  it("coalesces rapid edits into one generation of the latest request", async () => {
    vi.useFakeTimers();
    const generate = vi.fn((value: number) => value * 2);
    const onResult = vi.fn();
    const scheduler = createCycleGenerationScheduler({
      generate,
      fingerprint: String,
      onResult,
      debounceMs: 50,
    });

    scheduler.schedule(1);
    scheduler.schedule(2);
    scheduler.schedule(3);
    await vi.advanceTimersByTimeAsync(50);

    expect(generate).toHaveBeenCalledTimes(1);
    expect(generate).toHaveBeenCalledWith(3);
    expect(onResult).toHaveBeenCalledWith(6, 3);
  });

  it("does not regenerate an unchanged request", async () => {
    const generate = vi.fn((value: { id: string }) => value.id);
    const scheduler = createCycleGenerationScheduler({
      generate,
      fingerprint: (value) => value.id,
      onResult: vi.fn(),
    });

    await scheduler.flush({ id: "same" });
    await scheduler.flush({ id: "same" });

    expect(generate).toHaveBeenCalledTimes(1);
  });

  it("never publishes a stale asynchronous response", async () => {
    let finishFirst: ((value: string) => void) | undefined;
    const onResult = vi.fn();
    const scheduler = createCycleGenerationScheduler({
      generate: (value: string) => value === "first"
        ? new Promise<string>((resolve) => { finishFirst = resolve; })
        : Promise.resolve(value),
      fingerprint: String,
      onResult,
    });

    const first = scheduler.flush("first");
    await Promise.resolve();
    await scheduler.flush("latest");
    finishFirst?.("first");
    await first;

    expect(onResult).toHaveBeenCalledTimes(1);
    expect(onResult).toHaveBeenCalledWith("latest", "latest");
  });

  it("reports useful phases and only surfaces the current error", async () => {
    const phases: string[] = [];
    const onError = vi.fn();
    const scheduler = createCycleGenerationScheduler({
      generate: () => {
        throw new Error("INVALID_REQUEST");
      },
      fingerprint: String,
      onResult: vi.fn(),
      onError,
      onPhaseChange: (phase) => phases.push(phase),
    });

    await scheduler.flush("bad");

    expect(onError).toHaveBeenCalledWith(expect.any(Error), "bad");
    expect(phases).toEqual(["generating", "idle"]);
  });

  it("cancels a scheduled generation", async () => {
    vi.useFakeTimers();
    const generate = vi.fn();
    const scheduler = createCycleGenerationScheduler({
      generate,
      fingerprint: String,
      onResult: vi.fn(),
      debounceMs: 20,
    });

    scheduler.schedule("obsolete");
    scheduler.cancel();
    await vi.advanceTimersByTimeAsync(20);

    expect(generate).not.toHaveBeenCalled();
    expect(scheduler.phase).toBe("idle");
  });
});
