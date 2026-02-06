# Rule-bound intelligence layer

- **Validate** data completeness, **detect** inconsistencies, **suggest** improvements (non-destructive), **refuse** operations when rules are violated.
- **AI cannot override:** CPO status, risk blocks, workflow gates. The layer only reads these and may add violations; it never writes or bypasses them.
- **Deterministic explanations:** all findings use fixed rule codes and messages (see `types/intelligence.ts`).
- **No autonomous execution:** the layer returns validation result and suggestions; it does not apply changes.
- **All suggestions logged:** every suggestion and every refusal is audited via `intelligence.suggestion` and `intelligence.refusal`.

## Endpoints

- `POST /intelligence/validate` – run validation; returns `allowed`, `violations`, `suggestions`, `completeness`, `inconsistencies`.
- `POST /intelligence/validate-and-enforce` – same but returns 403 when `allowed` is false.
- `GET /intelligence/suggestions/:resourceType/:resourceId` – read-only suggestions/completeness/inconsistencies.

## Permissions

- `intelligence:read` – required for all intelligence endpoints.

## Integration

- **Place bid:** auction route calls `validate(..., operation: 'place_bid')` before creating a bid; refusal is logged and 403 returned.
- **Generate document / other flows:** call `validate(..., operation: 'generate_document' | 'general')` before the operation and refuse when `!result.allowed`.

## Rule codes (deterministic)

- Completeness: `INCOMPLETE_DOCUMENT`, `INCOMPLETE_ROI_INPUTS`, `INCOMPLETE_DUE_DILIGENCE`
- Inconsistencies: `INCONSISTENT_DOCUMENT_CPO`, `INCONSISTENT_ROI_NEGATIVE_PROFIT`
- Suggestions: `SUGGEST_ADD_BREAK_EVEN_DATE`, `SUGGEST_COMPLETE_DUE_DILIGENCE`, `SUGGEST_LINK_DOCUMENTS`
- Violations (refuse): `VIOLATION_CPO_NOT_APPROVED`, `VIOLATION_RISK_BLOCK_ACTIVE`, `VIOLATION_WORKFLOW_BLOCK_ACTIVE`
