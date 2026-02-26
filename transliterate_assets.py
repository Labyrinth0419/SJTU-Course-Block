"""Transliterate Japanese text in all files under assets to Romaji.

Usage:
    python transliterate_assets.py [directory]

If no directory is provided, uses ./assets.

This script finds text files (based on extension) and replaces Japanese
hiragana/katakana/kanji with romaji using pykakasi.
It writes modifications in-place but backs up original file with .bak.

Requires: pip install pykakasi
"""
import sys
import os
from pathlib import Path

try:
    import pykakasi
except ImportError:
    print("Please install pykakasi: pip install pykakasi")
    sys.exit(1)

TEXT_EXTS = {'.txt', '.md', '.json', '.yaml', '.yml', '.xml', '.html', '.htm'}
IMAGE_EXTS = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'}


def transliterate_file(path: Path, kakasi):
    text = path.read_text(encoding='utf-8')
    result = kakasi.convert(text)
    # join output
    romaji = ''.join(item['hepburn'] for item in result)
    if romaji != text:
        bak = path.with_suffix(path.suffix + '.bak')
        path.rename(bak)
        path.write_text(romaji, encoding='utf-8')
        print(f"Translated {path} (backup at {bak})")


def main():
    if len(sys.argv) > 1:
        root = Path(sys.argv[1])
    else:
        root = Path('assets')
    if not root.exists():
        print(f"Directory {root} does not exist")
        return
    kks = pykakasi.kakasi()
    kks.setMode("J", "a")  # Japanese to ascii
    kks.setMode("H", "a")
    kks.setMode("K", "a")
    kks.setMode("r", "Hepburn")
    kks.setMode("s", True)
    converter = kks.getConverter()

    for path in root.rglob('*'):
        if path.is_file():
            suffix = path.suffix.lower()
            if suffix in TEXT_EXTS:
                transliterate_file(path, converter)
            elif suffix in IMAGE_EXTS:
                # rename image file if name contains Japanese
                new_name = converter.do(path.stem)
                # converter returns ascii, but may contain spaces; sanitize
                new_name = new_name.replace(' ', '_')
                if new_name and new_name != path.stem:
                    new_path = path.with_stem(new_name)
                    path.rename(new_path)
                    print(f"Renamed image {path.name} -> {new_path.name}")

if __name__ == '__main__':
    main()
