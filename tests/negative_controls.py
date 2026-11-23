#!/usr/bin/env python3
"""负对照（变异测试）：逐条关掉一个安全检查或检测，确认至少一个测试会失败。

用法：python tests/negative_controls.py [--only ID] [--list]
需要 pwsh 与 Pester 5。每个变异在临时副本里做，不改工作区。
存活（测试仍全部通过）的变异说明那条检查没有测试守着，退出码 1。

变异清单写在 tests/negative_controls.json：每项 {id, file, find, replace, why}。
find 必须在文件里恰好出现一次，否则视为清单过期，报错退出（防止变异悄悄失效）。
"""
import json, os, shutil, subprocess, sys, tempfile

ROOT = os.environ.get('WCO_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'negative_controls.json')

PESTER = (
    "Import-Module Pester -MinimumVersion 5.0 -MaximumVersion 5.99;"
    "$c=New-PesterConfiguration;$c.Run.Path='./tests';$c.Run.PassThru=$true;$c.Output.Verbosity='None';"
    "$r=Invoke-Pester -Configuration $c; if($r.FailedCount -gt 0 -or $r.Result -ne 'Passed'){exit 1}else{exit 0}"
)


def run_pester(cwd):
    p = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', PESTER], cwd=cwd,
                       capture_output=True, text=True, timeout=600)
    return p.returncode == 0


def main():
    spec = json.load(open(SPEC, encoding='utf-8'))
    args = sys.argv[1:]
    if '--list' in args:
        for m in spec['mutants']:
            print(f"{m['id']}: {m['why']}")
        return 0
    only = args[args.index('--only') + 1] if '--only' in args else None
    if not shutil.which('pwsh'):
        print('SKIP: 没有 pwsh，负对照未运行（不算通过）')
        return 2
    survivors, stale, killed = [], [], []
    for m in spec['mutants']:
        if only and m['id'] != only:
            continue
        with tempfile.TemporaryDirectory() as td:
            dst = os.path.join(td, 'repo')
            shutil.copytree(ROOT, dst, ignore=shutil.ignore_patterns('.git', '__pycache__', 'dist'))
            path = os.path.join(dst, m['file'])
            raw = open(path, 'rb').read()
            bom = raw.startswith(b'\xef\xbb\xbf')
            text = raw.decode('utf-8-sig')
            crlf = '\r\n' in text
            text = text.replace('\r\n', '\n')
            n = text.count(m['find'])
            if n != 1:
                stale.append(f"{m['id']}（find 出现 {n} 次）")
                continue
            text = text.replace(m['find'], m['replace'])
            if crlf:
                text = text.replace('\n', '\r\n')
            open(path, 'wb').write((b'\xef\xbb\xbf' if bom else b'') + text.encode('utf-8'))
            ok = run_pester(dst)
            (survivors if ok else killed).append(m['id'])
            print(f"{'SURVIVED' if ok else 'killed  '} {m['id']}: {m['why']}", flush=True)
    print(f"\n负对照：{len(killed)} 个被测试抓住，{len(survivors)} 个存活，{len(stale)} 个清单过期")
    for s in survivors:
        print(f"  存活：{s}")
    for s in stale:
        print(f"  过期：{s}")
    return 1 if (survivors or stale) else 0


if __name__ == '__main__':
    sys.exit(main())
