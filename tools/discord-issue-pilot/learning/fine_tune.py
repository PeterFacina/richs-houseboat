"""Run local Qwen QLoRA with a private inbox, fixed evaluation set and separate Ollama tags."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
from urllib.request import Request, urlopen
from uuid import uuid4


HERE = Path(__file__).resolve().parent
FIELDS = ('objective', 'observations', 'tasks', 'verification', 'acceptance', 'unknowns')


def timestamp():
    return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def save_json(path, value):
    temporary = path.with_name(f'.{path.name}.{uuid4().hex}.tmp')
    try:
        temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def run_tool(args, timeout=60):
    return subprocess.run([str(value) for value in args], check=True, capture_output=True, text=True,
                          encoding='utf-8', timeout=timeout,
                          creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).stdout


def ollama(path, data=None, timeout=90):
    body = None if data is None else json.dumps(data).encode('utf-8')
    request = Request('http://127.0.0.1:11434/api/' + path, data=body,
                      headers={'Content-Type': 'application/json'})
    with urlopen(request, timeout=timeout) as response:
        return json.load(response)


@contextmanager
def gpu_lock(home):
    path = home / 'gpu-activity.sqlite'
    if not path.is_file():
        raise RuntimeError('The production worker has not initialized the shared GPU lock.')
    database = sqlite3.connect(path, timeout=0)
    try:
        database.execute('BEGIN IMMEDIATE')
        yield
    finally:
        database.close()


def read_holdout(path):
    rows = read_json(path)
    ids = {row['issue'] for row in rows}
    if len(ids) != len(rows) or len(ids) < 3 or any(not isinstance(issue, int) or issue <= 0 for issue in ids):
        raise ValueError('Use at least three distinct whole GitHub issues in the fixed evaluation set.')
    for row in rows:
        if not isinstance(row.get('messages'), list) or not row['messages'] or any(
            item.get('role') not in ('system', 'user') or not isinstance(item.get('content'), str)
            for item in row['messages']
        ):
            raise ValueError('Holdout messages must contain the original system and user inputs.')
        if not row.get('required') or any(not isinstance(x, str) or not x.strip()
                                         for x in row['required'] + row.get('forbidden', [])):
            raise ValueError('Every holdout case needs explicit evidence-based scoring criteria.')
    return rows, ids


def train_adapter(examples, config, run, publish):
    import torch
    from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
    from transformers import (AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig,
                              Trainer, TrainerCallback, TrainingArguments)
    from transformers.trainer_utils import get_last_checkpoint

    if not torch.cuda.is_available() or not torch.cuda.is_bf16_supported():
        raise RuntimeError('A CUDA runtime with bfloat16 support is required for this QLoRA profile.')
    base = config['baseModel']
    revision = config['baseRevision']
    tokenizer = AutoTokenizer.from_pretrained(base, revision=revision, trust_remote_code=False)
    tokenizer.save_pretrained(run / 'base-config')
    model = AutoModelForCausalLM.from_pretrained(base, revision=revision, trust_remote_code=False,
        quantization_config=BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type='nf4',
            bnb_4bit_compute_dtype=torch.bfloat16, bnb_4bit_use_double_quant=True),
        device_map={'': 0}, attn_implementation='sdpa')
    model.config.save_pretrained(run / 'base-config')
    model.config.use_cache = False
    model = get_peft_model(prepare_model_for_kbit_training(model), LoraConfig(
        r=8, lora_alpha=16, lora_dropout=.05, target_modules=['q_proj', 'k_proj', 'v_proj', 'o_proj'],
        task_type='CAUSAL_LM'))

    def encode(item):
        messages = item['messages']
        prefix = tokenizer.apply_chat_template(messages[:-1], tokenize=False,
                                               add_generation_prompt=True, enable_thinking=False)
        target = messages[-1]['content'] + '<|im_end|>\n'
        prompt_ids = tokenizer(prefix, add_special_tokens=False)['input_ids']
        response_ids = tokenizer(target, add_special_tokens=False)['input_ids']
        if len(prompt_ids) + len(response_ids) > config['maxTokens']:
            return None
        return {'input_ids': prompt_ids + response_ids, 'labels': [-100] * len(prompt_ids) + response_ids}

    encoded = [row for item in examples if (row := encode(item)) is not None]
    if len(encoded) < config['minExamples']:
        raise ValueError('Too few approved examples fit without truncating their evidence or target.')

    def collate(rows):
        width = max(len(row['input_ids']) for row in rows)
        padded = [width - len(row['input_ids']) for row in rows]
        return {key: torch.tensor(value) for key, value in {
            'input_ids': [row['input_ids'] + [tokenizer.pad_token_id] * n for row, n in zip(rows, padded)],
            'labels': [row['labels'] + [-100] * n for row, n in zip(rows, padded)],
            'attention_mask': [[1] * len(row['input_ids']) + [0] * n for row, n in zip(rows, padded)],
        }.items()}

    class Progress(TrainerCallback):
        def on_step_end(self, args, state, control, **kwargs):
            publish('training', examples=len(encoded), step=state.global_step, steps=state.max_steps)

    checkpoints = run / 'checkpoints'
    checkpoints.mkdir(exist_ok=True)
    trainer = Trainer(model=model, train_dataset=encoded, data_collator=collate, callbacks=[Progress()],
        args=TrainingArguments(output_dir=str(checkpoints), per_device_train_batch_size=1,
            gradient_accumulation_steps=4, gradient_checkpointing=True, bf16=True, learning_rate=1e-4,
            optim='paged_adamw_8bit', num_train_epochs=config['epochs'], report_to=[], save_steps=5,
            save_total_limit=2, seed=42, logging_steps=5, max_grad_norm=1.0))
    trainer.train(resume_from_checkpoint=get_last_checkpoint(str(checkpoints)))
    trainer.save_model(run / 'adapter')


def score(text, case):
    try:
        obj = json.loads(text)
        if any(not isinstance(obj.get(field), list) or not obj[field] or
               any(not isinstance(item, str) or not item.strip() for item in obj[field]) for field in FIELDS):
            return 0
    except (ValueError, AttributeError):
        return 0
    normalized = ' '.join(text.casefold().split())
    if any(' '.join(term.casefold().split()) in normalized for term in case.get('forbidden', [])):
        return 0
    return sum(' '.join(term.casefold().split()) in normalized for term in case['required']) / len(case['required'])


def compare(baseline, candidate, cases, run):
    results = []
    for case in cases:
        scores = {}
        for name, model in [('baseline', baseline), ('candidate', candidate)]:
            response = ollama('chat', {'model': model, 'messages': case['messages'], 'think': False,
                'format': 'json', 'stream': False, 'keep_alive': 0,
                'options': {'temperature': 0, 'seed': 42, 'num_ctx': 8192, 'num_predict': 2200}}, timeout=240)
            scores[name] = score(response['message']['content'], case)
            scores[name + 'Tokens'] = response.get('eval_count')
        results.append({'issue': case['issue'], **scores})
    improved = all(row['candidate'] >= row['baseline'] for row in results) and any(
        row['candidate'] > row['baseline'] for row in results)
    report = {'baselineModel': baseline, 'candidateModel': candidate, 'improved': improved, 'cases': results,
        'baselineScore': 100 * sum(row['baseline'] for row in results) / len(results),
        'candidateScore': 100 * sum(row['candidate'] for row in results) / len(results), 'checkedAt': timestamp()}
    save_json(run / 'evaluation.json', report)
    return report


def tick(config, home, retry):
    status = home / 'training-status.json'
    version = None

    def publish(phase, **details):
        save_json(status, {'schema': 1, 'phase': phase, 'observedAt': timestamp(), 'run': version, **details})

    examples = json.loads(run_tool([config['node'], HERE / 'training-dataset.mjs', home / 'examples.sqlite']))
    if len(examples) < config['minExamples']:
        publish('waiting-for-approved-examples', examples=len(examples), required=config['minExamples'])
        return
    holdout = Path(config['holdout'])
    if not holdout.is_file():
        publish('waiting-for-holdout', examples=len(examples))
        return
    cases, held_out = read_holdout(holdout)
    examples = [item for item in examples if item['issue'] not in held_out]
    if len(examples) < config['minExamples']:
        publish('waiting-for-approved-examples', examples=len(examples), required=config['minExamples'])
        return
    if config['baseModel'] != 'Qwen/Qwen3-14B' or not re.fullmatch(r'[0-9a-f]{40}', config['baseRevision']):
        raise ValueError('Pin the Qwen3-14B base revision in the host config.')
    version = sha256(json.dumps([examples, cases, config['baseRevision'], config['maxTokens'], config['epochs']],
                                 sort_keys=True).encode()).hexdigest()[:16]
    run = home / 'runs' / version
    candidate = 'houseboat-qwen3:' + version
    if (run / 'evaluation.json').exists():
        evaluated = read_json(run / 'evaluation.json')
        publish('awaiting-promotion' if evaluated['improved'] else 'evaluation-did-not-improve', model=candidate,
                examples=len(examples), cases=len(cases), baselineScore=evaluated['baselineScore'],
                candidateScore=evaluated['candidateScore'])
        return
    if (run / 'failed.json').exists() and not retry:
        publish('failed', model=candidate, examples=len(examples))
        return
    heartbeat_path = Path(config['workerHeartbeat'])
    heartbeat = read_json(heartbeat_path) if heartbeat_path.exists() else {}
    age = (datetime.now(timezone.utc) - datetime.fromisoformat(heartbeat.get('observedAt', '1970-01-01T00:00:00Z'))).total_seconds()
    if heartbeat.get('phase') != 'watching' or not heartbeat.get('gpuLock') or not 0 <= age <= 90:
        publish('waiting-for-worker', examples=len(examples))
        return
    try:
        with gpu_lock(home):
            free = int(run_tool(['nvidia-smi', '--query-gpu=memory.free', '--format=csv,noheader,nounits']).splitlines()[0])
            if free < config['minFreeMiB'] or ollama('ps', timeout=8)['models']:
                publish('waiting-for-gpu', examples=len(examples))
                return
            run.mkdir(parents=True, exist_ok=True)
            baseline = config['baselineModel']
            installed = {item['name']: item['digest'] for item in ollama('tags')['models']}
            if installed.get(baseline) != config['baselineDigest']:
                raise ValueError('The runtime base model digest differs from the pinned Ollama tag.')
            selection_path = home / 'production-model.json'
            production = read_json(selection_path)['model'] if selection_path.exists() else baseline
            if production not in installed:
                raise ValueError('The recorded production model is unavailable for comparison.')
            save_json(run / 'dataset.json', examples)
            if not (run / 'adapter' / 'adapter_model.safetensors').exists():
                publish('training', examples=len(examples))
                train_adapter(examples, config, run, publish)
            publish('evaluating', model=candidate, examples=len(examples), cases=len(cases))
            adapter = run / 'adapter.gguf'
            if not adapter.exists():
                pending = run / 'adapter.pending.gguf'
                run_tool([sys.executable, config['converter'], '--base', run / 'base-config',
                          '--outtype', 'f16', '--outfile', pending, run / 'adapter'], timeout=600)
                os.replace(pending, adapter)
            if candidate not in installed:
                modelfile = run / 'Modelfile'
                modelfile.write_text(f'FROM {baseline}\nADAPTER "{adapter.as_posix()}"\n', encoding='utf-8')
                run_tool([config['ollama'], 'create', candidate, '-f', modelfile], timeout=1200)
            result = compare(production, candidate, cases, run)
            publish('awaiting-promotion' if result['improved'] else 'evaluation-did-not-improve', model=candidate,
                    examples=len(examples), cases=len(cases), baselineScore=result['baselineScore'],
                    candidateScore=result['candidateScore'])
    except sqlite3.OperationalError as error:
        if error.sqlite_errorcode != sqlite3.SQLITE_BUSY:
            raise
        publish('waiting-for-gpu', examples=len(examples))
    except Exception as error:
        if run.is_dir():
            save_json(run / 'failed.json', {'type': type(error).__name__, 'at': timestamp()})
        publish('failed', model=candidate, examples=len(examples), error=type(error).__name__)
        raise


def change_model(action, config, home, run_id, reviewer):
    if not reviewer or not reviewer.strip():
        raise ValueError('Name the human approving this model change.')
    pointer = home / 'production-model.json'
    current = read_json(pointer) if pointer.exists() else {'model': config['baselineModel'], 'previous': None}
    if action == 'promote':
        if not re.fullmatch(r'[0-9a-f]{16}', run_id or ''):
            raise ValueError('Supply a recorded training run ID.')
        report = read_json(home / 'runs' / run_id / 'evaluation.json')
        if not report['improved'] or report['baselineModel'] != current['model']:
            raise ValueError('The candidate must improve against the current production model.')
        new = report['candidateModel']
        if new != 'houseboat-qwen3:' + run_id:
            raise ValueError('Candidate tag does not belong to this run.')
    else:
        new = current['previous']
    if not new or new not in {item['name'] for item in ollama('tags')['models']}:
        raise ValueError('The requested model is not installed locally.')
    decision = {'model': new, 'previous': current['model'], 'action': action, 'reviewer': reviewer.strip(), 'at': timestamp()}
    save_json(pointer, decision)
    with (home / 'model-decisions.jsonl').open('a', encoding='utf-8') as log:
        log.write(json.dumps(decision) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['tick', 'promote', 'rollback'])
    parser.add_argument('config', type=Path)
    parser.add_argument('--run')
    parser.add_argument('--reviewer')
    parser.add_argument('--retry', action='store_true')
    args = parser.parse_args()
    config = read_json(args.config)
    home = Path(config['trainingHome']).resolve()
    if not (home / 'examples.sqlite').is_file():
        raise ValueError('The private worker training inbox is missing.')
    if not 3 <= config['minExamples'] <= 10_000 or not 512 <= config['maxTokens'] <= 4096 or not 1 <= config['epochs'] <= 5:
        raise ValueError('Set bounded example, sequence length and epoch limits.')
    if args.action == 'tick':
        tick(config, home, args.retry)
    else:
        with gpu_lock(home):
            change_model(args.action, config, home, args.run, args.reviewer)


if __name__ == '__main__':
    main()
