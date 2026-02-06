/**
 * Rule-bound intelligence layer.
 * Deterministic explanations only. No autonomous execution.
 * AI/intelligence cannot override: CPO status, risk blocks, workflow gates.
 */

/** Deterministic rule code – used for explanations (no free-form text). */
export type IntelligenceRuleCode =
  | 'INCOMPLETE_DOCUMENT'
  | 'INCOMPLETE_ROI_INPUTS'
  | 'INCOMPLETE_DUE_DILIGENCE'
  | 'INCONSISTENT_DOCUMENT_CPO'
  | 'INCONSISTENT_ROI_NEGATIVE_PROFIT'
  | 'SUGGEST_ADD_BREAK_EVEN_DATE'
  | 'SUGGEST_COMPLETE_DUE_DILIGENCE'
  | 'SUGGEST_LINK_DOCUMENTS'
  | 'VIOLATION_CPO_NOT_APPROVED'
  | 'VIOLATION_RISK_BLOCK_ACTIVE'
  | 'VIOLATION_WORKFLOW_BLOCK_ACTIVE';

export type FindingSeverity = 'info' | 'suggestion' | 'violation';

export interface IntelligenceFinding {
  code: IntelligenceRuleCode;
  severity: FindingSeverity;
  message: string;
  params?: Record<string, unknown>;
}

export interface IntelligenceResult {
  allowed: boolean;
  violations: IntelligenceFinding[];
  suggestions: IntelligenceFinding[];
  completeness: IntelligenceFinding[];
  inconsistencies: IntelligenceFinding[];
}

export const RULE_MESSAGES: Record<IntelligenceRuleCode, string> = {
  INCOMPLETE_DOCUMENT: 'Document is missing required fields for the current workflow.',
  INCOMPLETE_ROI_INPUTS: 'ROI inputs are incomplete; add acquisition price and expected resale value.',
  INCOMPLETE_DUE_DILIGENCE: 'Due diligence checklist has pending or risk items.',
  INCONSISTENT_DOCUMENT_CPO: 'Document status is APPROVED but CPO status is not VERDE.',
  INCONSISTENT_ROI_NEGATIVE_PROFIT: 'ROI net profit is negative; review inputs before proceeding.',
  SUGGEST_ADD_BREAK_EVEN_DATE: 'Add expected_resale_date to ROI for break-even date.',
  SUGGEST_COMPLETE_DUE_DILIGENCE: 'Complete due diligence to reduce risk and enable bidding.',
  SUGGEST_LINK_DOCUMENTS: 'Link relevant documents to the auction asset.',
  VIOLATION_CPO_NOT_APPROVED: 'Operation refused: CPO status must be VERDE (cannot be overridden).',
  VIOLATION_RISK_BLOCK_ACTIVE: 'Operation refused: risk block is active (cannot be overridden).',
  VIOLATION_WORKFLOW_BLOCK_ACTIVE: 'Operation refused: workflow gate blocked (cannot be overridden).',
};
