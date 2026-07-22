import type {
  CycleEditorSchema as ContractCycleEditorSchema,
  CycleEditorSchemaChoice as ContractCycleEditorChoice,
  CycleEditorSchemaCondition as ContractCycleEditorCondition,
  CycleEditorSchemaField as ContractCycleEditorField,
  CycleEditorSchemaLocalizedText as ContractLocalizedText,
} from "../../../../../contracts/v1/generated/contracts";

export type CycleEditorSchema = ContractCycleEditorSchema;
export type CycleEditorChoice = ContractCycleEditorChoice;
export type CycleEditorCondition = ContractCycleEditorCondition;
export type CycleEditorField = ContractCycleEditorField;
export type LocalizedText = ContractLocalizedText;
export type CycleFormRegion = ContractCycleEditorField["region"];
export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = unknown;

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
