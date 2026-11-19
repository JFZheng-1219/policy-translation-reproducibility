# Public sources and access procedures

This document records the public access routes for the third-party source materials and covariates used in the study. A general website homepage is not a substitute for document-level provenance: every policy document and statistical-yearbook observation should also be represented in the repository source manifest.

## Policy documents

The original policy documents were collected from the official websites of the relevant Chinese provincial and municipal governments. For each policy, record the issuing authority, official policy title, document number where available, publication date, original webpage or file URL, access date and corresponding repository filename in `SOURCE_MANIFEST_TEMPLATE.csv`.

Recommended retrieval procedure:

1. Open the official website of the issuing provincial or municipal government.
2. Search the policy title or document number in the site's government-information-disclosure or policy-document section.
3. Open the original HTML page or official PDF/DOC attachment, rather than a news repost or commercial database copy.
4. Record the final official URL and access date in the source manifest.
5. Save or extract the text using the documented UTF-8 workflow, without altering the substantive content.
6. If an original URL has moved, record the replacement official URL and note the change; do not silently replace it with an unofficial mirror.

The State Council policy database (`https://sousuo.www.gov.cn/zcwjk/`) can be used for applicable central-government documents, but provincial and municipal documents should be linked to their issuing authorities' official websites.

## City GDP per capita

City GDP per capita was compiled from the statistical yearbook issued by each relevant municipal statistics authority. The National Bureau of Statistics of China identifies local statistics bureau websites and locally published statistical yearbooks as the principal routes for subprovincial statistics:

- National Bureau of Statistics guidance: `https://www.stats.gov.cn/zs/tjws/tjzn/202301/t20230101_1903751.html`
- National Bureau of Statistics homepage: `https://www.stats.gov.cn/`

Recommended retrieval procedure:

1. Follow the relevant municipal statistics bureau's official website or statistical-yearbook section.
2. Select the exact yearbook edition used in the analysis.
3. Record the table title, reference year, unit, whether values are reported at current or constant prices, and the page/table number where available.
4. If GDP per capita is calculated rather than directly reported, record the numerator, denominator, population definition and formula.
5. Record the official yearbook/table URL and access date in the source manifest.

The final repository documentation must state the analysis reference year, currency unit, price basis and any deflation or logarithmic transformation.

## City carbon emissions

City-level carbon-emissions data were obtained from the China Emission Accounts and Datasets (CEADs):

- CEADs data portal: `https://www.ceads.net/data/`
- CEADs city-level carbon-emission inventories: `https://www.ceads.net/data/carbon-inventory/city-level/`

Recommended retrieval procedure:

1. Open the CEADs city-level carbon-emission-inventory page.
2. Select the exact product/version used in the study.
3. Follow the CEADs download or account-access procedure shown for that product.
4. Record the product title, version, coverage years, release date, download URL and access date.
5. Preserve the original downloaded file and its licence/terms metadata where redistribution is permitted.
6. Document how the selected emissions field was matched to cities and converted into carbon-emission intensity.

The final repository documentation must identify the exact CEADs product/version and specify the emissions unit, reference year, intensity denominator and transformation formula. Do not cite only the CEADs homepage.

## Minimum provenance fields

The source manifest should contain, where applicable: record identifier, data type, region, document or dataset title, issuing authority/provider, publication year, data year, official URL, access date, local filename, version, unit, price basis, transformation and notes.
