"""Generate and copy launcher icon PNGs into Android mipmap folders.

Usage:
    python generate_mipmap_icons.py path/to/source.png
    python generate_mipmap_icons.py path/to/directory/

If a directory is supplied, every PNG in it will be processed.

The script will resize the given PNG to the standard Android launcher
icon resolutions and write them into
`course_block/android/app/src/main/res/mipmap-<density>/ic_launcher.png`.

Densities and sizes (square) used:
  mdpi   -> 48x48
  hdpi   -> 72x72
  xhdpi  -> 96x96
  xxhdpi -> 144x144
  xxxhdpi-> 192x192

You can adjust the mapping if you want other names or additional
folders (e.g. mipmap-anydpi, mipmap-ldpi).

The script requires Pillow (`pip install pillow`).
"""
import sys
import os
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow is required. Install with `pip install pillow`.")
    sys.exit(1)

# mapping density -> pixel size
SIZES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

ROOT = Path(__file__).resolve().parent
ANDROID_RES_BASE = ROOT / 'course_block' / 'android' / 'app' / 'src' / 'main' / 'res'


def ensure_dir(path: Path):
    if not path.exists():
        path.mkdir(parents=True, exist_ok=True)


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    src = Path(sys.argv[1])
    if not src.exists():
        print(f"Source {src} not found")
        sys.exit(1)

    # helper that handles one source image path
    def process_image(img_path: Path):
        print(f"Processing {img_path}")
        try:
            img = Image.open(img_path).convert('RGBA')
        except Exception as e:
            print(f"Failed to open image {img_path}: {e}")
            return
        stem = img_path.stem
        for density, size in SIZES.items():
            dst_dir = ANDROID_RES_BASE / f'mipmap-{density}'
            ensure_dir(dst_dir)
            dst_file = dst_dir / f'ic_launcher{("_" + stem) if stem else ""}.png'
            resized = img.resize((size, size), Image.LANCZOS)
            resized.save(dst_file, format='PNG')
            print(f"Written {dst_file} ({size}x{size})")

    generated_any = False
    if src.is_dir():
        for png in src.glob('*.png'):
            process_image(png)
            generated_any = True
    else:
        process_image(src)
        generated_any = True

    # if no vip-specific icon was generated, duplicate default to vip name
    for density in SIZES.keys():
        dst_dir = ANDROID_RES_BASE / f'mipmap-{density}'
        default_file = dst_dir / 'ic_launcher.png'
        vip_file = dst_dir / 'ic_launcher_vip.png'
        if default_file.exists() and not vip_file.exists():
            # copy default to vip
            default_file.replace(vip_file)
            print(f"Created vip icon {vip_file}")

    print("All densities generated.")

if __name__ == '__main__':
    main()
