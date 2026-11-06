"""Build launcher resources from the exact user-supplied picture.
Only deterministic fitting/resizing for Android densities; no redraw.
Run: python3 tool/generate_icon.py (requires Pillow).
"""
from pathlib import Path
from PIL import Image, ImageOps
root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'assets/branding/launcher_original.png').convert('RGB')
res = root / 'android/app/src/main/res'
background = '#FFD18A'
for density, size in {'mdpi':48, 'hdpi':72, 'xhdpi':96, 'xxhdpi':144, 'xxxhdpi':192}.items():
    folder = res / f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    ImageOps.pad(source, (size, size), method=Image.Resampling.LANCZOS, color=background).save(folder / 'ic_launcher.png')
    # Keep the complete uploaded photo inside the safe central area of adaptive
    # icons; Android supplies the round/squircle mask, without cutting off dogs.
    canvas_size = round(size * 108 / 48)
    safe_size = round(canvas_size * 72 / 108)
    canvas = Image.new('RGB', (canvas_size, canvas_size), background)
    photo = ImageOps.pad(source, (safe_size, safe_size), method=Image.Resampling.LANCZOS, color=background)
    inset = (canvas_size - safe_size) // 2
    canvas.paste(photo, (inset, inset))
    canvas.save(folder / 'ic_launcher_foreground.png')
folder = res / 'mipmap-anydpi-v26'
folder.mkdir(parents=True, exist_ok=True)
(folder / 'ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''')
(res / 'values/colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources><color name="launcher_background">#FFD18A</color></resources>
''')
print('Generated legacy and adaptive launcher resources from the uploaded original.')
