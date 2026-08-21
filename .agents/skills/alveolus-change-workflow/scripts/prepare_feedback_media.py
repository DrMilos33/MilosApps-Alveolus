#!/usr/bin/env python3
"""Prepare bounded, text-indexed GIF evidence without modifying the source."""

from __future__ import annotations

import argparse
import hashlib
import math
import re
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


MAX_FRAMES = 6
MAX_PREVIEW_BYTES = 8 * 1024 * 1024
DEFAULT_MAX_SIZE = (960, 540)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_case_id(value: str) -> str:
    result = re.sub(r"[^a-zA-Z0-9._-]+", "-", value.strip()).strip("-.")
    if not result:
        raise ValueError("case id must contain at least one safe character")
    return result


def sample_indices(frame_count: int, maximum: int = MAX_FRAMES) -> list[int]:
    count = min(maximum, frame_count)
    if count <= 1:
        return [0]
    return sorted({round(index * (frame_count - 1) / (count - 1)) for index in range(count)})


def load_metadata(source: Path) -> tuple[int, list[int], list[int]]:
    with Image.open(source) as image:
        frame_count = int(getattr(image, "n_frames", 1))
        durations: list[int] = []
        for index in range(frame_count):
            image.seek(index)
            durations.append(max(1, int(image.info.get("duration", 100))))
    timestamps: list[int] = []
    elapsed = 0
    for duration in durations:
        timestamps.append(elapsed)
        elapsed += duration
    return frame_count, durations, timestamps


def render_frames(source: Path, indices: list[int], maximum_size: tuple[int, int]) -> list[Image.Image]:
    frames: list[Image.Image] = []
    with Image.open(source) as image:
        for index in indices:
            image.seek(index)
            frame = image.convert("RGBA")
            frame = ImageOps.contain(frame, maximum_size, Image.Resampling.LANCZOS)
            frames.append(frame)
    return frames


def contact_sheet(frames: list[Image.Image], timestamps: list[int]) -> Image.Image:
    columns = min(3, len(frames))
    rows = math.ceil(len(frames) / columns)
    cell_width = max(frame.width for frame in frames)
    cell_height = max(frame.height for frame in frames) + 28
    sheet = Image.new("RGBA", (cell_width * columns, cell_height * rows), (6, 17, 21, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, frame in enumerate(frames):
        column = index % columns
        row = index // columns
        x = column * cell_width + (cell_width - frame.width) // 2
        y = row * cell_height
        sheet.alpha_composite(frame, (x, y))
        draw.text(
            (column * cell_width + 8, y + cell_height - 21),
            f"{timestamps[index] / 1000.0:.2f} s",
            fill=(222, 245, 239, 255),
            font=font,
        )
    return sheet


def write_previews(
    source: Path,
    output_dir: Path,
    indices: list[int],
    all_timestamps: list[int],
    maximum_size: tuple[int, int],
) -> tuple[list[Path], Path, list[int]]:
    frames = render_frames(source, indices, maximum_size)
    selected_timestamps = [all_timestamps[index] for index in indices]
    frame_paths: list[Path] = []
    for output_index, (frame, timestamp) in enumerate(zip(frames, selected_timestamps), start=1):
        path = output_dir / f"frame_{output_index:02d}_{timestamp:06d}ms.png"
        frame.save(path, format="PNG", optimize=True)
        frame_paths.append(path)
    sheet_path = output_dir / "contact_sheet.png"
    contact_sheet(frames, selected_timestamps).save(sheet_path, format="PNG", optimize=True)
    return frame_paths, sheet_path, selected_timestamps


def preview_size(paths: list[Path], sheet_path: Path) -> int:
    return sum(path.stat().st_size for path in [*paths, sheet_path])


def prepare(source: Path, output_dir: Path) -> Path:
    source = source.resolve()
    if not source.is_file():
        raise FileNotFoundError(source)
    if source.suffix.lower() != ".gif":
        raise ValueError("only animated GIF evidence is accepted")

    source_hash_before = sha256(source)
    source_size = source.stat().st_size
    output_dir.mkdir(parents=True, exist_ok=True)
    stored_original = output_dir / "original.gif"
    if source != stored_original.resolve():
        shutil.copy2(source, stored_original)
    else:
        stored_original = source
    if sha256(stored_original) != source_hash_before:
        raise RuntimeError("stored original differs from source")

    for generated in [*output_dir.glob("frame_*.png"), output_dir / "contact_sheet.png", output_dir / "manifest.md"]:
        if generated.exists() and generated != stored_original:
            generated.unlink()

    frame_count, durations, all_timestamps = load_metadata(stored_original)
    indices = sample_indices(frame_count)
    maximum_size = DEFAULT_MAX_SIZE
    while True:
        for old_frame in output_dir.glob("frame_*.png"):
            old_frame.unlink()
        sheet = output_dir / "contact_sheet.png"
        if sheet.exists():
            sheet.unlink()
        frame_paths, sheet_path, selected_timestamps = write_previews(
            stored_original, output_dir, indices, all_timestamps, maximum_size
        )
        current_size = preview_size(frame_paths, sheet_path)
        if current_size <= MAX_PREVIEW_BYTES:
            break
        if maximum_size[0] <= 160 or maximum_size[1] <= 90:
            raise RuntimeError("prepared media cannot be reduced below 8 MiB")
        maximum_size = (max(160, int(maximum_size[0] * 0.78)), max(90, int(maximum_size[1] * 0.78)))

    if sha256(source) != source_hash_before:
        raise RuntimeError("source GIF changed during preparation")

    total_duration = sum(durations)
    manifest = output_dir / "manifest.md"
    lines = [
        "# ALVEOLUS feedback evidence",
        "",
        f"- Original: `{stored_original.name}`",
        f"- SHA-256: `{source_hash_before}`",
        f"- Original bytes: {source_size}",
        f"- Source frames: {frame_count}",
        f"- Duration: {total_duration / 1000.0:.2f} s",
        f"- Prepared media bytes: {current_size}",
        "- Task rule: attach only the contact sheet or selected PNG frames, never the GIF.",
        "",
        "## Selected frames",
        "",
    ]
    for path, frame_index, timestamp in zip(frame_paths, indices, selected_timestamps):
        lines.append(f"- `{path.name}` — source frame {frame_index}, {timestamp / 1000.0:.2f} s")
    manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(manifest)
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--case", default="", help="safe evidence case id")
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[4]
    case_id = safe_case_id(args.case or args.source.stem)
    output_dir = args.output_dir or repo_root / ".codex-temp" / "evidence" / case_id
    prepare(args.source, output_dir.resolve())


if __name__ == "__main__":
    main()
