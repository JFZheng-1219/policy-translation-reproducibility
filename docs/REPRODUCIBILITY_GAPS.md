# Items to resolve before public release

## Blocking items

1. **Policy-text access route.** The Python pipeline references 1,076 JSON files under `policy_texts/`, totalling approximately 43 MB. These files were not included in the approved upload list. Decide whether they may be redistributed after stripping local paths, or replace them with verified source URLs and a documented retrieval/extraction workflow.
2. **Missing transformation code.** Supply code or a deterministic protocol that converts completed LLM outputs into `LLM_results.csv`, `figure_data.csv`, `Cities_by_Policy_Translation_Pattern.csv` and `Regression_Analysis_Data.dta`.
3. **Variable definitions.** Confirm `Weight`, the `-1/0/1` direction coding, the full meanings and formulas of `NAI`, `PTR`, `NTR`, `CC` and `CP`, and the definitions of Patterns 1–4.
4. **External covariates.** Document the source, reference year, units, deflation/base-year choices and transformations for GDP per capita and carbon-emission intensity.
5. **Licences and creators.** Confirm data and code licences and provide the complete creator lists, affiliations and ORCIDs.

## Release checks

- Run both Stata do-files from the repository root and compare generated outputs with the manuscript tables.
- Test the repository and Zenodo records while signed out.
- Replace all DOI and source-access placeholders in `AVAILABILITY_STATEMENTS.md`.
- Cite the data and code records in the manuscript reference list.
- Confirm that no API key, private path, temporary file or author-only link is present in Git history.

