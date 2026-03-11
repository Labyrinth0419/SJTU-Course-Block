#!/usr/bin/env python3
"""批量压缩 assets/icons 下的 PNG 图标。

功能：
- 对每个 PNG 先做 palette 量化（最多 256 色），再以优化模式保存。
- 默认覆盖原文件，可通过 --output-dir 将压缩结果写到其他目录。
- 会生成同名 .bak 备份，除非使用 --no-backup。

使用示例：
  python compress_icons.py                    # 直接覆盖 assets/icons 内的文件
  python compress_icons.py --output-dir out   # 结果写入 out，并保持原文件不动
  python compress_icons.py --max-size 512     # 限制最长边 512 像素再压缩

依赖：Pillow
  pip install pillow
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path
from typing import Iterable

from PIL import Image

ROOT = Path(__file__).resolve().parent
DEFAULT_ICON_DIR = ROOT / "course_block" / "assets" / "icons"


def iter_pngs(path: Path) -> Iterable[Path]:
    for p in sorted(path.glob("*.png")):
        if p.is_file():
            yield p


def compress_png(src: Path, dst: Path, max_size: int | None, backup: bool) -> None:
    if backup and dst == src:
        bak = src.with_suffix(".png.bak")
        if not bak.exists():
            shutil.copy2(src, bak)

    img = Image.open(src).convert("RGBA")
    if max_size:
        w, h = img.size
        scale = min(max_size / w, max_size / h, 1.0)
        if scale < 1.0:
            new_size = (int(w * scale), int(h * scale))
            img = img.resize(new_size, Image.LANCZOS)

    # 256 色量化 + 优化保存（RGBA 需用 FASTOCTREE）
    quantized = img.quantize(colors=256, method=Image.FASTOCTREE)
    dst.parent.mkdir(parents=True, exist_ok=True)
    quantized.save(dst, format="PNG", optimize=True)



def main() -> None:
    parser = argparse.ArgumentParser(description="压缩 assets/icons 下的 PNG")
    parser.add_argument(
        "--icon-dir",
        type=Path,
        default=DEFAULT_ICON_DIR,
        help="图标目录，默认 course_block/assets/icons",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="输出目录，默认覆盖源目录",
    )
    parser.add_argument(
        "--max-size",
        type=int,
        default=None,
        help="可选，限制最长边像素，超出则等比缩放",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="覆盖写入时不生成 .bak 备份",
    )
    args = parser.parse_args()

    icon_dir = args.icon_dir.resolve()
    out_dir = args.output_dir.resolve() if args.output_dir else icon_dir
    if not icon_dir.exists():
        raise SystemExit(f"icon 目录不存在: {icon_dir}")

    pngs = list(iter_pngs(icon_dir))
    if not pngs:
        raise SystemExit("未找到 PNG 文件")

    for src in pngs:
        dst = out_dir / src.name if out_dir != icon_dir else src
        compress_png(src, dst, args.max_size, backup=not args.no_backup)
        print(f"compressed -> {dst}")


if __name__ == "__main__":
    main()
