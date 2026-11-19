# Code audit

Audit date: 2026-11-19

## Scope

Static review of the three Python scripts and two Stata do-files, plus Python syntax compilation and a deliberately limited Stata smoke test. Full model estimation was stopped at the author's request because the multilevel integrations are computationally expensive.

## Corrections applied

1. Replaced script-local and ambiguous working-directory assumptions with repository-relative paths.
2. Renamed `M1 M2.do` to `M1_M2.do` and `M3 M4 M5.do` to `M3_M4_M5_M6.do`; the latter contains M6 as well as M3–M5.
3. Corrected the Stata input filename to `Regression_Analysis_Data.dta`.
4. Added `version 18.0`, explicit output directories and run logs to the Stata scripts.
5. Converted an uncommented line of equals signs in `M1_M2.do` into a valid Stata comment. The original line caused `r(199)`.
6. Corrected four files that had Excel content but `.csv` filenames; genuine UTF-8 CSV copies are now deposited.

## Python findings

- All three scripts pass `py_compile` syntax checking.
- No API key, token or credential is embedded. The scripts read `OPENAI_API_KEY` from the environment.
- The prompts, model identifiers and reasoning settings are embedded in the scripts.
- The default input/output paths now resolve within the repository.
- Runtime reproduction of stages 1–2 remains blocked until the 1,076 `policy_texts/*.json` files or an equivalent documented retrieval route are supplied.
- Exact LLM outputs may vary with service and model changes; depositing the exact derived results is therefore necessary and has been planned.

## Stata findings

- The analysis dataset has 103 complete city-level observations and 13 variables. The do-files assert 103 cities and 27 province-level units.
- A limited smoke test completed M1 and reached M2's adaptive-quadrature estimation before being stopped. No full M2–M6 verification is claimed.
- M5 is enclosed in `if 0` and is intentionally represented as non-estimable because of structural separation. This is not a coding accident, but it must be described as a failed robustness specification rather than as an estimated model.
- M3 uses cluster-robust inference with only 27 clusters. The script discloses this limitation; reviewers may still request a small-sample cluster correction or wild-cluster-bootstrap sensitivity analysis.
- Reported stars and P values are unadjusted across many outcome-specific effects. The scripts appropriately emphasize joint tests, effect sizes and uncertainty, but the manuscript must distinguish confirmatory from exploratory comparisons.
- All models are cross-sectional association models. The supplied code itself warns against causal interpretation.

## Submission-critical gaps

- **P0:** No code was supplied for converting the completed LLM workbook into the processed result, figure, pattern-classification and regression files.
- **P0:** The source policy-text access route is unresolved.
- **P1:** Definitions and construction rules for `Weight`, `NAI`, `PTR`, `NTR` and Patterns 1–4 are incomplete in the repository documentation.
- **P1:** Sources, years, units and transformations for GDP per capita and carbon-emission intensity require documentation.
- **P1:** Data and code licences, complete creator lists and ORCIDs remain to be confirmed.

