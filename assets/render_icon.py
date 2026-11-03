from pathlib import Path

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ASSETS = Path(__file__).resolve().parent
SOURCE = ASSETS / "chaoxing_official.jpg"
PNG_ICON = ASSETS / "learning_plus.png"
ICO_ICON = ASSETS / "learning_plus.ico"
SIZE = 1024

with Image.open(SOURCE) as source:
    icon = source.convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)

# Add the PLUS wordmark in the empty upper-left area of the official logo.
badge_box = (56, 56, 366, 184)

shadow = Image.new("RGBA", icon.size, (0, 0, 0, 0))
shadow_box = (badge_box[0], badge_box[1] + 12, badge_box[2], badge_box[3] + 12)
ImageDraw.Draw(shadow).rounded_rectangle(shadow_box, radius=64, fill=(80, 18, 22, 90))
icon = Image.alpha_composite(icon, shadow.filter(ImageFilter.GaussianBlur(18)))

draw = ImageDraw.Draw(icon)
draw.rounded_rectangle(badge_box, radius=64, fill="#fffdf8", outline="#ffd88a", width=6)
font_path = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts" / "arialbd.ttf"
font = ImageFont.truetype(str(font_path), 76)
text = "PLUS"
text_box = draw.textbbox((0, 0), text, font=font)
text_width = text_box[2] - text_box[0]
text_height = text_box[3] - text_box[1]
text_x = badge_box[0] + (badge_box[2] - badge_box[0] - text_width) / 2 - text_box[0]
text_y = badge_box[1] + (badge_box[3] - badge_box[1] - text_height) / 2 - text_box[1]
draw.text((text_x, text_y), text, fill="#d8232f", font=font)

icon.save(PNG_ICON, format="PNG", optimize=True)
icon.save(ICO_ICON, format="ICO", sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
print(f"Generated {PNG_ICON} and {ICO_ICON} from {SOURCE}")
