export type CycleFormRegion =
  | "weight"
  | "template"
  | "additional-options"
  | "plating"
  | "scheduling"
  | "output";

export type LocalizedText = string | Readonly<Record<string, string>>;
export type JsonPrimitive = string | number | boolean | null;
export type JsonValue =
  | JsonPrimitive
  | readonly JsonValue[]
  | { readonly [key: string]: JsonValue };

export interface CycleEditorChoice {
  readonly value: JsonPrimitive;
  readonly label: LocalizedText;
  readonly disabled?: boolean;
}

export interface CycleEditorCondition {
  readonly path: string;
  readonly operator:
    | "equals"
    | "notEquals"
    | "present"
    | "in"
    | "greaterThanOrEqual"
    | "lessThanOrEqual";
  readonly value?: JsonValue;
}

export interface CycleEditorField {
  readonly id: string;
  readonly path: string;
  readonly region: CycleFormRegion;
  readonly group?: string;
  readonly groupLabel?: LocalizedText;
  readonly label: LocalizedText;
  readonly description?: LocalizedText;
  readonly kind:
    | "boolean"
    | "choice"
    | "segmented"
    | "integer"
    | "number"
    | "percentage"
    | "weight"
    | "text"
    | "date"
    | "token-order"
    | "plate-counter"
    | "action";
  readonly value: JsonValue;
  readonly choices?: readonly CycleEditorChoice[];
  readonly minimum?: number;
  readonly maximum?: number;
  readonly step?: number;
  readonly suffix?: LocalizedText;
  readonly required?: boolean;
  readonly readOnly?: boolean;
  readonly visibleWhen?: readonly CycleEditorCondition[];
  readonly enabledWhen?: readonly CycleEditorCondition[];
  readonly metadata?: Readonly<Record<string, JsonValue>>;
  readonly action?: string;
  readonly decreaseLabel?: LocalizedText;
  readonly increaseLabel?: LocalizedText;
}

/** Public browser representation returned by getCycleEditorSchema. */
export interface CycleEditorSchema {
  readonly apiVersion: string;
  readonly engineVersion: string;
  readonly catalogVersion: string;
  readonly catalogHash: string;
  readonly schemaVersion: string;
  readonly id: string;
  readonly fields: readonly CycleEditorField[];
  readonly labels?: Readonly<Record<string, LocalizedText>>;
}

export interface CycleFormIntent {
  readonly type: "cycle.field.changed" | "cycle.action.requested";
  readonly schemaId: string;
  readonly fieldId?: string;
  readonly path?: string;
  readonly value?: JsonValue;
  readonly action?: string;
}

export type CycleFormIntentHandler = (
  intent: CycleFormIntent,
) => void | Promise<void>;

export interface RenderCycleFormOptions {
  readonly schema: CycleEditorSchema;
  readonly root: ParentNode;
  readonly dispatch: CycleFormIntentHandler;
  readonly locale?: string;
}
