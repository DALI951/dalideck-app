#!/usr/bin/env python3
"""Resize DaliDeck app icon masters into Android mipmap densities.

Run AFTER `flutter create .` (so the android/ tree exists). Requires Pillow.
Inputs  : dev/app_icon/icon_legacy.png     (1024x1024 full app icon)
          dev/app_icon/icon_foreground.png (1024x1024 adaptive glyph, centered)
Outputs : android/app/src/main/res/
            mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
            mipmap-.../ic_launcher_round.png
            mipmap-.../ic_launcher_foreground.png
            mipmap-anydpi-v26/ic_launcher.xml
            mipmap-anydpi-v26/ic_launcher_round.xml
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
MASTERS = os.path.join(ROOT, 'dev', 'app_icon')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

LEGACY_SIZES = {  # density -> px
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}
FOREGROUND_SIZES = {  # 108dp base for adaptive crop
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
}

LEGACY_XML = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''


def main():
    legacy = Image.open(os.path.join(MASTERS, 'icon_legacy.png')).convert('RGBA')
    fg = Image.open(os.path.join(MASTERS, 'icon_foreground.png')).convert('RGBA')

    for density, px in LEGACY_SIZES.items():
        folder = os.path.join(RES, 'mipmap-%s' % density)
        os.makedirs(folder, exist_ok=True)
        small = legacy.resize((px, px), Image.LANCZOS)
        small.save(os.path.join(folder, 'ic_launcher.png'))
        small.save(os.path.join(folder, 'ic_launcher_round.png'))
        print('wrote %s ic_launcher.png (%d)' % (density, px))

    for density, px in FOREGROUND_SIZES.items():
        folder = os.path.join(RES, 'mipmap-%s' % density)
        os.makedirs(folder, exist_ok=True)
        small = fg.resize((px, px), Image.LANCZOS)
        small.save(os.path.join(folder, 'ic_launcher_foreground.png'))
        print('wrote %s ic_launcher_foreground.png (%d)' % (density, px))

    base = os.path.join(RES, 'values')
    os.makedirs(base, exist_ok=True)
    with open(os.path.join(base, 'colors.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<resources>\n'
                '    <color name="ic_launcher_background">#FF0B0D10</color>\n'
                '</resources>\n')
    v26 = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(v26, exist_ok=True)
    with open(os.path.join(v26, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write(LEGACY_XML)
    with open(os.path.join(v26, 'ic_launcher_round.xml'), 'w', encoding='utf-8') as f:
        f.write(LEGACY_XML)
    print('wrote adaptive icon XML + color resource')


if __name__ == '__main__':
    main()