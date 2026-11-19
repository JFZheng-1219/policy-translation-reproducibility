"""English reproducibility script for the three-stage policy analysis.

This file is an English-language derivative of the research script. It reads the translated workbook released in the same directory and never stores or prints the API key.
"""

from __future__ import annotations
import argparse
import json
import os
import re
import shutil
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any
import openpyxl
from openai import OpenAI
REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO_ROOT / 'data' / 'source'
OUTPUT_DIR = REPO_ROOT / 'outputs' / 'llm'
INPUT_XLSX = SOURCE_DIR / 'Policy_data_cleaning_EN.xlsx'
PILOT_XLSX = OUTPUT_DIR / 'Results_step1_pilot_EN.xlsx'
FINAL_XLSX = OUTPUT_DIR / 'Results_step1_EN.xlsx'
MODEL = 'gpt-5.6-luna'
REASONING_EFFORT = 'medium'
SHEET_MAIN = 'Sheet1'
SHEET_CANDIDATES = 'Sheet1'
SEP = '; '
MATCHING_PROMPT = "You are a public-policy scholar with extensive expertise in Chinese climate and environmental governance. You are familiar with China's climate-policy architecture, the carbon-peaking and carbon-neutrality policy framework, ecological-civilization policies, carbon-market design, local policy implementation, and central–provincial–municipal policy transmission.\n\nYour task is to identify the superior-level policy document or documents on which a given subnational climate-policy document is based, or which it implements, carries forward, translates or responds to. The eligible subnational documents in Policy_data_cleaning_EN.xlsx are those issued at the levels of province, autonomous region, municipality, provincial capital city, sub-provincial city and prefecture-level city. The underlying policy text may be in Chinese, whereas candidate titles and metadata are provided in English. Always reproduce candidate titles exactly as supplied.\n\n# 1. Objective\n\nFor each eligible subnational climate-policy document, identify the superior-level policies that informed its formulation or that it implements, operationalizes or carries forward. The closed candidate set is constructed from the central- and provincial-level records in Policy_data_cleaning_EN.xlsx. Read the local policy title, the first 1,200 characters of its text, and the candidate metadata supplied in the request. Then apply all three matching mechanisms below in sequence.\n\n## M1. Explicit-reference matching\n\nIdentify a match when the local text explicitly names a superior policy in formulations equivalent to “this document is formulated in accordance with [policy]”, “pursuant to the requirements of [policy]”, “to implement [policy]”, “in accordance with the arrangements of [policy]”, “to implement the spirit of [policy]”, “with reference to [policy]” or “to align with [policy]”.\n\n## M2. Institutional-reference matching\n\nApply this mechanism when the local document does not give an exact title but expresses a clear institutional relationship of subordination or implementation.\n\n1. Strategic inheritance. Statements such as “implementing the strategic arrangements of the CPC Central Committee and the State Council on carbon peaking and carbon neutrality”, “implementing national ecological-civilization requirements” or “implementing the national climate-change strategy” should be linked to the relevant central framework policies.\n2. Policy-system inheritance. Recognize China's “1+N” climate-policy system. For example, a local commitment to advance carbon peaking in the industrial sector may inherit requirements from the central framework opinions on carbon peaking and carbon neutrality, the Action Plan for Carbon Dioxide Peaking Before 2030, and the central implementation plan for carbon peaking in the industrial sector.\n3. Institutional-chain inheritance. Recognize upstream and downstream relationships among policy instruments. For example, a local policy for an inclusive carbon programme should not be matched only to documents containing that phrase. Its institutional foundations may include national carbon-market policies, voluntary greenhouse-gas emissions-reduction trading, rules for certified emissions reductions, carbon-trading rules and carbon-finance services.\n\n## M3. Semantic-isomorphism matching\n\nUse the supplied candidate metadata to identify substantive correspondence in policy structure and policy objects.\n\n1. Title structure. A local “Implementation Plan for Carbon Peaking in the Industrial Sector” may correspond to the central policy with the same sector–goal–instrument structure.\n2. Policy object. Compare the governed objects. Industrial enterprises may point to industrial carbon-peaking policies; buildings to building-energy-efficiency or green-building policies; public low-carbon behaviour to inclusive-carbon or voluntary-emissions-reduction policies; key emitting entities to carbon-market policies; and ecosystem sinks to carbon-sink policies.\n\nFor M3, retain only the three or four most strongly matched superior policies. Do not use broad thematic similarity to generate an unlimited list.\n\n### Required semantic expansion for priority domains\n\n1. Inclusive-carbon policies. If the local document mentions an inclusive carbon programme, individual carbon accounts, green points, low-carbon scenarios, carbon entitlements, carbon credits, the exchange of emissions reductions, or an inclusive mechanism, expand the search beyond titles containing “inclusive carbon”. Consider:\n   - the carbon-market system: national carbon-market development, carbon emissions trading and carbon-trading institutions;\n   - the voluntary-emissions-reduction system: voluntary greenhouse-gas emissions-reduction trading, CCERs, certified emissions reductions, registration, trading and offsetting; and\n   - the carbon-services system: carbon-management platforms, carbon-service platforms, carbon-asset management and carbon-finance services.\n   Thus, a local plan for an inclusive-carbon system may correspond to rules for voluntary emissions-reduction trading and settlement, administrative measures for voluntary emissions-reduction trading, national carbon-market policies and carbon-trading institutional documents.\n2. Carbon-market policies. If the document mentions carbon trading, allowances, compliance, certified emissions reductions, offsetting or a trading platform, consider carbon emissions-trading institutions, voluntary-emissions-reduction trading and carbon-market development policies.\n3. Climate-adaptation policies. If the document mentions climate risk, disaster prevention and reduction, resilient cities or adaptation capacity, consider the national climate-adaptation strategy and the relevant provincial climate-adaptation action plan.\n\n# 2. Mandatory constraints\n\n1. Administrative hierarchy. For a provincial-level unit (province, autonomous region or municipality), eligible superior policies are central policies only. Never match a policy from another province. For a municipal-level unit (provincial capital city, sub-provincial city or prefecture-level city), eligible superior policies are central policies and policies of the province to which the city belongs. Never match policies from another province.\n2. Closed candidate set. Every returned title must be copied verbatim from the candidate list. Do not paraphrase, abbreviate, normalize punctuation or invent a title. No explanation is required in the title fields, because the returned titles must remain exactly consistent with the Filename field.\n3. Missing candidate. If the matching mechanisms identify a superior policy that should exist but is absent from the candidate list, place its title only in the separate `missing` array.\n4. Multiple sources. A local policy may inherit from more than one superior policy. Apply M1, M2 and M3 in order and return all defensible matches, subject to the M3 limit above.\n5. Abstention. If no defensible superior policy exists, return an empty array. Do not force a match, although the task should normally identify at least one superior policy when the evidence supports it.\n\n# 3. Illustrative examples\n\n## Example 1: M1 explicit reference for a provincial policy\n\nLocal title: Implementing Opinions of Zhejiang Province on Fully and Faithfully Implementing the New Development Philosophy and Advancing Carbon Peaking and Carbon Neutrality.\nAdministrative level: Province.\nRegion: Zhejiang Province.\nText excerpt: “To implement the Opinions of the CPC Central Committee and the State Council on Fully and Faithfully Implementing the New Development Philosophy and Advancing Carbon Peaking and Carbon Neutrality, and to advance work in our province …”.\nThe returned central policy is the candidate title corresponding exactly to those central opinions.\n\n## Example 2: M1 and M2 with multiple central sources\n\nLocal title: Notice of Liaoning Province on Issuing the Liaoning Provincial Carbon-Peaking Implementation Plan.\nAdministrative level: Province.\nText excerpt: “To thoroughly implement the major strategic decisions of the CPC Central Committee and the State Council on carbon peaking and carbon neutrality, and to implement the central framework opinions and the Action Plan for Carbon Dioxide Peaking Before 2030 … this plan is formulated.”\nThe central set includes the exact candidate titles of the framework opinions and the 2030 action plan, together with any other directly relevant framework document supported by the excerpt.\n\n## Example 3: M3 title and domain isomorphism for a city\n\nLocal title: Notice of Xiamen on Issuing the Xiamen Implementation Plan for Carbon Peaking in Urban-Rural Development.\nAdministrative level: Sub-provincial city.\nRegion: Xiamen.\nText excerpt: “To implement the decisions and arrangements of the CPC Central Committee and the State Council and the work requirements of the province and the city …”.\nThe central set may include the national implementation plan for carbon peaking in urban-rural development, and the provincial set may include the Fujian provincial implementation plan with the same sector–goal–instrument structure, provided that their exact titles appear in the candidate list.\n\n## Example 4: M2 institutional reference for a city\n\nLocal title: Lanzhou Implementation Plan for Achieving Peak Carbon Emissions by 2025.\nAdministrative level: Provincial capital city.\nRegion: Lanzhou.\nText excerpt: “The Lanzhou Development and Reform Commission, in accordance with national and provincial work on climate change, energy conservation and emissions reduction …”.\nThe central set may include the central framework opinions and the national 2030 carbon-peaking action plan; the provincial set may include the Gansu provincial carbon-peaking implementation plan, provided that the exact candidate titles support these matches."
CITY_TO_PROVINCE = {'Lanzhou': 'Gansu Province', 'Nanning': 'Guangxi Zhuang Autonomous Region', 'Taiyuan': 'Shanxi Province', 'Lhasa': 'Tibet Autonomous Region', 'Kunming': 'Yunnan Province', 'Haikou': 'Hainan Province', 'Shijiazhuang': 'Hebei Province', 'Xining': 'Qinghai Province', 'Guiyang': 'Guizhou Province', 'Zhengzhou': 'Henan Province', 'Yinchuan': 'Ningxia Hui Autonomous Region', 'Changsha': 'Hunan Province', 'Shenzhen': 'Guangdong Province', 'Nanjing': 'Jiangsu Province', 'Xiamen': 'Fujian Province', 'Harbin': 'Heilongjiang Province', 'Dalian': 'Liaoning Province', 'Ningbo': 'Zhejiang Province', 'Chengdu': 'Sichuan Province', 'Hangzhou': 'Zhejiang Province', 'Wuhan': 'Hubei Province', 'Shenyang': 'Liaoning Province', 'Jinan': 'Shandong Province', "Xi'an": 'Shaanxi Province', 'Changchun': 'Jilin Province', 'Sanming': 'Fujian Province', 'Shangrao': 'Jiangxi Province', 'Dongying': 'Shandong Province', 'Zhongwei': 'Ningxia Hui Autonomous Region', 'Wuhai': 'Inner Mongolia Autonomous Region', 'Bozhou': 'Anhui Province', 'Liupanshui': 'Guizhou Province', 'Neijiang': 'Sichuan Province', 'Baotou': 'Inner Mongolia Autonomous Region', 'Nantong': 'Jiangsu Province', 'Bortala Mongol Autonomous Prefecture': 'Xinjiang Uygur Autonomous Region', 'Wuzhong': 'Ningxia Hui Autonomous Region', 'Kashgar Prefecture': 'Xinjiang Uygur Autonomous Region', 'Jiayuguan': 'Gansu Province', 'Daqing': 'Heilongjiang Province', 'Dali Bai Autonomous Prefecture': 'Yunnan Province', 'Weihai': 'Shandong Province', 'Xiaogan': 'Hubei Province', 'Ankang': 'Shaanxi Province', 'Anshun': 'Guizhou Province', 'Baoji': 'Shaanxi Province', 'Xuancheng': 'Anhui Province', 'Yueyang': 'Hunan Province', 'Bayannur': 'Inner Mongolia Autonomous Region', 'Pingliang': 'Gansu Province', 'Langfang': 'Hebei Province', 'Kaifeng': 'Henan Province', 'Zhangjiakou': 'Hebei Province', 'Zhangye': 'Gansu Province', 'Deyang': 'Sichuan Province', 'Wenshan Zhuang and Miao Autonomous Prefecture': 'Yunnan Province', 'Xinyu': 'Jiangxi Province', 'Changji Hui Autonomous Prefecture': 'Xinjiang Uygur Autonomous Region', 'Jincheng': 'Shanxi Province', 'Jingdezhen': 'Jiangxi Province', 'Benxi': 'Liaoning Province', 'Laibin': 'Guangxi Zhuang Autonomous Region', 'Songyuan': 'Jilin Province', 'Liuzhou': 'Guangxi Zhuang Autonomous Region', 'Guilin': 'Guangxi Zhuang Autonomous Region', 'Yulin': 'Shaanxi Province', 'Heyuan': 'Guangdong Province', 'Quanzhou': 'Fujian Province', "Tai'an": 'Shandong Province', 'Taizhou': 'Jiangsu Province', 'Huainan': 'Anhui Province', 'Qingyuan': 'Guangdong Province', 'Zhanjiang': 'Guangdong Province', 'Shizuishan': 'Ningxia Hui Autonomous Region', 'Honghe Hani and Yi Autonomous Prefecture': 'Yunnan Province', 'Shaoxing': 'Zhejiang Province', 'Putian': 'Fujian Province', 'Hengyang': 'Hunan Province', 'Quzhou': 'Zhejiang Province', 'Xuchang': 'Henan Province', 'Liaoyuan': 'Jilin Province', 'Liaoyang': 'Liaoning Province', 'Yuncheng': 'Shanxi Province', 'Tonghua': 'Jilin Province', 'Suining': 'Sichuan Province', 'Handan': 'Hebei Province', 'Shaoyang': 'Hunan Province', 'Jinhua': 'Zhejiang Province', 'Zhenjiang': 'Jiangsu Province', 'Changzhi': 'Shanxi Province', 'Fuxin': 'Liaoning Province', 'Jixi': 'Heilongjiang Province', 'Hebi': 'Henan Province', 'Huanggang': 'Hubei Province', 'Huangshi': 'Hubei Province', 'Qiandongnan Miao and Dong Autonomous Prefecture': 'Guizhou Province', 'Qiqihar': 'Heilongjiang Province'}

def normalize_title(value: Any) -> str:
    return str(value or '').strip()

def split_titles(value: Any) -> list[str]:
    text = normalize_title(value)
    return [x.strip() for x in re.split('[；;、\\n]+', text) if x.strip()]

def merge_titles(existing: Any, generated: list[str]) -> str:
    result: list[str] = []
    for title in split_titles(existing) + generated:
        if title and title not in result:
            result.append(title)
    return SEP.join(result)

def read_policy_text(path_value: Any) -> str:
    path = Path(normalize_title(path_value))
    if not path.is_absolute():
        path = SOURCE_DIR / path
    try:
        obj = json.loads(path.read_text(encoding='utf-8'))
        text = obj.get('markdown') or obj.get('text') or obj.get('content') or ''
        return str(text)[:1200]
    except Exception as exc:
        return f'[Unable to read policy text: {exc}]'

def get_province(region: str) -> str | None:
    return CITY_TO_PROVINCE.get(region)

def load_candidates(ws) -> list[dict[str, str]]:
    rows = list(ws.iter_rows(values_only=True))
    headers = [normalize_title(x) for x in rows[0]]
    out = []
    for row in rows[1:]:
        item = dict(zip(headers, row))
        title = normalize_title(item.get('Filename'))
        if title:
            out.append({'title': title, 'level': normalize_title(item.get('Administrative level')), 'region': normalize_title(item.get('Region name')), 'tag': normalize_title(item.get('Domain tags')), 'summary': normalize_title(item.get('Summary'))})
    return out

def allowed_candidates(row: dict[str, Any], candidates: list[dict[str, str]]) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    level = normalize_title(row['level'])
    region = normalize_title(row['region'])
    central = [c for c in candidates if c['level'] in {'Central', 'National'}]
    province_name = region if level in {'Province', 'Autonomous region', 'Municipality'} else get_province(region)
    province = [c for c in candidates if province_name and c['region'] == province_name and (c['level'] not in {'Central', 'National'})]
    return (central, province)

def candidate_block(label: str, items: list[dict[str, str]]) -> str:
    lines = [f'[{label.upper()} CANDIDATE LIST]']
    for idx, c in enumerate(items, 1):
        metadata = [f"Title: {c['title']}"]
        if c['tag']:
            metadata.append(f"domain tags: {c['tag']}")
        if c['summary']:
            metadata.append(f"summary: {c['summary']}")
        lines.append(f"{idx}. " + '; '.join(metadata))
    return '\n'.join(lines)

def parse_response(text: str, central: list[dict[str, str]], province: list[dict[str, str]]) -> tuple[list[str], list[str], list[str]]:
    allowed_c = {x['title'] for x in central}
    allowed_p = {x['title'] for x in province}
    try:
        obj = json.loads(text)
        c = obj.get('central', [])
        p = obj.get('province', [])
        missing = obj.get('missing', [])
        if isinstance(c, str):
            c = [c]
        if isinstance(p, str):
            p = [p]
        if isinstance(missing, str):
            missing = [missing]
        return ([x for x in c if x in allowed_c], [x for x in p if x in allowed_p], [str(x) for x in missing])
    except Exception:
        return ([title for title in allowed_c if title in text], [title for title in allowed_p if title in text], [])

def call_model(client: OpenAI, row: dict[str, Any], body: str, central: list[dict[str, str]], province: list[dict[str, str]]) -> tuple[list[str], list[str], list[str], str]:
    level = normalize_title(row['level'])
    region = normalize_title(row['region'])
    user_content = MATCHING_PROMPT + '\n\n' + f'''[POLICY TO BE MATCHED]
Administrative level: {level}
Region name: {region}
Policy title: {row['filename']}
First 1,200 characters of the policy text:
{body}

{candidate_block('Central', central)}

{candidate_block('Province containing the city', province)}

Select titles verbatim and only from the candidate lists. Provincial-level units may return only `central`; municipal-level units may return both `central` and `province`. Return strict JSON with no explanation:
{{"central":["candidate title"],"province":["candidate title"],"missing":["title required by the matching rules but absent from the candidate list"]}}
Use an empty array when there is no match; do not place the phrase `No match` in a title array.'''
    response = client.responses.create(
        model=MODEL,
        reasoning={'effort': REASONING_EFFORT},
        input=user_content,
        store=False,
    )
    text = response.output_text
    c, p, missing = parse_response(text, central, province)
    return (c, p, missing, text)

def process(input_path: Path, output_path: Path, limit: int | None, skip: int=0) -> int:
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        raise RuntimeError('The OPENAI_API_KEY environment variable is not set.')
    client = OpenAI(api_key=api_key, timeout=60.0, max_retries=2)
    wb = openpyxl.load_workbook(input_path)
    ws = wb[SHEET_MAIN]
    cws = wb[SHEET_CANDIDATES]
    headers = {normalize_title(ws.cell(1, col).value): col for col in range(1, ws.max_column + 1)}
    candidates = load_candidates(cws)
    eligible_levels = {'Province', 'Autonomous region', 'Municipality', 'Provincial capital city', 'Sub-provincial city', 'Prefecture-level city'}
    processed = 0
    skipped = 0
    pending: list[tuple[int, dict[str, Any], list[dict[str, str]], list[dict[str, str]], str]] = []
    for excel_row in range(2, ws.max_row + 1):
        level = normalize_title(ws.cell(excel_row, headers['Administrative level']).value)
        if level not in eligible_levels:
            continue
        if skip and skipped < skip:
            skipped += 1
            continue
        row = {'level': level, 'region': ws.cell(excel_row, headers['Region name']).value, 'filename': ws.cell(excel_row, headers['Filename']).value, 'location': ws.cell(excel_row, headers['Textual location']).value}
        central, province = allowed_candidates(row, candidates)
        body = read_policy_text(row['location'])
        pending.append((excel_row, row, central, province, body))
        if limit is not None and len(pending) >= limit:
            break

    def run_one(item):
        excel_row, row, central, province, body = item
        result = call_model(client, row, body, central, province)
        return (excel_row, row, result)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(run_one, item) for item in pending]
        for done_no, future in enumerate(as_completed(futures), 1):
            excel_row, row, result = future.result()
            c_titles, p_titles, missing, raw = result
            print(f'Completed {done_no}/{len(futures)}: Excel row {excel_row}: {row["filename"]}')
            center_col = headers['Matched_Parent_Files(center)']
            province_col = headers['Matched_Parent_Files(province)']
            ws.cell(excel_row, center_col).value = merge_titles(ws.cell(excel_row, center_col).value, c_titles)
            ws.cell(excel_row, province_col).value = merge_titles(ws.cell(excel_row, province_col).value, p_titles)
            if missing:
                note_col = headers.get('Notes')
                if note_col:
                    ws.cell(excel_row, note_col).value = merge_titles(ws.cell(excel_row, note_col).value, missing)
            processed += 1
    wb.save(output_path)
    return processed

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    parser = argparse.ArgumentParser()
    parser.add_argument('--continue', dest='continue_run', action='store_true', help='Continue processing all remaining policy records.')
    args = parser.parse_args()
    if args.continue_run:
        count = process(PILOT_XLSX if PILOT_XLSX.exists() else INPUT_XLSX, FINAL_XLSX, None, skip=10)
        print(f'Completed all remaining records ({count} processed). Output: {FINAL_XLSX}')
        return
    count = process(INPUT_XLSX, PILOT_XLSX, 10)
    print(f'Pilot completed ({count} records processed). Output: {PILOT_XLSX}')
    answer = input('Continue Step 1 and generate Results_step1_EN.xlsx? Enter yes/no: ').strip().lower()
    if answer in {'yes', 'y'}:
        count = process(PILOT_XLSX, FINAL_XLSX, None)
        print(f'Completed all records ({count} processed). Output: {FINAL_XLSX}')
    else:
        print('Paused after the pilot. After reviewing the pilot output, run: python step1.py --continue')
if __name__ == '__main__':
    main()
