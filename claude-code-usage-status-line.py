#!/usr/bin/env python3
"""Claude Code status line: shows 5h and 7d usage utilization from the Anthropic OAuth usage API."""

import json
import os
import sys
import time
import hashlib
import urllib.request
from datetime import datetime, timezone


def get_config_dir():
    if len(sys.argv) > 1:
        return os.path.expanduser(sys.argv[1])
    return os.path.expanduser('~/.claude')


def get_token(config_dir):
    creds_file = os.path.join(config_dir, '.credentials.json')
    try:
        with open(creds_file) as f:
            data = json.load(f)
        return data['claudeAiOauth']['accessToken']
    except Exception:
        return None


def fetch_usage(token):
    req = urllib.request.Request(
        'https://api.anthropic.com/api/oauth/usage',
        headers={
            'Authorization': f'Bearer {token}',
            'anthropic-beta': 'oauth-2025-04-20',
            'Content-Type': 'application/json',
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())
    except Exception:
        return None


def get_cache_path(config_dir):
    h = hashlib.md5(config_dir.encode()).hexdigest()[:8]
    return f'/tmp/claude-usage-{h}.txt'


def load_cache(cache_path, ttl=58):
    try:
        if os.path.exists(cache_path):
            age = time.time() - os.path.getmtime(cache_path)
            if age < ttl:
                with open(cache_path) as f:
                    return f.read().rstrip()
    except Exception:
        pass
    return None


def save_cache(cache_path, content):
    try:
        with open(cache_path, 'w') as f:
            f.write(content)
    except Exception:
        pass


def format_reset(iso_str):
    try:
        dt = datetime.fromisoformat(iso_str.replace('Z', '+00:00'))
        diff = dt - datetime.now(timezone.utc)
        secs = max(0, int(diff.total_seconds()))
        if secs < 3600:
            return f'{secs // 60}m'
        elif secs < 86400:
            return f'{secs // 3600}h'
        else:
            return f'{secs // 86400}d'
    except Exception:
        return ''


def color_bar(pct):
    if pct is None:
        return '?'
    if pct < 50:
        color = '\033[32m'
    elif pct < 80:
        color = '\033[33m'
    else:
        color = '\033[31m'
    reset = '\033[0m'
    filled = round(pct / 10)
    empty = 10 - filled
    return f'{color}{"█" * filled}{"░" * empty}{reset} {pct:2.0f}%'


def main():
    # Consume stdin (Claude Code sends session JSON we don't use)
    try:
        if not sys.stdin.isatty():
            sys.stdin.read()
    except Exception:
        pass

    config_dir = get_config_dir()
    cache_path = get_cache_path(config_dir)

    cached = load_cache(cache_path)
    if cached:
        print(cached)
        return

    token = get_token(config_dir)
    if not token:
        return

    data = fetch_usage(token)
    if not data:
        return

    h5 = data.get('five_hour', {}).get('utilization')
    h5_reset = data.get('five_hour', {}).get('resets_at', '')
    d7 = data.get('seven_day', {}).get('utilization')
    d7_reset = data.get('seven_day', {}).get('resets_at', '')

    parts = [f'5h {color_bar(h5)}']
    if h5_reset:
        parts[-1] += f' ↻{format_reset(h5_reset)}'

    parts.append(f'7d {color_bar(d7)}')
    if d7_reset:
        parts[-1] += f' ↻{format_reset(d7_reset)}'

    output = '  '.join(parts)
    save_cache(cache_path, output)
    print(output)


if __name__ == '__main__':
    main()
