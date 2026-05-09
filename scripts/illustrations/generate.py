#!/usr/bin/env python3
"""Generate watercolor illustrations for WorkoutTracker via OpenAI gpt-image-1."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
PROMPTS_FILE = SCRIPT_DIR / "prompts.toml"
CACHE_DIR = SCRIPT_DIR / ".cache"
MODEL = "gpt-image-1"


@dataclass
class IllustrationSpec:
    name: str
    prompt: str
    output: Path
    size: str
    quality: str
    model: str

    @property
    def cache_key(self) -> str:
        h = hashlib.sha256()
        h.update(self.prompt.encode("utf-8"))
        h.update(self.size.encode("utf-8"))
        h.update(self.quality.encode("utf-8"))
        h.update(self.model.encode("utf-8"))
        return h.hexdigest()[:16]

    @property
    def cache_marker(self) -> Path:
        return CACHE_DIR / f"{self.name}-{self.cache_key}.done"


def load_specs() -> list[IllustrationSpec]:
    with open(PROMPTS_FILE, "rb") as f:
        data = tomllib.load(f)

    style = data["style"]
    suffix = style["suffix"]
    size = style["size"]
    quality = style["quality"]

    specs: list[IllustrationSpec] = []
    for name, entry in data["scenery"].items():
        full_prompt = f"{entry['prompt']}, {suffix}"
        output = REPO_ROOT / entry["output"]
        specs.append(IllustrationSpec(
            name=name,
            prompt=full_prompt,
            output=output,
            size=size,
            quality=quality,
            model=MODEL,
        ))
    return specs


def filter_specs(specs: list[IllustrationSpec], names: list[str] | None) -> list[IllustrationSpec]:
    if not names:
        return specs
    keep = set(names)
    available = {s.name for s in specs}
    unknown = sorted(keep - available)
    if unknown:
        raise SystemExit(
            f"ERROR: --filter で未知の name: {', '.join(unknown)}\n"
            f"  利用可能: {', '.join(sorted(available))}"
        )
    return [s for s in specs if s.name in keep]


def write_contents_json(image_path: Path) -> None:
    """imageset/Contents.json を作る（scale: 1x のみ）"""
    contents = {
        "images": [{"idiom": "universal", "filename": image_path.name, "scale": "1x"}],
        "info": {"version": 1, "author": "xcode"},
    }
    contents_path = image_path.parent / "Contents.json"
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def generate_one(spec: IllustrationSpec, *, force: bool, dry_run: bool) -> str:
    """戻り値: 'generated' / 'cached' / 'dry-run'"""
    if dry_run:
        print(f"[dry-run] {spec.name}")
        print(f"  prompt: {spec.prompt}")
        print(f"  output: {spec.output}")
        return "dry-run"

    if not force and spec.cache_marker.exists() and spec.output.exists():
        print(f"[cached]  {spec.name}")
        return "cached"

    from openai import OpenAI
    client = OpenAI()

    print(f"[generate] {spec.name}...")
    result = client.images.generate(
        model=spec.model,
        prompt=spec.prompt,
        size=spec.size,
        quality=spec.quality,
    )
    b64 = result.data[0].b64_json
    if b64 is None:
        raise RuntimeError(f"No b64_json returned for {spec.name}")
    image_bytes = base64.b64decode(b64)

    spec.output.parent.mkdir(parents=True, exist_ok=True)
    spec.output.write_bytes(image_bytes)
    write_contents_json(spec.output)

    CACHE_DIR.mkdir(exist_ok=True)
    spec.cache_marker.write_text(spec.prompt + "\n")

    print(f"  → {spec.output}")
    return "generated"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate watercolor illustrations")
    parser.add_argument("--dry-run", action="store_true", help="プロンプトを print して API 呼ばず終了")
    parser.add_argument("--force", action="store_true", help="キャッシュを無視して再生成")
    parser.add_argument("--filter", type=str, default=None, help="カンマ区切りの name 部分指定")
    args = parser.parse_args()

    if not args.dry_run and not os.environ.get("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY が未設定。.envrc を確認するか --dry-run を使う。", file=sys.stderr)
        return 1

    specs = load_specs()
    names = [n.strip() for n in args.filter.split(",")] if args.filter else None
    specs = filter_specs(specs, names)

    if not specs:
        print("該当する spec がない。")
        return 0

    counts = {"generated": 0, "cached": 0, "dry-run": 0}
    for spec in specs:
        result = generate_one(spec, force=args.force, dry_run=args.dry_run)
        counts[result] = counts.get(result, 0) + 1

    print(f"\n結果: generated={counts['generated']}, cached={counts['cached']}, dry-run={counts['dry-run']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
