#!/usr/bin/env python3
"""Claude Code status line: cwd | model[effort] | rate limits | context + cache hit rate"""

import json
import os
import sys
import time


GREEN  = '\033[32m'
YELLOW = '\033[33m'
RED    = '\033[31m'
RESET  = '\033[0m'


def read_session():
    try:
        if not sys.stdin.isatty():
            return json.load(sys.stdin)
    except Exception:
        pass
    return {}


def ansi_color(pct, low=50, high=80):
    if pct < low:
        return GREEN
    elif pct < high:
        return YELLOW
    return RED


def color_bar(pct):
    if pct is None:
        return '?'
    color = ansi_color(pct)
    filled = round(pct / 10)
    return f'{color}{"█" * filled}{"░" * (10 - filled)}{RESET} {pct:2.0f}%'


def format_reset(epoch_secs):
    secs = max(0, int(epoch_secs - time.time()))
    if secs < 3600:
        return f'{secs // 60}m'
    elif secs < 86400:
        return f'{secs // 3600}h'
    return f'{secs // 86400}d'


def section_cwd(data):
    cwd = (data.get('workspace') or {}).get('current_dir') or data.get('cwd', '')
    return os.path.basename(cwd) if cwd else None


def section_model(data):
    name = (data.get('model') or {}).get('display_name', '')
    if not name:
        return None
    effort = (data.get('effort') or {}).get('level', '')
    return f'{name} [{effort}]' if effort else name


def section_rate_limits(data):
    rl = data.get('rate_limits')
    if not rl:
        return None
    parts = []
    for key, label in [('five_hour', '5h'), ('seven_day', '7d')]:
        w = rl.get(key)
        if not w:
            continue
        pct = w.get('used_percentage')
        resets_at = w.get('resets_at')
        piece = f'{label} {color_bar(pct)}'
        if resets_at:
            piece += f' ↻{format_reset(resets_at)}'
        parts.append(piece)
    return '  '.join(parts) if parts else None


def section_context(data):
    ctx = data.get('context_window') or {}
    pct = ctx.get('used_percentage')
    if pct is None:
        return None

    parts = [f'ctx {color_bar(pct)}']

    usage = ctx.get('current_usage')
    if usage:
        cache_read  = usage.get('cache_read_input_tokens', 0) or 0
        cache_write = usage.get('cache_creation_input_tokens', 0) or 0
        input_tok   = usage.get('input_tokens', 0) or 0
        total = cache_read + cache_write + input_tok
        if total > 0:
            hit_pct = cache_read / total * 100
            color = GREEN if hit_pct >= 70 else YELLOW if hit_pct >= 30 else RED
            parts.append(f'cache {color}{hit_pct:2.0f}%{RESET}')

    return '  '.join(parts)


def main():
    data = read_session()

    sections = [
        section_cwd(data),
        section_model(data),
        section_rate_limits(data),
        section_context(data),
    ]

    output = ' | '.join(s for s in sections if s)
    if output:
        print(output)


if __name__ == '__main__':
    main()
