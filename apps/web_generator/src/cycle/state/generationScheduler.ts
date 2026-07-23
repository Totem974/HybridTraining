export type GenerationPhase = "idle" | "scheduled" | "generating";

export interface CycleGenerationSchedulerOptions<TInput, TResult> {
  readonly generate: (input: TInput) => TResult | Promise<TResult>;
  readonly fingerprint: (input: TInput) => string;
  readonly onResult: (result: TResult, input: TInput) => void;
  readonly onError?: (error: unknown, input: TInput) => void;
  readonly onPhaseChange?: (phase: GenerationPhase) => void;
  readonly debounceMs?: number;
}

export interface CycleGenerationScheduler<TInput> {
  readonly phase: GenerationPhase;
  schedule(input: TInput): void;
  flush(input?: TInput): Promise<void>;
  cancel(): void;
}

/**
 * Coalesces rapid editor updates and publishes only the newest generation.
 *
 * The scheduler is deliberately domain-agnostic: the engine remains responsible
 * for validation and generation, while the UI supplies an opaque request and its
 * canonical fingerprint.
 */
export function createCycleGenerationScheduler<TInput, TResult>(
  options: CycleGenerationSchedulerOptions<TInput, TResult>,
): CycleGenerationScheduler<TInput> {
  const delay = options.debounceMs ?? 80;
  let currentPhase: GenerationPhase = "idle";
  let timer: ReturnType<typeof setTimeout> | undefined;
  let pending: TInput | undefined;
  let revision = 0;
  let lastPublishedFingerprint: string | undefined;
  let inFlight: Promise<void> | undefined;

  function setPhase(next: GenerationPhase): void {
    if (currentPhase === next) return;
    currentPhase = next;
    options.onPhaseChange?.(next);
  }

  function clearTimer(): void {
    if (timer === undefined) return;
    clearTimeout(timer);
    timer = undefined;
  }

  async function run(input: TInput, runRevision: number): Promise<void> {
    const inputFingerprint = options.fingerprint(input);
    if (inputFingerprint === lastPublishedFingerprint) {
      if (runRevision === revision) setPhase("idle");
      return;
    }

    setPhase("generating");
    try {
      const result = await options.generate(input);
      if (runRevision !== revision) return;
      lastPublishedFingerprint = inputFingerprint;
      options.onResult(result, input);
    } catch (error) {
      if (runRevision === revision) options.onError?.(error, input);
    } finally {
      if (runRevision === revision) setPhase("idle");
    }
  }

  async function flush(input?: TInput): Promise<void> {
    if (input !== undefined) {
      pending = input;
      revision += 1;
    }
    clearTimer();
    const next = pending;
    if (next === undefined) {
      if (!inFlight) setPhase("idle");
      return;
    }
    pending = undefined;
    const runRevision = revision;
    const task = run(next, runRevision);
    inFlight = task;
    await task;
    if (inFlight === task) inFlight = undefined;
  }

  return {
    get phase() {
      return currentPhase;
    },
    schedule(input: TInput): void {
      pending = input;
      revision += 1;
      clearTimer();
      setPhase("scheduled");
      timer = setTimeout(() => {
        timer = undefined;
        void flush();
      }, delay);
    },
    flush,
    cancel(): void {
      revision += 1;
      pending = undefined;
      clearTimer();
      setPhase("idle");
    },
  };
}
