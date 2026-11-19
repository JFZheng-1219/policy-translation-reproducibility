# Data dictionary

## `data/source/Policy_data_cleaning_EN.*`

One record per policy document; 1,076 records. The `.xlsx` file is the input expected by the Python pipeline. The `.csv` file is an open-format copy of its only worksheet.

| Field or field family | Description |
|---|---|
| `Administrative level` | Administrative level of the issuing authority. |
| `Region name` | Region associated with the policy. |
| `Filename` | English policy-document title used as the document identifier. |
| `Year` | Policy year. |
| `Issuing agency` | Issuing government authority or authorities. |
| `Textual location` | Repository-relative location of the extracted policy text. |
| `Matched_Parent_Files(center)` | Superior central policies matched in stage 1. |
| `Matched_Parent_Files(province)` | Superior provincial policies matched in stage 1. |
| `Goals`, `Instruments`, `Actors`, `Temporal` | Four policy-narrative dimensions generated in stage 2. |
| `*_Score`, `*_Reason` | Central-comparison scores and reasons generated in stage 3. |
| `*_Score（CP)`, `*_Reason（CP)` | Provincial-comparison scores and reasons generated in stage 3. |

Blank analysis fields in the source workbook are expected; they are populated sequentially by `step1.py`, `step2.py` and `step3.py`.

## `data/processed/LLM_results.csv`

One record per policy document; 1,076 records. Contains administrative identifiers, a document weight, four dimension-specific central-comparison scores and directions, and corresponding provincial-comparison fields where applicable.

Direction fields use the observed codes `-1`, `0` and `1`. The final public documentation must confirm their exact mapping to the study's negative, no-directional and positive categories. The meaning and construction of `Weight` must also be supplied.

## `data/processed/Cities_by_Policy_Translation_Pattern.csv`

Contains 107 urban units: 72 ordinary prefecture-level cities, 26 provincial capitals, five sub-provincial cities and four municipalities.

| Field | Description |
|---|---|
| `Pattern` | Four-category policy-translation pattern (`Pattern 1`–`Pattern 4`). |
| `Region ID` | Study-specific urban-unit identifier. |
| `Administrative level` | Urban administrative category. |
| `Region name` | Urban-unit name. |

The substantive definition and assignment rule for each pattern must be added from the manuscript Methods or transformation code.

## `data/processed/figure_data.csv`

Contains 134 region-level records and 33 fields used to prepare the figures.

| Field family | Description |
|---|---|
| `Region ID`, `Administrative level`, `Region name` | Region identifiers and administrative category. |
| `NAI*` | Alignment-index fields. The full expansion, formula, scale and missing-value rule must be added. |
| `PTR*` | Positive-translation fields, including dimension-specific values. The formula and denominator must be added. |
| `NTR*` | Negative-translation fields, including dimension-specific values. The formula and denominator must be added. |
| Fields ending in `(CC)` | Central-comparison measures; confirm the manuscript terminology. |
| Fields ending in `(CP)` | Provincial-comparison measures; confirm the manuscript terminology. |

## `data/analysis/Regression_Analysis_Data.*`

Analysis-ready sample of 103 cities nested within 27 province-level units. The four municipalities are excluded because province-level translation measures are not defined for them. The `.dta` file preserves labels; the `.csv` file preserves numerical values in an open format.

| Variable | Description |
|---|---|
| `region_id` | Study-specific city identifier. |
| `region_name` | City name. |
| `gsem_city_sample` | Indicator for inclusion in the city-level modelling sample; all deposited observations equal 1. |
| `pattern` | Unordered four-category city policy-translation outcome; Pattern 1 is the model reference category. |
| `province_id` | Province-level cluster identifier. |
| `ln_GDPpc` | Natural logarithm of city GDP per capita compiled from the statistical yearbook issued by the relevant municipal statistics authority. The reference year, currency unit, current/constant-price basis and any deflation procedure must still be documented. |
| `ln_CEI` | Natural logarithm of city carbon-emission intensity constructed using city-level carbon-emissions data from the China Emission Accounts and Datasets (CEADs). The exact CEADs product/version, reference year, unit, denominator and transformation formula must still be documented. |
| `admin_level` | City administrative-level category. |
| `economic_region` | Economic-region category: East, Central, West or Northeast. |
| `S_PC_goal` | Provincial Goal net translation orientation, defined in the Stata label as `PTR - NTR`. |
| `S_PC_instrument` | Provincial Instrument net translation orientation, defined as `PTR - NTR`. |
| `S_PC_actor` | Provincial Actor net translation orientation, defined as `PTR - NTR`. |
| `S_PC_temporal` | Provincial Temporal net translation orientation, defined as `PTR - NTR`. |

No individual-level or personally identifying data were detected in the supplied files. Missing values in CSV files are represented by empty fields unless otherwise documented.

