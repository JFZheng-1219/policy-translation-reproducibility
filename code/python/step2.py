"""English reproducibility script for the three-stage policy analysis.

This file is an English-language derivative of the research script. It reads the translated workbook released in the same directory and never stores or prints the API key.
"""

from __future__ import annotations
import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any
import openpyxl
from openai import OpenAI
REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO_ROOT / 'data' / 'source'
OUTPUT_DIR = REPO_ROOT / 'outputs' / 'llm'
INPUT_XLSX = OUTPUT_DIR / 'Results_step1_EN.xlsx'
OUTPUT_XLSX = OUTPUT_DIR / 'Results_step2_EN.xlsx'
ERROR_LOG = OUTPUT_DIR / 'step2-errors.jsonl'
MODEL = 'gpt-5.6-terra'
REASONING_EFFORT = 'medium'
SHEET_NAME = 'Sheet1'
CHECKPOINT_EVERY = 200
MAX_WORKERS = 4
ANALYSIS_PROMPT = "You are a public-policy scholar with extensive expertise in climate change, carbon peaking and carbon neutrality, ecological and environmental governance, energy transitions, carbon markets, climate adaptation and local policy implementation in China. You are familiar with China's central–provincial–municipal policy-transmission system, conventions of government policy writing, departmental divisions of responsibility, Five-Year Plan cycles, pilot governance and administrative, market-based and technological policy instruments.\n\nYour task is not to provide a generic summary or analyse rhetorical style. Instead, use the complete original policy text identified by the `Textual location` field to recover the structured system of meaning that constitutes the policy narrative. The source policy may be in Chinese; write the four outputs in polished English.\n\nIn this study, a policy narrative comprises four dimensions:\n\n1. Policy goals: the problem the policy seeks to address and the state that defines policy success.\n2. Policy instruments: the mechanisms, tools and implementation pathways through which the policy expects to achieve its goals.\n3. Responsible actors: the actors that steer, implement, enforce, regulate, participate in or bear responsibility for the policy.\n4. Temporal orientation: the speed, sequence, stages and time horizon through which policy change is expected to unfold.\n\nRead the complete policy text and base every conclusion strictly on that text.\n\n# 1. General principles\n\n1. Treat the policy as a structured governance logic rather than a bag of keywords. Do not infer the four dimensions from the title, section headings or term frequency alone. Interpret how the policy defines the problem, what it seeks to change, how the proposed mechanisms are expected to produce change, which actors carry differentiated roles, and how implementation unfolds over time.\n2. Use only information explicitly stated in the original policy or directly recoverable from its internal structure. Do not add external knowledge, infer objectives from common sense, invent responsible departments, automatically add 2030 or 2060 when those dates are absent, import content from a superior policy, or describe a possible effect as an explicit policy objective. When evidence for a dimension is limited, state the available information concisely rather than fabricating detail.\n\n# 2. Internal policy-type assessment\n\nBefore producing the four outputs, determine internally which policy type or combination of types best describes the document. This classification is for analytical calibration only and must not be returned. Possible types include comprehensive strategy or top-level design; comprehensive action plan; sectoral carbon-peaking policy; local carbon-peaking implementation; energy conservation and carbon reduction; pollution control; circular-resource use; carbon market or emissions trading; voluntary emissions-reduction market; inclusive carbon programme; carbon footprint or product-carbon management; green finance; ecological carbon sinks; climate adaptation; risk governance; pilot or demonstration; technical standard or management specification; planning document; administrative measures or trading rules; and other types. Use the policy type to adjust the analytical emphasis without changing the four output dimensions.\n\nExamples below are illustrative rather than exhaustive. Analyse each document on its own terms.\n\n# 3. Policy goals\n\nAnswer: What is the policy problem, what change is sought, and what counts as success?\n\nDo not merely condense a section labelled “main objectives”. Reconstruct the sequence from problem definition to desired state and success criteria.\n\n1. Problem definition. Identify the conditions that the policy defines as requiring change, such as a carbon-intensive energy structure, low energy efficiency, high pollution, an industrial structure requiring adjustment, incomplete carbon-market institutions, a need to ensure the integrity of emissions reductions, rising climate risk, insufficient infrastructure resilience, weak conversion of forest carbon sinks into ecological-product value, absent product-carbon-footprint rules, or limited local low-carbon experience. Do not add causal claims unless they are stated in the text.\n2. Desired change. Identify the governance, economic, social, market or ecological state the policy seeks to create, such as a green and low-carbon industrial system, a unified carbon market, greater climate resilience, a carbon-footprint management system, stronger forest carbon sinks or a circular-economy system.\n3. Success criteria. Prioritize quantitative targets, intensity targets, shares, institutional-development objectives, capacity-building objectives, market-operation objectives, risk-reduction targets and demonstration or diffusion targets. If no quantitative indicator is supplied, state the qualitative success criteria.\n4. Broader purpose. If the text explicitly connects the policy to carbon peaking and carbon neutrality, high-quality development, the Beautiful China initiative, ecological civilization or public-health security, this broader purpose may be noted briefly. Do not allow broad political language to replace the policy's specific objectives.\n\nWrite approximately 120–180 English words. Prioritize the sequence: problem definition → desired change → success criteria. Do not write a task inventory.\n\n# 4. Policy instruments\n\nAnswer: Through what causal, institutional and operational mechanisms does the policy expect its goals to be achieved?\n\nDo not list every “key task”. Identify the principal instrument mix and the mechanisms through which it is expected to work. Relevant types may include:\n\n1. Regulatory instruments: legislation, standards, mandatory requirements, approval, market access, capacity controls, emissions controls, energy-conservation review, environmental impact assessment, inspection, enforcement and administrative penalties.\n2. Economic and market instruments: fiscal subsidies, taxation, government procurement, pricing, green credit, green bonds, green funds, carbon emissions trading, CCERs, inclusive-carbon mechanisms, energy-use-rights trading and ecological compensation.\n3. Technological instruments: research and development, technological retrofitting, digitalization, renewable-energy substitution, carbon capture, utilization and storage, energy storage, efficient equipment and monitoring technologies.\n4. Information and measurement instruments: accounting, monitoring, reporting, disclosure, registries, inventories, standards and third-party verification.\n5. Organizational instruments: interdepartmental coordination, joint mechanisms, dedicated taskforces, leading groups, responsibility systems, performance assessment, pilots and demonstration projects.\n6. Capacity-building and social instruments: training, workforce development, public communication, participation, industry associations and professional service organizations.\n\nOther instruments may include structural adjustment, command-and-control measures, economic incentives, information and capacity measures, organizational procedures and social mobilization. Explain how the instruments work together. For example, a policy may use a methodology to define project boundaries, third-party verification to protect integrity, a registry to establish ownership and a market to realize the value of emissions reductions. Alternatively, efficiency constraints may remove inefficient capacity while retrofitting and energy substitution reduce emissions from existing assets and green finance lowers transition costs. For a complex policy, synthesize the three to six most consequential instrument families rather than cataloguing every measure.\n\nWrite approximately 120–180 English words, covering the main instrument mix, relationships among instruments and the mechanism through which change is expected to occur.\n\n# 5. Responsible actors\n\nAnswer: Who steers, who implements, who is regulated or mobilized, and how is responsibility distributed?\n\nDo not copy a list of “responsible units”. Distinguish the following roles internally:\n\n1. Steering actors: bodies responsible for overall decisions, coordination, rulemaking, task allocation, supervision and performance assessment, such as central ministries, provincial or municipal governments, leading groups and development and reform authorities.\n2. Implementing actors: bodies that put the policy into practice, construct projects, enforce rules, deliver public services or undertake specific actions, such as local governments, sectoral departments, institutions and industrial-park authorities.\n3. Regulated or target actors: organizations whose behaviour the policy seeks to change, including key emitting entities, construction or transport companies, financial institutions, project owners and key energy-consuming units.\n4. Intermediary actors: organizations providing validation, verification, certification, advice, research, finance or technical services, including third-party verifiers, industry associations, research institutes, certification bodies and trading institutions.\n5. Social or participating actors: residents, consumers, communities, farmers, volunteers, news media and civil-society organizations, distinguishing whether they are participants, beneficiaries, protected groups or monitors.\n\nThe objective is to explain how governance responsibility is organized and allocated, not to count departments. Where present, summarize central–provincial–municipal–county relationships and government–market–society coordination. If the document names only one competent authority and one regulated group, do not invent additional actors.\n\nWrite approximately 90–140 English words.\n\n# 6. Temporal orientation\n\nAnswer: How does the policy imagine change unfolding over time?\n\nDo more than extract dates. Analyse milestones, implementation stages, sequencing, pace, short- and long-term relationships, and feedback, evaluation or adjustment mechanisms.\n\n1. Extract explicit time information, including target years, Five-Year Plan periods, annual or periodic cycles, phased implementation, three-year actions, five-year post-enactment periods and pilot durations.\n2. Identify the temporal logic internally. Possible modes include:\n   - milestone-driven: targets intensify across key years;\n   - phased transformation: different stages perform different transition functions;\n   - experimental diffusion: pilot launch → institution building → model formation → wider replication;\n   - adaptive iteration: monitoring → risk assessment → warning → intervention → reassessment;\n   - continuous procedure: application → verification → registration → trading → supervision → next cycle; and\n   - incremental or rolling implementation: scope expands gradually, lists are updated annually, measures are introduced in batches or arrangements are continually refined.\n3. Explain the meaning of the time structure. Do not merely state that the policy gives targets for 2025 and 2030. Explain, for example, that 2025 is a foundation-building stage and 2030 a maturity point, with pilots preceding expansion. If no end date is stated, say explicitly that the policy establishes continuous institution building or routine implementation rather than inventing a milestone.\n\nWrite approximately 90–140 English words.\n\n# 7. OCR and text-quality rules\n\nThe text may originate from PDF-to-JSON conversion or OCR and may contain misspellings, broken lines, page numbers, website navigation, repeated titles, watermarks, copyright notices, punctuation errors or incorrectly recognized numbers.\n\n1. Resolve obvious layout and OCR noise from context.\n2. Do not treat navigation text, copyright material, page numbers or similar noise as policy content.\n3. Do not silently correct substantively uncertain policy numbers.\n4. If a critical quantitative target cannot be read reliably, omit the uncertain number rather than reporting an erroneous value.\n5. Ignore minor OCR problems that do not affect interpretation.\n6. If re-extraction is necessary, consult the archived source-PDF directory associated with the project rather than adding external evidence.\n\n# 8. Prevent duplication across dimensions\n\nEach dimension answers a different question: goals describe what the policy seeks to change; instruments describe how; actors describe who steers, implements, regulates or participates; and temporal orientation describes the time structure. A statement such as “achieve carbon peaking by 2030” lies at the intersection of goals and time. In Goals, identify carbon peaking as the success state; in Temporal orientation, explain why 2030 is the milestone and how implementation proceeds before it. Avoid repeating the same sentence across all four fields.\n\n# 9. Information priority\n\nFor long documents, prioritize: explicit targets and quantitative indicators; principal governance mechanisms; representative core instruments; the steering and responsibility structure; critical time stages; and only then secondary projects or generic publicity language. Do not sacrifice structural synthesis in an attempt to cover every task.\n\n# 10. Style and length\n\nWrite objectively, analytically and with high information density. Use policy-research language, avoid value judgements and generic praise, and do not mechanically copy the source. Do not use formulations such as “the policy is highly significant”, “is conducive to” or “fully demonstrates”, unless such language itself constitutes the policy's explicit problem framing. Length guidance is flexible: completeness of the policy logic takes priority over mechanical compliance, and sparse documents may require shorter answers. Avoid exceeding approximately 250 English words for any one dimension."
OUTPUT_INSTRUCTION = 'Return one valid JSON object only. Do not include a Markdown code fence, heading, explanation or reasoning process. The keys must be exactly:\n{"Goals":"...","Instruments":"...","Actors":"...","Temporal":"..."}\nEach value must be a continuous analytical passage in polished English, without bullet points. Do not add information absent from the source text.'

def clean_text(value: Any) -> str:
    return str(value or '').strip()

def read_full_policy(path_value: Any) -> str:
    path_text = clean_text(path_value)
    if not path_text:
        raise ValueError('Textual location is empty.')
    path = Path(path_text)
    if not path.is_absolute():
        path = SOURCE_DIR / path
    if not path.exists():
        raise FileNotFoundError(path)
    obj = json.loads(path.read_text(encoding='utf-8'))
    for key in ('markdown', 'text', 'content', 'full_text'):
        value = obj.get(key)
        if value and clean_text(value):
            return clean_text(value)
    raise ValueError(f'No usable policy text was found in the JSON file: {path}')

def extract_json_object(text: str) -> dict[str, str]:
    raw = text.strip()
    if raw.startswith('```'):
        raw = re.sub('^```(?:json)?\\s*', '', raw, flags=re.I)
        raw = re.sub('\\s*```$', '', raw)
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        start, end = (raw.find('{'), raw.rfind('}'))
        if start < 0 or end <= start:
            raise ValueError('No JSON object was found in the model response.')
        obj = json.loads(raw[start:end + 1])
    aliases = {'Goals': ('Goals', 'goals', 'Policy goals', 'Policy_goals'), 'Instruments': ('Instruments', 'instruments', 'Policy instruments', 'Policy_instruments'), 'Actors': ('Actors', 'actors', 'Responsible actors', 'Responsible_actors'), 'Temporal': ('Temporal', 'temporal', 'Temporal orientation', 'Temporal_orientation')}
    result: dict[str, str] = {}
    for target, keys in aliases.items():
        value = next((obj.get(key) for key in keys if obj.get(key) is not None), None)
        value = clean_text(value)
        if not value:
            raise ValueError(f'The model response is missing fields: {target}')
        result[target] = value
    return result

def call_model(client: OpenAI, title: str, level: str, region: str, full_text: str) -> dict[str, str]:
    content = (
        ANALYSIS_PROMPT
        + '\n\n[POLICY METADATA FOR THIS REQUEST]\n'
        + f'Administrative level: {level}; Region: {region}; Policy title: {title}\n\n'
        + '[BEGIN COMPLETE POLICY TEXT]\n'
        + full_text
        + '\n[END COMPLETE POLICY TEXT]\n\n'
        + OUTPUT_INSTRUCTION
    )
    response = client.responses.create(
        model=MODEL,
        reasoning={'effort': REASONING_EFFORT},
        input=content,
        store=False,
    )
    return extract_json_object(response.output_text)

def atomic_save(workbook: openpyxl.Workbook, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = output_path.with_name(output_path.stem + '.tmp.xlsx')
    workbook.save(temp_path)
    os.replace(temp_path, output_path)

def append_error(record: dict[str, Any]) -> None:
    ERROR_LOG.parent.mkdir(parents=True, exist_ok=True)
    with ERROR_LOG.open('a', encoding='utf-8') as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + '\n')

def is_quota_error(error_text: str) -> bool:
    lowered = error_text.lower()
    return 'credit_balance_exhausted' in lowered or 'insufficient_quota' in lowered or 'no credits remaining' in lowered

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if not os.environ.get('OPENAI_API_KEY'):
        raise RuntimeError('The OPENAI_API_KEY environment variable is not set.')
    source_path = OUTPUT_XLSX if OUTPUT_XLSX.exists() else INPUT_XLSX
    workbook = openpyxl.load_workbook(source_path)
    worksheet = workbook[SHEET_NAME]
    headers = {clean_text(worksheet.cell(1, col).value): col for col in range(1, worksheet.max_column + 1)}
    required = ['Administrative level', 'Region name', 'Filename', 'Textual location', 'Goals', 'Instruments', 'Actors', 'Temporal']
    missing_headers = [name for name in required if name not in headers]
    if missing_headers:
        raise KeyError(f'Missing required columns: {missing_headers}')
    output_cols = {name: headers[name] for name in ('Goals', 'Instruments', 'Actors', 'Temporal')}
    pending: list[dict[str, Any]] = []
    for excel_row in range(2, worksheet.max_row + 1):
        title = clean_text(worksheet.cell(excel_row, headers['Filename']).value)
        location = clean_text(worksheet.cell(excel_row, headers['Textual location']).value)
        if not title and (not location):
            continue
        if all((clean_text(worksheet.cell(excel_row, output_cols[name]).value) for name in output_cols)):
            continue
        pending.append({'row': excel_row, 'title': title, 'level': clean_text(worksheet.cell(excel_row, headers['Administrative level']).value), 'region': clean_text(worksheet.cell(excel_row, headers['Region name']).value), 'location': location})
    print(f'Pending policy records: {len(pending)}; source workbook: {source_path}')
    if not pending:
        atomic_save(workbook, OUTPUT_XLSX)
        print(f'No new records require processing. Output: {OUTPUT_XLSX}')
        return
    client = OpenAI(api_key=os.environ['OPENAI_API_KEY'], timeout=180.0, max_retries=2)

    def run_one(item: dict[str, Any]) -> tuple[dict[str, Any], dict[str, str]]:
        full_text = read_full_policy(item['location'])
        result = call_model(client, item['title'], item['level'], item['region'], full_text)
        return (item, result)
    completed = 0
    failures: list[tuple[dict[str, Any], str]] = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        future_map = {pool.submit(run_one, item): item for item in pending}
        for future in as_completed(future_map):
            item = future_map[future]
            try:
                _, result = future.result()
                for name, col in output_cols.items():
                    worksheet.cell(item['row'], col).value = result[name]
                completed += 1
                print(f'Completed {completed}/{len(pending)}: Excel row {item["row"]}: {item["title"]}')
                if completed % CHECKPOINT_EVERY == 0:
                    atomic_save(workbook, OUTPUT_XLSX)
                    print(f'Checkpoint saved after {completed} successful records: {OUTPUT_XLSX}')
            except Exception as exc:
                failures.append((item, repr(exc)))
                append_error({'time': time.strftime('%Y-%m-%d %H:%M:%S'), **item, 'error': repr(exc)})
                print(f'Processing failed and will be retried: Excel row {item["row"]}: {exc}', file=sys.stderr)
    atomic_save(workbook, OUTPUT_XLSX)
    if failures and any((is_quota_error(error_text) for _, error_text in failures)):
        print(f'API quota exhausted. Current progress was saved: {completed} completed; {len(failures)} pending.')
        raise RuntimeError('API quota exhausted. Re-run the script after quota is restored; completed rows will be retained.')
    if failures:
        print(f'Retrying {len(failures)} failed records sequentially.')
        still_failed: list[tuple[dict[str, Any], str]] = []
        for item, _ in failures:
            try:
                _, result = run_one(item)
                for name, col in output_cols.items():
                    worksheet.cell(item['row'], col).value = result[name]
                completed += 1
                print(f'Retry succeeded: Excel row {item["row"]}: {item["title"]}')
                if completed % CHECKPOINT_EVERY == 0:
                    atomic_save(workbook, OUTPUT_XLSX)
                    print(f'Checkpoint saved after {completed} successful records: {OUTPUT_XLSX}')
            except Exception as exc:
                still_failed.append((item, repr(exc)))
                append_error({'time': time.strftime('%Y-%m-%d %H:%M:%S'), **item, 'retry_error': repr(exc)})
        failures = still_failed
    atomic_save(workbook, OUTPUT_XLSX)
    print(f'Final save completed: {completed} successful; {len(failures)} failed. Output: {OUTPUT_XLSX}')
    if failures:
        raise RuntimeError(f'{len(failures)} records remain incomplete. Re-run the script to resume. Error log: {ERROR_LOG}')
if __name__ == '__main__':
    main()
