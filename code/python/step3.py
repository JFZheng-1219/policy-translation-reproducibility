"""English reproducibility script for the three-stage policy analysis.

This file is an English-language derivative of the research script. It reads the translated workbook released in the same directory and never stores or prints the API key.
"""

from __future__ import annotations
import argparse
import hashlib
import json
import logging
import os
import re
import sys
import threading
import time
from concurrent.futures import FIRST_COMPLETED, Future, ThreadPoolExecutor, wait
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Literal
import openpyxl
from openai import OpenAI
from pydantic import BaseModel, ConfigDict, Field
REPO_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = REPO_ROOT / 'outputs' / 'llm'
INPUT_XLSX = OUTPUT_DIR / 'Results_step2_EN.xlsx'
OUTPUT_XLSX = OUTPUT_DIR / 'Results_step3_EN.xlsx'
SCRIPT_DIR = OUTPUT_DIR
MODEL_NAME = 'gpt-5.6-luna'
REASONING_EFFORT = 'medium'
SHEET_NAME = 'Sheet1'
CHECKPOINT_EVERY = 100
DEFAULT_WORKERS = 4
MAX_ATTEMPTS = 4
REQUEST_TIMEOUT_SECONDS = 300.0
LOG_FILE_NAME = 'step3.log'
ERROR_LOG_NAME = 'step3-errors.jsonl'
CHECKPOINT_FILE_NAME = 'step3-checkpoint.jsonl'
PREFLIGHT_FILE_NAME = 'step3-preflight.json'
CENTRAL_LEVEL = 'Central'
PROVINCE_LEVELS = {'Province', 'Autonomous region', 'Municipality'}
CITY_LEVELS = {'Provincial capital city', 'Sub-provincial city', 'Prefecture-level city'}
ELIGIBLE_LEVELS = PROVINCE_LEVELS | CITY_LEVELS
NONE_MARKERS = {'', 'no match', 'none', 'null', 'nan'}
REQUIRED_HEADERS = ['Administrative level', 'Region name', 'Filename', 'Matched_Parent_Files(center)', 'Matched_Parent_Files(province)', 'Goals', 'Instruments', 'Actors', 'Temporal', 'Goal_Score', 'Goal_Reason', 'Instrument_Score', 'Instrument_Reason', 'Actor_Score', 'Actor_Reason', 'Temporal_Score', 'Temporal_Reason', 'Goal_Score（CP)', 'Goal_Reason（CP)', 'Instrument_Score（CP)', 'Instrument_Reason（CP)', 'Actor_Score（CP)', 'Actor_Reason（CP)', 'Temporal_Score（CP)', 'Temporal_Reason（CP)']
DIMENSION_HEADERS = ('Goals', 'Instruments', 'Actors', 'Temporal')
CENTRAL_OUTPUT_HEADERS = ('Goal_Score', 'Goal_Reason', 'Instrument_Score', 'Instrument_Reason', 'Actor_Score', 'Actor_Reason', 'Temporal_Score', 'Temporal_Reason')
PROVINCE_OUTPUT_HEADERS = ('Goal_Score（CP)', 'Goal_Reason（CP)', 'Instrument_Score（CP)', 'Instrument_Reason（CP)', 'Actor_Score（CP)', 'Actor_Reason（CP)', 'Temporal_Score（CP)', 'Temporal_Reason（CP)')
TITLE_CORRECTIONS = {}
DUPLICATE_TITLE_ROW_OVERRIDES = {'Plan for Guangxi ecological and environmental protection the 14th Five-Year Plan': 511}
SCORING_PROMPT = "You are a public-policy scholar with extensive expertise in climate change, carbon peaking and carbon neutrality, ecological and environmental governance, energy transitions, carbon markets, climate adaptation and local policy implementation in China. Your task is to assess the substantive policy alignment between a local policy and its already matched superior-level policy or policy collection.\n\nThis is not a text-similarity exercise. Do not score on the basis of keyword overlap, title similarity, wording similarity or superficial sentence resemblance. Use only the supplied four-dimensional policy summaries to determine whether the local policy inherits, specifies, strengthens, partially carries forward, omits, weakens or substantively departs from superior-level requirements. Every score must be an integer from 1 to 5. Do not return decimals, percentages, letter grades or any other format.\n\n# 1. Unit of comparison\n\nEvaluate each local policy once. A local policy may be matched to several central policies and/or several provincial policies. Do not score each superior policy separately and then average the results. Do not reduce the score merely because the superior-policy collection contains many documents. Treat all relevant superior policies at a given level as one policy collection.\n\nWhen a comprehensive superior policy contains material outside the substantive scope of the local specialized policy, do not penalize the local policy for omitting that irrelevant material. For example, a local building-energy-efficiency policy should not lose points because it does not reproduce agricultural mitigation provisions from a comprehensive central climate policy.\n\n# 2. Local specification and directional departure\n\nA local policy may depart from the wording of the superior policy while remaining substantively compatible. At the beginning of each reason, identify the direction as `Positive restructuring`, `Negative drift` or `No directional restructuring`, according to the evidence.\n\nPositive restructuring includes converting a superior-level principle into concrete measures, adding local implementing departments, specifying responsibility, introducing compatible and earlier deadlines, quantifying a broad requirement, or otherwise detailing an implementation pathway without changing the superior policy's core direction. Such specification or strengthening is not a reason to lower the alignment score.\n\nNegative drift includes materially weakening a core objective, omitting an important policy instrument, altering a core mechanism, breaking the responsibility chain, removing a key implementing actor, materially postponing a mandatory deadline, contradicting the superior policy's implementation logic, or another substantive departure.\n\nUse `No directional restructuring` where the local policy preserves the relevant superior-level requirements without material strengthening or weakening, or where the supplied evidence does not support a directional judgement. A policy dimension may contain both positive and negative changes. In that case, identify both, determine which has greater substantive importance for the dimension and assign the alignment score on the basis of the net substantive relationship rather than counting changes mechanically.\n\n# 3. Common 1–5 Likert scale\n\n5 = Highly aligned. The local policy fully or almost fully carries forward the superior policy's core requirements that are relevant to the local policy's scope. The principal direction, core content and implementation logic are highly aligned. The local policy may further specify, quantify, detail or strengthen those requirements. No material weakening or conflict is present.\n\n4 = Substantially aligned. The local policy carries forward most core requirements and retains the overall direction and principal objectives or implementation mechanisms. Minor content is omitted, the scope is somewhat narrower, implementation detail is limited, or emphasis differs, but the core policy logic is unchanged and no material conflict is present.\n\n3 = Partially aligned. The local policy has clear and substantive overlap with the superior policy but carries forward only part of the core requirements, or materially omits or adjusts important objectives, instruments, actors or time arrangements. It combines policy inheritance with consequential differences and cannot be classified as highly or substantially aligned.\n\n2 = Weakly aligned. Only part of the theme, a few objectives or a few measures correspond to the superior policy. Most core requirements are not substantively carried forward, or the key instruments, responsibility structure, objective system or temporal arrangements differ markedly.\n\n1 = Clearly misaligned. The local policy has little substantive correspondence with the core requirements of the relevant superior policy, or it introduces contrary arrangements, material weakening, conflicting objectives or responsibility structures, removal of a core mechanism, or clearly incompatible mandatory deadlines.\n\n# 4. Multiple superior policies\n\nNever score individual superior policies and average the results. Identify the requirements across the superior-policy collection that are relevant to the current local policy. If one superior document establishes objectives, another instruments and another responsibilities, integrate them into one complete reference. If the superior documents differ, prioritize the requirements that are most directly relevant to the local policy, institutionally authoritative and substantively explicit, and briefly indicate that prioritization in the reason.\n\n# 5. Reasons\n\nFor each dimension, provide a concise, auditable reason of approximately 45–90 English words. The reason must:\n1. identify the specific respects in which the local policy aligns with the superior policy collection;\n2. if the score is below 5, identify the most important omission, weakening or other difference;\n3. refer to concrete objectives, mechanisms, actors or time points contained in the supplied summaries; and\n4. provide enough substantive evidence to justify the score.\n\nDo not write only “highly aligned”, “basically aligned”, “substantially aligned” or “partially aligned”. Do not reveal internal reasoning or chain-of-thought. Return only the final score and concise evidentiary reason required by the structured output.\n\n# 6. Evidence restriction\n\nUse only the local and superior-policy four-dimensional summaries included in the current request. Do not use external knowledge, reconstruct content from an unseen original policy, or add facts merely because they are familiar from national policy."

class DimensionScores(BaseModel):
    model_config = ConfigDict(extra='forbid')
    goal_score: Literal[1, 2, 3, 4, 5]
    goal_reason: str = Field(min_length=20, max_length=800)
    instrument_score: Literal[1, 2, 3, 4, 5]
    instrument_reason: str = Field(min_length=20, max_length=800)
    actor_score: Literal[1, 2, 3, 4, 5]
    actor_reason: str = Field(min_length=20, max_length=800)
    temporal_score: Literal[1, 2, 3, 4, 5]
    temporal_reason: str = Field(min_length=20, max_length=800)

class ScoringResponse(BaseModel):
    model_config = ConfigDict(extra='forbid')
    central: DimensionScores | None
    province: DimensionScores | None

@dataclass(frozen=True)
class PolicyRecord:
    row: int
    level: str
    region: str
    filename: str
    goals: str
    instruments: str
    actors: str
    temporal: str

    def api_dict(self) -> dict[str, str]:
        return {'filename': self.filename, 'administrative_level': self.level, 'region_name': self.region, 'goals': self.goals, 'instruments': self.instruments, 'actors': self.actors, 'temporal': self.temporal}

@dataclass(frozen=True)
class ScoringTask:
    row: int
    local: PolicyRecord
    central_parents: tuple[PolicyRecord, ...]
    province_parents: tuple[PolicyRecord, ...]
    fingerprint: str

    @property
    def needs_central(self) -> bool:
        return bool(self.central_parents)

    @property
    def needs_province(self) -> bool:
        return bool(self.province_parents)

def clean_text(value: Any) -> str:
    if value is None:
        return ''
    return str(value).strip()

def split_parent_titles(value: Any) -> list[str]:
    """Split only on the delimiters specified for multi-file cells.

    The Chinese list separator '、' is intentionally not a delimiter because it
    can be part of an official policy title.
    """
    raw = clean_text(value)
    if raw.lower() in NONE_MARKERS:
        return []
    parts = [part.strip() for part in re.split('[；;\\r\\n]+', raw) if part.strip()]
    return [part for part in parts if part.lower() not in NONE_MARKERS]

def stable_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))

def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()

def atomic_save(workbook: openpyxl.Workbook, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = output_path.with_name(output_path.stem + '.tmp.xlsx')
    workbook.save(temp_path)
    os.replace(temp_path, output_path)

def append_jsonl(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a', encoding='utf-8') as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + '\n')
        handle.flush()
        os.fsync(handle.fileno())

def configure_logging(log_path: Path) -> logging.Logger:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger('step3')
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s')
    file_handler = logging.FileHandler(log_path, encoding='utf-8')
    file_handler.setFormatter(formatter)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    return logger

def header_map(worksheet: openpyxl.worksheet.worksheet.Worksheet) -> dict[str, int]:
    headers = {clean_text(worksheet.cell(1, column).value): column for column in range(1, worksheet.max_column + 1)}
    missing = [name for name in REQUIRED_HEADERS if name not in headers]
    if missing:
        raise KeyError(f'Sheet1 is missing required columns: {missing}')
    return headers

def record_from_row(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int], row: int) -> PolicyRecord:
    return PolicyRecord(row=row, level=clean_text(worksheet.cell(row, headers['Administrative level']).value), region=clean_text(worksheet.cell(row, headers['Region name']).value), filename=clean_text(worksheet.cell(row, headers['Filename']).value), goals=clean_text(worksheet.cell(row, headers['Goals']).value), instruments=clean_text(worksheet.cell(row, headers['Instruments']).value), actors=clean_text(worksheet.cell(row, headers['Actors']).value), temporal=clean_text(worksheet.cell(row, headers['Temporal']).value))

def build_title_index(records: list[PolicyRecord]) -> dict[str, list[PolicyRecord]]:
    index: dict[str, list[PolicyRecord]] = {}
    for record in records:
        if record.filename:
            index.setdefault(record.filename, []).append(record)
    return index

def same_dimensions(records: list[PolicyRecord]) -> bool:
    if not records:
        return False
    first = (records[0].goals, records[0].instruments, records[0].actors, records[0].temporal)
    return all(((record.goals, record.instruments, record.actors, record.temporal) == first for record in records[1:]))

def resolve_parent(title: str, expected_group: Literal['central', 'province'], title_index: dict[str, list[PolicyRecord]]) -> PolicyRecord:
    candidates = title_index.get(title, [])
    if expected_group == 'central':
        candidates = [record for record in candidates if record.level == CENTRAL_LEVEL]
    else:
        candidates = [record for record in candidates if record.level in PROVINCE_LEVELS]
    if not candidates:
        raise ValueError(f'Parent title not found at the expected {expected_group} administrative level: {title}')
    if len(candidates) > 1:
        override_row = DUPLICATE_TITLE_ROW_OVERRIDES.get(title)
        if override_row is not None:
            selected = next((record for record in candidates if record.row == override_row), None)
            if selected is None:
                rows = [record.row for record in candidates]
                raise ValueError(f'The configured duplicate-title override is invalid for {title}: selected row={override_row}; candidate rows={rows}')
            return selected
        if not same_dimensions(candidates):
            rows = [record.row for record in candidates]
            raise ValueError(f'The title maps to multiple rows with different four-dimensional summaries and cannot be resolved uniquely: {title}; rows={rows}')
    return candidates[0]

def normalize_parent_cell(worksheet: openpyxl.worksheet.worksheet.Worksheet, row: int, column: int, correction_log: list[dict[str, Any]]) -> list[str]:
    raw_value = worksheet.cell(row, column).value
    raw_titles = split_parent_titles(raw_value)
    if not raw_titles:
        return []
    corrected_titles: list[str] = []
    for raw_title in raw_titles:
        corrected = TITLE_CORRECTIONS.get(raw_title, raw_title)
        if corrected != raw_title:
            correction_log.append({'row': row, 'column': column, 'original': raw_title, 'corrected': corrected})
        if corrected not in corrected_titles:
            corrected_titles.append(corrected)
    if corrected_titles != raw_titles:
        worksheet.cell(row, column).value = '；'.join(corrected_titles)
    return corrected_titles

def make_task_fingerprint(local: PolicyRecord, central_parents: tuple[PolicyRecord, ...], province_parents: tuple[PolicyRecord, ...]) -> str:
    payload = {'model': MODEL_NAME, 'reasoning_effort': REASONING_EFFORT, 'local': local.api_dict(), 'central_parents': [record.api_dict() for record in central_parents], 'province_parents': [record.api_dict() for record in province_parents], 'prompt_sha256': hashlib.sha256(SCORING_PROMPT.encode('utf-8')).hexdigest()}
    return hashlib.sha256(stable_json(payload).encode('utf-8')).hexdigest()

def prepare_tasks(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int]) -> tuple[list[ScoringTask], dict[str, Any]]:
    records = [record_from_row(worksheet, headers, row) for row in range(2, worksheet.max_row + 1)]
    title_index = build_title_index(records)
    correction_log: list[dict[str, Any]] = []
    dropped_wrong_level: list[dict[str, Any]] = []
    duplicate_resolutions: list[dict[str, Any]] = []
    issues: list[dict[str, Any]] = []
    tasks: list[ScoringTask] = []
    no_parent_rows: list[int] = []
    center_col = headers['Matched_Parent_Files(center)']
    province_col = headers['Matched_Parent_Files(province)']
    for local in records:
        if local.level == CENTRAL_LEVEL:
            clear_block(worksheet, headers, local.row, CENTRAL_OUTPUT_HEADERS)
            clear_block(worksheet, headers, local.row, PROVINCE_OUTPUT_HEADERS)
            continue
        if local.level not in ELIGIBLE_LEVELS:
            continue
        missing_local_dimensions = [name for name, value in zip(DIMENSION_HEADERS, (local.goals, local.instruments, local.actors, local.temporal)) if not value]
        if missing_local_dimensions:
            issues.append({'row': local.row, 'filename': local.filename, 'type': 'missing_local_dimensions', 'details': missing_local_dimensions})
            continue
        central_titles = normalize_parent_cell(worksheet, local.row, center_col, correction_log)
        province_titles = normalize_parent_cell(worksheet, local.row, province_col, correction_log) if local.level in CITY_LEVELS else []
        if local.level in PROVINCE_LEVELS:
            clear_block(worksheet, headers, local.row, PROVINCE_OUTPUT_HEADERS)
        central_parents: list[PolicyRecord] = []
        province_parents: list[PolicyRecord] = []
        for group, titles, destination, column in (('central', central_titles, central_parents, center_col), ('province', province_titles, province_parents, province_col)):
            for title in titles:
                try:
                    parent = resolve_parent(title, group, title_index)
                except ValueError as exc:
                    all_candidates = title_index.get(title, [])
                    valid_level_candidates = [record for record in all_candidates if group == 'central' and record.level == CENTRAL_LEVEL or (group == 'province' and record.level in PROVINCE_LEVELS)]
                    if all_candidates and (not valid_level_candidates):
                        dropped_wrong_level.append({'row': local.row, 'filename': local.filename, 'group': group, 'title': title, 'actual_levels': sorted({record.level for record in all_candidates}), 'actual_rows': [record.row for record in all_candidates]})
                        continue
                    issues.append({'row': local.row, 'filename': local.filename, 'type': 'parent_resolution_error', 'group': group, 'title': title, 'details': str(exc)})
                    continue
                missing_parent_dimensions = [name for name, value in zip(DIMENSION_HEADERS, (parent.goals, parent.instruments, parent.actors, parent.temporal)) if not value]
                if missing_parent_dimensions:
                    issues.append({'row': local.row, 'filename': local.filename, 'type': 'missing_parent_dimensions', 'group': group, 'parent_title': title, 'parent_row': parent.row, 'details': missing_parent_dimensions})
                    continue
                destination.append(parent)
                override_row = DUPLICATE_TITLE_ROW_OVERRIDES.get(title)
                if override_row is not None and len(title_index.get(title, [])) > 1:
                    duplicate_resolutions.append({'local_row': local.row, 'local_filename': local.filename, 'title': title, 'selected_parent_row': override_row})
            if titles:
                valid_titles = []
                for record in destination:
                    if record.filename not in valid_titles:
                        valid_titles.append(record.filename)
                worksheet.cell(local.row, column).value = '；'.join(valid_titles) if valid_titles else 'No match'
        if not central_parents:
            clear_block(worksheet, headers, local.row, CENTRAL_OUTPUT_HEADERS)
        if local.level in CITY_LEVELS and (not province_parents):
            clear_block(worksheet, headers, local.row, PROVINCE_OUTPUT_HEADERS)
        if issues and any((issue['row'] == local.row for issue in issues)):
            continue
        if not central_parents and (not province_parents):
            no_parent_rows.append(local.row)
            continue
        central_tuple = tuple(central_parents)
        province_tuple = tuple(province_parents)
        tasks.append(ScoringTask(row=local.row, local=local, central_parents=central_tuple, province_parents=province_tuple, fingerprint=make_task_fingerprint(local, central_tuple, province_tuple)))
    report = {'generated_at': utc_now(), 'input_rows': worksheet.max_row - 1, 'eligible_rows': sum((record.level in ELIGIBLE_LEVELS for record in records)), 'city_rows': sum((record.level in CITY_LEVELS for record in records)), 'api_tasks': len(tasks), 'central_comparisons': sum((task.needs_central for task in tasks)), 'province_comparisons': sum((task.needs_province for task in tasks)), 'rows_without_matched_parents': no_parent_rows, 'title_corrections': correction_log, 'dropped_wrong_level_parent_references': dropped_wrong_level, 'duplicate_parent_resolutions': duplicate_resolutions, 'issues': issues}
    return (tasks, report)

def clear_block(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int], row: int, names: tuple[str, ...]) -> None:
    for name in names:
        worksheet.cell(row, headers[name]).value = None

def score_block_values(result: DimensionScores) -> tuple[Any, ...]:
    return (result.goal_score, result.goal_reason.strip(), result.instrument_score, result.instrument_reason.strip(), result.actor_score, result.actor_reason.strip(), result.temporal_score, result.temporal_reason.strip())

def write_block(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int], row: int, names: tuple[str, ...], result: DimensionScores) -> None:
    for name, value in zip(names, score_block_values(result)):
        worksheet.cell(row, headers[name]).value = value

def valid_score(value: Any) -> bool:
    if isinstance(value, bool):
        return False
    try:
        return int(value) in {1, 2, 3, 4, 5} and float(value) == int(value)
    except (TypeError, ValueError):
        return False

def block_complete(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int], row: int, names: tuple[str, ...]) -> bool:
    values = [worksheet.cell(row, headers[name]).value for name in names]
    return all((valid_score(values[index]) for index in (0, 2, 4, 6))) and all((bool(clean_text(values[index])) for index in (1, 3, 5, 7)))

def task_complete(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int], task: ScoringTask) -> bool:
    central_done = not task.needs_central or block_complete(worksheet, headers, task.row, CENTRAL_OUTPUT_HEADERS)
    province_done = not task.needs_province or block_complete(worksheet, headers, task.row, PROVINCE_OUTPUT_HEADERS)
    return central_done and province_done

def validate_response(task: ScoringTask, result: ScoringResponse) -> None:
    if task.needs_central and result.central is None:
        raise ValueError('A central comparison is required, but `central` is null in the structured output.')
    if not task.needs_central and result.central is not None:
        raise ValueError('No central comparison is required, but the model returned a `central` result.')
    if task.needs_province and result.province is None:
        raise ValueError('A provincial comparison is required, but `province` is null in the structured output.')
    if not task.needs_province and result.province is not None:
        raise ValueError('No provincial comparison is required, but the model returned a `province` result.')

def apply_response(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int], task: ScoringTask, result: ScoringResponse) -> None:
    validate_response(task, result)
    if result.central is not None:
        write_block(worksheet, headers, task.row, CENTRAL_OUTPUT_HEADERS, result.central)
    if result.province is not None:
        write_block(worksheet, headers, task.row, PROVINCE_OUTPUT_HEADERS, result.province)

def make_api_input(task: ScoringTask) -> str:
    payload = {'comparison_request': {'score_against_central_collection': task.needs_central, 'score_against_province_collection': task.needs_province, 'output_rule': '`central` contains scores against the central-policy collection and `province` contains scores against the provincial-policy collection. Return null for any comparison not required for this row. Do not output the reasoning process.'}, 'local_policy': task.local.api_dict(), 'central_parent_policy_collection': [parent.api_dict() for parent in task.central_parents], 'province_parent_policy_collection': [parent.api_dict() for parent in task.province_parents]}
    return 'The following JSON contains the only four-dimensional policy content permitted for this assessment. Treat each superior-policy collection as one integrated reference; do not score individual policies or average separate scores.\n' + json.dumps(payload, ensure_ascii=False, indent=2)
_thread_local = threading.local()

def get_client() -> OpenAI:
    client = getattr(_thread_local, 'client', None)
    if client is None:
        client = OpenAI(timeout=REQUEST_TIMEOUT_SECONDS, max_retries=0)
        _thread_local.client = client
    return client

def usage_dict(response: Any) -> dict[str, Any]:
    usage = getattr(response, 'usage', None)
    if usage is None:
        return {}
    details = getattr(usage, 'output_tokens_details', None)
    return {'input_tokens': getattr(usage, 'input_tokens', None), 'output_tokens': getattr(usage, 'output_tokens', None), 'total_tokens': getattr(usage, 'total_tokens', None), 'reasoning_tokens': getattr(details, 'reasoning_tokens', None) if details else None}

def call_api(task: ScoringTask) -> tuple[ScoringResponse, dict[str, Any]]:
    last_error: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response = get_client().responses.parse(model=MODEL_NAME, reasoning={'effort': REASONING_EFFORT}, instructions=SCORING_PROMPT, input=make_api_input(task), text_format=ScoringResponse, store=False)
            parsed = response.output_parsed
            if parsed is None:
                status = getattr(response, 'status', 'unknown')
                raise ValueError(f'The API did not return parseable structured output; status={status}')
            validate_response(task, parsed)
            metadata = {'response_id': getattr(response, 'id', None), 'usage': usage_dict(response), 'attempt': attempt}
            return (parsed, metadata)
        except Exception as exc:
            last_error = exc
            if attempt >= MAX_ATTEMPTS:
                break
            time.sleep(min(30, 2 ** attempt))
    assert last_error is not None
    raise last_error

def is_fatal_api_error(exc: Exception) -> bool:
    text = str(exc).lower()
    markers = ('invalid_api_key', 'incorrect api key', 'insufficient_quota', 'credit_balance_exhausted', 'no credits remaining', 'model_not_found', 'does not have access to model')
    return any((marker in text for marker in markers))

def checkpoint_record(task: ScoringTask, result: ScoringResponse, metadata: dict[str, Any]) -> dict[str, Any]:
    return {'status': 'success', 'timestamp': utc_now(), 'model': MODEL_NAME, 'reasoning_effort': REASONING_EFFORT, 'row': task.row, 'filename': task.local.filename, 'fingerprint': task.fingerprint, 'needs_central': task.needs_central, 'needs_province': task.needs_province, 'result': result.model_dump(mode='json'), **metadata}

def load_checkpoint(path: Path) -> dict[int, dict[str, Any]]:
    latest: dict[int, dict[str, Any]] = {}
    if not path.exists():
        return latest
    with path.open('r', encoding='utf-8') as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                record = json.loads(line)
                if record.get('status') == 'success':
                    latest[int(record['row'])] = record
            except Exception as exc:
                raise ValueError(f'Checkpoint line {line_number} is invalid: {exc}') from exc
    return latest

def replay_checkpoint(worksheet: openpyxl.worksheet.worksheet.Worksheet, headers: dict[str, int], tasks: list[ScoringTask], checkpoint_path: Path, logger: logging.Logger) -> int:
    latest = load_checkpoint(checkpoint_path)
    replayed = 0
    for task in tasks:
        record = latest.get(task.row)
        if not record or record.get('fingerprint') != task.fingerprint:
            continue
        try:
            result = ScoringResponse.model_validate(record['result'])
            apply_response(worksheet, headers, task, result)
            replayed += 1
        except Exception as exc:
            logger.warning('Ignoring invalid checkpoint data for Excel row %s: %s', task.row, exc)
    return replayed

def validate_resume_source(input_path: Path, output_path: Path, output_workbook: openpyxl.Workbook) -> None:
    if not output_path.exists():
        return
    source_workbook = openpyxl.load_workbook(input_path, read_only=True, data_only=False)
    try:
        source = source_workbook[SHEET_NAME]
        output = output_workbook[SHEET_NAME]
        if source.max_row != output.max_row or source.max_column != output.max_column:
            raise ValueError('The existing Results_step3_EN.xlsx has different dimensions from the current input workbook.')
        compare_indexes = list(range(0, 6)) + list(range(8, 12))
        source_rows = source.iter_rows(values_only=True)
        output_rows = output.iter_rows(values_only=True)
        for row_number, (source_row, output_row) in enumerate(zip(source_rows, output_rows), 1):
            for index in compare_indexes:
                if source_row[index] != output_row[index]:
                    raise ValueError(f'The existing Results_step3_EN.xlsx is incompatible with the input workbook at row {row_number}, column {index + 1}.')
    finally:
        source_workbook.close()

def select_workbook(input_path: Path, output_path: Path) -> openpyxl.Workbook:
    if output_path.exists():
        workbook = openpyxl.load_workbook(output_path)
        validate_resume_source(input_path, output_path, workbook)
        return workbook
    return openpyxl.load_workbook(input_path)

def write_preflight_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Four-dimensional central–provincial–municipal policy-alignment scoring (GPT-5.6 Luna).')
    parser.add_argument('--input', type=Path, default=INPUT_XLSX)
    parser.add_argument('--output', type=Path, default=OUTPUT_XLSX)
    parser.add_argument('--state-dir', type=Path, default=SCRIPT_DIR)
    parser.add_argument('--workers', type=int, default=DEFAULT_WORKERS)
    parser.add_argument('--limit', type=int, default=None, help='Process only the first N pending rows.')
    parser.add_argument('--preflight-only', action='store_true', help='Validate inputs without calling the API.')
    parser.add_argument('--dry-run', action='store_true', help='Build requests without calling the API or saving Excel output.')
    return parser.parse_args()

def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    args = parse_args()
    state_dir = args.state_dir.resolve()
    logger = configure_logging(state_dir / LOG_FILE_NAME)
    error_log = state_dir / ERROR_LOG_NAME
    checkpoint_path = state_dir / CHECKPOINT_FILE_NAME
    preflight_path = state_dir / PREFLIGHT_FILE_NAME
    if not args.input.exists():
        raise FileNotFoundError(args.input)
    if args.workers < 1:
        raise ValueError('--workers must be at least 1.')
    workbook = select_workbook(args.input, args.output)
    if SHEET_NAME not in workbook.sheetnames:
        raise KeyError(f'The workbook does not contain {SHEET_NAME}.')
    worksheet = workbook[SHEET_NAME]
    headers = header_map(worksheet)
    tasks, report = prepare_tasks(worksheet, headers)
    write_preflight_report(preflight_path, report)
    logger.info('Preflight: data rows=%s; scoring tasks=%s; central comparisons=%s; provincial comparisons=%s; title corrections=%s; wrong-level references removed=%s; duplicate-title resolutions=%s; issues=%s', report['input_rows'], report['api_tasks'], report['central_comparisons'], report['province_comparisons'], len(report['title_corrections']), len(report['dropped_wrong_level_parent_references']), len(report['duplicate_parent_resolutions']), len(report['issues']))
    if report['issues']:
        logger.error('Preflight failed. See: %s', preflight_path)
        return 2
    if args.preflight_only:
        logger.info('Preflight passed; no API call was made and no result workbook was saved.')
        return 0
    if not os.environ.get('OPENAI_API_KEY'):
        raise RuntimeError('The Windows environment variable OPENAI_API_KEY is not set.')
    replayed = replay_checkpoint(worksheet, headers, tasks, checkpoint_path, logger)
    if replayed:
        logger.info('Restored %s valid rows from the checkpoint.', replayed)
    all_pending = [task for task in tasks if not task_complete(worksheet, headers, task)]
    completed_before_run = len(tasks) - len(all_pending)
    pending = all_pending
    if args.limit is not None:
        pending = pending[:max(0, args.limit)]
    logger.info('Tasks already completed or restored=%s; total remaining=%s; API calls in this run=%s', completed_before_run, len(all_pending), len(pending))
    if args.dry_run:
        lengths = [len(make_api_input(task)) for task in pending]
        logger.info('Dry run passed: requests=%s; total input characters=%s; maximum request size=%s; no API call was made.', len(pending), sum(lengths), max(lengths, default=0))
        return 0
    if not pending:
        atomic_save(workbook, args.output)
        logger.info('No pending records. Output saved: %s', args.output)
        return 0
    successes = 0
    failures = 0
    logger.info('Starting API scoring: model=%s; reasoning=%s; workers=%s', MODEL_NAME, REASONING_EFFORT, args.workers)
    try:
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            task_iter = iter(pending)
            future_map: dict[Future[tuple[ScoringResponse, dict[str, Any]]], ScoringTask] = {}
            for _ in range(min(args.workers, len(pending))):
                task = next(task_iter)
                future_map[executor.submit(call_api, task)] = task
            stop_scheduling = False
            while future_map:
                done, _ = wait(future_map, return_when=FIRST_COMPLETED)
                for future in done:
                    task = future_map.pop(future)
                    try:
                        result, metadata = future.result()
                        event = checkpoint_record(task, result, metadata)
                        append_jsonl(checkpoint_path, event)
                        apply_response(worksheet, headers, task, result)
                        successes += 1
                        logger.info('Completed %s/%s: Excel row %s: %s', successes + failures, len(pending), task.row, task.local.filename)
                        if successes % CHECKPOINT_EVERY == 0:
                            atomic_save(workbook, args.output)
                            logger.info('Saved checkpoint after %s successful results: %s', successes, args.output)
                    except Exception as exc:
                        failures += 1
                        append_jsonl(error_log, {'timestamp': utc_now(), 'row': task.row, 'filename': task.local.filename, 'fingerprint': task.fingerprint, 'error_type': type(exc).__name__, 'error': str(exc)})
                        logger.error('Failed: Excel row %s: %s: %s', task.row, task.local.filename, exc)
                        if is_fatal_api_error(exc):
                            stop_scheduling = True
                            logger.critical('A fatal API-key, quota or model-permission error was detected; no further requests will be submitted.')
                    if not stop_scheduling:
                        try:
                            next_task = next(task_iter)
                        except StopIteration:
                            pass
                        else:
                            future_map[executor.submit(call_api, next_task)] = next_task
    except KeyboardInterrupt:
        logger.warning('An interruption signal was received; completed results are being saved.')
        atomic_save(workbook, args.output)
        return 130
    atomic_save(workbook, args.output)
    logger.info('Run completed: successful=%s; failed=%s; output=%s. Re-run the script to resume failed rows.', successes, failures, args.output)
    return 1 if failures else 0
if __name__ == '__main__':
    raise SystemExit(main())
