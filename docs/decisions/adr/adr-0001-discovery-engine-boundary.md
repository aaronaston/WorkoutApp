# ADR-0001: Define discovery boundary between rules engine and LLM orchestration

## Status
Accepted

## Date
2026-02-19

## Context
`wa-3o4` introduces a rules-based recommendation engine that must stay explainable and tunable.
`wa-pac` introduces LLM configuration and privacy controls for optional free-form generation. Without
a clear boundary, LLM behavior could make recommendations opaque, bypass preference knobs, or leak
more context than intended.

## Decision
1) Rules-based ranking is the primary discovery path and always runs locally.
2) LLM orchestration is an optional adjunct path used for free-form generation and explicit
   regeneration requests; it does not replace deterministic ranking.
3) LLM outputs are treated as candidate workouts (`WorkoutSource.generated`) and do not silently
   mutate ranking scores for existing workouts.
4) `wa-pac` settings gate all LLM access:
   - LLM must be enabled and configured (API key in Keychain).
   - Only data categories explicitly allowed by settings may be included in prompts.
   - When disabled/unavailable/offline, discovery degrades to rules/search/browse only.
5) Discovery surfaces must label origin and rationale:
   - Rules-ranked items show rules-based recommendation reasons.
   - Generated items show prompt-fit rationale + policy-constrained context summary.
6) Generation uses a bounded refinement loop (max two LLM rounds):
   - Round 1: generate candidate from augmented prompt.
   - Retrieval: select relevant templates/rules via deterministic prefilter + similarity search.
   - Round 2: refine candidate using only retrieved relevant context.
   - Validate deterministically against hard rules; allow at most one repair retry.
7) LLM interactions use structured function-calling/JSON schema contracts so retrieval and
   validation stay deterministic and auditable.

## Alternatives
- Option A: Let LLM directly re-rank all discovery results
  - Pros: potentially better semantic matching
  - Cons: opaque ranking, weak determinism, harder preference explainability
- Option B: Keep rules and LLM paths separate with explicit boundaries (chosen)
  - Pros: explainable core behavior, predictable fallbacks, clearer privacy controls
  - Cons: two code paths and UI states to maintain

## Consequences
- `wa-3o4` owns deterministic ranking, score reasons, and preference weighting behavior.
- `wa-pac` owns credential/config state and prompt data-sharing policy.
- Integration point requires a typed prompt-context contract with per-category filtering.
- Testing must cover policy gating, disabled/offline degradation, and origin labeling.
- LLM orchestration adds deterministic retrieve/validate components and loop-stop conditions.
- Explainability must include refinement provenance (which constraints/templates influenced final output).

## References
- `readme.md`
- `docs/architecture/README.md`
- wa-3o4
- wa-pac
