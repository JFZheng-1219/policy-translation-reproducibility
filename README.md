# Alignment without uniformity in national climate policy translation in Chinese cities

This repository contains the deposited data and custom code supporting the manuscript *Alignment without uniformity in national climate policy translation in Chinese cities*, by Jinfeng Zheng, Fan Wu and Haoxuan Sa, prepared for submission to *Nature Cities*.

## Scope

The repository provides the exact processed data, figure source data and analysis-ready data used in the manuscript, together with the three Python scripts for the LLM-assisted policy analysis and the Stata scripts for the M1–M6 statistical analyses. It does not contain the original policy-text corpus or a complete executable transformation from the LLM outputs to every processed, figure and regression dataset. The deposited processed and analysis-ready datasets therefore serve as the fixed inputs for reproducing the reported figures and statistical analyses.

## Repository contents

```text
code/
  python/                     Three-stage LLM-assisted policy analysis
  stata/                      M1–M6 statistical analyses
data/
  source/                     Policy metadata and the stage-1 input workbook
  processed/                  LLM-derived results, city patterns and figure data
  analysis/                   Analysis-ready regression data
docs/
  DATA_DICTIONARY.md          File- and variable-level documentation
  SOURCES_AND_ACCESS.md       Official source routes and download procedures
  SOURCE_MANIFEST_TEMPLATE.csv Template for document-level provenance records
  REPRODUCIBILITY.md          Reproduction instructions and environment
  CODE_AUDIT.md               Static code review and limited smoke-test findings
  AVAILABILITY_STATEMENTS.md  Manuscript-ready statement templates
  REPOSITORY_METADATA.md      GitHub and Zenodo metadata checklist
  REPRODUCIBILITY_GAPS.md     Items that must be resolved before public release
outputs/
  llm/                        Generated Python-pipeline outputs
  stata/                      Generated Stata tables and diagnostics
```

## Data files

- `data/source/Policy_data_cleaning_EN.xlsx`: Excel input workbook containing metadata for 1,076 policy documents and empty fields populated by the three-stage Python pipeline.
- `data/source/Policy_data_cleaning_EN.csv`: open-format copy of the input worksheet.
- `data/processed/LLM_results.csv`: document-level LLM-derived scores and directions.
- `data/processed/Cities_by_Policy_Translation_Pattern.csv`: classifications for 107 urban units.
- `data/processed/figure_data.csv`: source data for the study figures.
- `data/analysis/Regression_Analysis_Data.dta`: analysis-ready data for M1–M6 (103 cities nested within 27 province-level units).
- `data/analysis/Regression_Analysis_Data.csv`: open-format copy of the numerical regression data.

The four files originally supplied with a `.csv` extension were internally Excel workbooks. This repository corrects the mismatch: the Python input is retained as `.xlsx`, and the public tabular copies are genuine UTF-8 CSV files.

## Code files

- `code/python/step1.py`: matches subnational policies to candidate superior-level policies.
- `code/python/step2.py`: produces four-dimensional policy summaries.
- `code/python/step3.py`: scores alignment against central and provincial policy collections.
- `code/stata/M1_M2.do`: primary multinomial models and reporting outputs.
- `code/stata/M3_M4_M5_M6.do`: robustness and sensitivity analyses.

## Authors

- Jinfeng Zheng
- Fan Wu
- Haoxuan Sa

## Quick start

For Stata, set the working directory to the repository root and run:

```stata
do code/stata/M1_M2.do
do code/stata/M3_M4_M5_M6.do
```

For Python:

```text
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
```

See `docs/SOURCES_AND_ACCESS.md` for the official source routes, `docs/REPRODUCIBILITY.md` for the complete workflow and `docs/REPRODUCIBILITY_GAPS.md` for items that must be resolved before public release.

