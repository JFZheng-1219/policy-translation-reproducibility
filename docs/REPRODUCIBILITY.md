# Reproducibility instructions

## Software environment

- Python 3 with the pinned packages in `requirements.txt`
- Stata/MP 18; both do-files declare `version 18.0`

## Python LLM pipeline

From the repository root, after installing the Python dependencies and setting the `OPENAI_API_KEY` environment variable, run:

```text
python code/python/step1.py
python code/python/step1.py --continue
python code/python/step2.py
python code/python/step3.py --preflight-only
python code/python/step3.py
```

Pipeline mapping:

1. `step1.py` reads `data/source/Policy_data_cleaning_EN.xlsx`, reads the policy texts referenced by `Textual location`, and writes `outputs/llm/Results_step1_EN.xlsx`.
2. `step2.py` reads the stage-1 workbook and writes `outputs/llm/Results_step2_EN.xlsx`.
3. `step3.py` reads the stage-2 workbook and writes `outputs/llm/Results_step3_EN.xlsx`.

The scripts read the API key only from the environment and do not store or print it. The prompts, model identifiers and reasoning-effort settings are recorded directly in the scripts. Hosted-model access, behaviour and outputs can change; the exact derived results used in the paper are therefore deposited separately.

## Stata analyses

Set the Stata working directory to the repository root and run:

```stata
do code/stata/M1_M2.do
do code/stata/M3_M4_M5_M6.do
```

The do-files read `data/analysis/Regression_Analysis_Data.dta` and write tables and diagnostics to `outputs/stata/`.

The analytical unit is the city. The common main-analysis sample contains 103 cities nested within 27 province-level units. M3 uses 27 province-level clusters, so inference is subject to finite-cluster uncertainty. M5 is intentionally reported as non-estimable under the supplied three-category provincial-pattern construction because of structural separation. The scripts report unadjusted two-sided P values and warn against selecting isolated significance stars in place of joint tests, effect sizes and uncertainty.

## Missing transformation stage

No supplied script constructs `LLM_results.csv`, `figure_data.csv`, `Cities_by_Policy_Translation_Pattern.csv`, or `Regression_Analysis_Data.dta` from the completed stage-3 workbook. Before public release, deposit the missing transformation code or provide a deterministic, auditable specification of every aggregation, threshold, pattern assignment, merge, exclusion and external-variable source.

