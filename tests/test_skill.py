#!/usr/bin/env python3
"""Pytest-discoverable test entry for windows-cleanup-optimize.

Runs the comprehensive selftest suite including structural, AST syntax,
and negative fixtures. Exits 0 on success, 1 on failure.
"""
import subprocess
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SELFTEST = ROOT / "scripts" / "selftest.py"


def test_selftest_passes():
    """Pytest test case executing selftest.py."""
    proc = subprocess.run([sys.executable, str(SELFTEST)], capture_output=True, text=True)
    assert proc.returncode == 0, f"selftest failed:\n{proc.stdout}\n{proc.stderr}"


if __name__ == "__main__":
    proc = subprocess.run([sys.executable, str(SELFTEST)])
    sys.exit(proc.returncode)
