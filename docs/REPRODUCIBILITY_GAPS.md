# Items to resolve before public release

## Blocking items

1. **Document-level policy provenance.** The policy texts were collected from official Chinese provincial and municipal government websites, but the supplied table contains local file paths rather than the original public URLs. Complete `docs/SOURCE_MANIFEST_TEMPLATE.csv` with one verified source URL and access date for each policy. The Python pipeline also references 1,076 JSON files under `policy_texts/`, totalling approximately 43 MB; decide whether these extracted texts may be redistributed or whether the repository will provide retrieval/extraction instructions only.
2. **Missing transformation code.** Supply code or a deterministic protocol that converts completed LLM outputs into `LLM_results.csv`, `figure_data.csv`, `Cities_by_Policy_Translation_Pattern.csv` and `Regression_Analysis_Data.dta`.
3. **Variable definitions.** Confirm `Weight`, the `-1/0/1` direction coding, the full meanings and formulas of `NAI`, `PTR`, `NTR`, `CC` and `CP`, and the definitions of Patterns 1–4.
4. **External covariates.** GDP per capita is sourced from the relevant municipal statistical yearbooks and carbon-emissions data from CEADs. Confirm the exact statistical-yearbook editions/tables, reference years, units, current/constant-price basis and any deflation; also confirm the exact CEADs city-level product/version, reference year, unit, denominator and carbon-emission-intensity transformation.
5. **Licences and creators.** Confirm data and code licences and provide the complete creator lists, affiliations and ORCIDs.

## Release checks

- Run both Stata do-files from the repository root and compare generated outputs with the manuscript tables.
- Test the repository and Zenodo records while signed out.
- Replace all DOI and source-access placeholders in `AVAILABILITY_STATEMENTS.md`.
- Cite the data and code records in the manuscript reference list.
- Confirm that no API key, private path, temporary file or author-only link is present in Git history.

