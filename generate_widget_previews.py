"""生成小组件预览图，并输出到 Android drawable 各密度目录。

使用方法：
    python generate_widget_previews.py

前提：
    在 assets/widget/preview/ 下放好截图（文件名固定）：
        widget_today.png
        widget_upcoming.png
        widget_week.png
        widget_day.png

    截图分辨率随意，脚本以源图宽度作为 xxxhdpi 基准，
    等比缩小到其余密度（mdpi=25%, hdpi=37.5%, xhdpi=50%, xxhdpi=75%）。

输出：
    course_block/android/app/src/main/res/drawable-<density>/widget_preview_<name>.png

依赖：
    pip install pillow
"""

from pathlib import Path
try:
    from PIL import Image
except ImportError:
    raise SystemExit("需要 Pillow，请先运行：pip install pillow")

ROOT        = Path(__file__).resolve().parent
SRC_DIR     = ROOT / "assets" / "widget" / "preview"
RES_BASE    = ROOT / "course_block" / "android" / "app" / "src" / "main" / "res"

# xxxhdpi 为基准 (scale=1.0)，其余等比缩小
DENSITIES = {
    "mdpi":     0.25,
    "hdpi":     0.375,
    "xhdpi":    0.5,
    "xxhdpi":   0.75,
    "xxxhdpi":  1.0,
}

# 源文件名 → 输出 drawable 名
WIDGETS = {
    "widget_today":    "widget_preview_today",
    "widget_upcoming": "widget_preview_upcoming",
    "widget_week":     "widget_preview_week",
    "widget_day":      "widget_preview_day",
}


def process(src: Path, out_name: str) -> None:
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    print(f"  源图: {src.name}  ({w}×{h})")

    for density, scale in DENSITIES.items():
        new_w = max(1, round(w * scale))
        new_h = max(1, round(h * scale))
        resized = img.resize((new_w, new_h), Image.LANCZOS)

        out_dir = RES_BASE / f"drawable-{density}"
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{out_name}.png"

        resized.save(out_path, "PNG", optimize=True)
        print(f"    → drawable-{density}/{out_name}.png  ({new_w}×{new_h})")


def main() -> None:
    if not SRC_DIR.exists():
        SRC_DIR.mkdir(parents=True, exist_ok=True)
        print(f"已创建目录 {SRC_DIR}")
        print("请将以下截图放入该目录后重新运行：")
        for src_name in WIDGETS:
            print(f"  {src_name}.png")
        return

    missing = []
    for src_name in WIDGETS:
        src = SRC_DIR / f"{src_name}.png"
        if not src.exists():
            missing.append(src.name)

    if missing:
        print("以下截图文件缺失，请放入后重新运行：")
        for m in missing:
            print(f"  {SRC_DIR / m}")
        return

    print("开始处理预览图...\n")
    for src_name, out_name in WIDGETS.items():
        src = SRC_DIR / f"{src_name}.png"
        process(src, out_name)
        print()

    print("全部完成！现在可以运行 flutter build apk 或 adb install。")


if __name__ == "__main__":
    main()
