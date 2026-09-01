from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
SECRET_KEYS = ("GEMINI_API_KEY",)


def read_env(path: Path) -> dict[str, str]:
    if not path.exists():
        raise SystemExit(f"No {path}. Copy .env.example to .env and fill it in.")
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def push(key: str, value: str, project: str) -> bool:
    handle, temp_path = tempfile.mkstemp(prefix="orbit-secret-")
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="") as fh:
            fh.write(value)
        command = [
            "firebase",
            "functions:secrets:set",
            key,
            "--data-file",
            temp_path,
            "--project",
            project,
        ]
        result = subprocess.run(command, shell=os.name == "nt")
        return result.returncode == 0
    finally:
        try:
            os.remove(temp_path)
        except OSError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Push secrets from functions-py/.env into Secret Manager."
    )
    parser.add_argument("--project", default="orbit-507316")
    parser.add_argument("--only", action="append", default=None)
    args = parser.parse_args()

    env = read_env(ENV_PATH)
    wanted = tuple(args.only) if args.only else SECRET_KEYS

    failures = 0
    for key in wanted:
        value = env.get(key, "")
        if not value:
            print(f"skip {key}: empty in .env")
            continue
        print(f"push {key} ({len(value)} bytes, no trailing newline)")
        if not push(key, value, args.project):
            failures += 1
            print(f"failed {key}", file=sys.stderr)

    if failures:
        print(f"{failures} secret(s) failed", file=sys.stderr)
        return 1
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
