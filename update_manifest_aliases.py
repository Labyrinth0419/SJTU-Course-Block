"""Scan Android res mipmap directories for launcher icons and add
activity-alias entries to AndroidManifest.xml.

Run this from workspace root; it will modify
`course_block/android/app/src/main/AndroidManifest.xml`.

The script finds files named `ic_launcher*.png` (excluding plain
`ic_launcher.png`), extracts the suffix after `ic_launcher`, and
adds an `<activity-alias>` block for each unique name (e.g. `_vip` or
`_custom`).  It will first remove any previously inserted autoscript
blocks (marked by comments).
"""
import re
from pathlib import Path

manifest_path = Path('course_block/android/app/src/main/AndroidManifest.xml')
res_base = Path('course_block/android/app/src/main/res')

if not manifest_path.exists():
    print('Cannot find AndroidManifest.xml')
    exit(1)

# collect icon names
icons = set()
for mip in res_base.glob('mipmap-*'):
    for f in mip.glob('ic_launcher*.png'):
        name = f.stem  # e.g. ic_launcher or ic_launcher_vip
        if name == 'ic_launcher':
            continue
        icons.add(name)

if not icons:
    print('No alternate icons found in res directories.')
    exit(0)

# generate alias xml
alias_xml = []
# note: default activity remains MainActivity; do not create a .DEFAULT alias
# (plugin will enable/disable MainActivity itself when switching back to default).
for icon in sorted(icons):
    # convert to something safe for alias name
    alias_name = icon.replace('ic_launcher', '').strip('_')
    xml = f"""
        <!-- alias for {icon} (auto-generated) -->
        <activity-alias
            android:name=".{alias_name}"
            android:enabled="false"
            android:targetActivity=".MainActivity"
            android:exported="true"
            android:icon="@mipmap/{icon}">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>
    """
    alias_xml.append(xml)

content = manifest_path.read_text(encoding='utf-8')
# remove existing auto blocks between markers
pattern = re.compile(r'<!-- START AUTO ICONS -->.*?<!-- END AUTO ICONS -->', re.DOTALL)
content = re.sub(pattern, '', content)

# insert new block before closing </application>
insertion = '<!-- START AUTO ICONS -->\n' + '\n'.join(alias_xml) + '\n<!-- END AUTO ICONS -->\n'
content = content.replace('</application>', insertion + '</application>')

manifest_path.write_text(content, encoding='utf-8')
print('AndroidManifest.xml updated with alternate icons:', icons)