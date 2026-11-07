#!/usr/bin/env python3
# Draws the app's icon: a phone with a finger swiping up from its gesture
# area. Writes icon.png (256 px, as the other LuneOS apps') and
# icon-256x256.png (the splash icon) next to appinfo.json.
#
#   python3 -I tools/make-icon.py
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024  # drawn large, scaled down for smooth edges
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# Shadow under the phone
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((300, 130, 760, 940), 90, fill=(0, 0, 0, 110))
img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))

d = ImageDraw.Draw(img)
# Body and screen
d.rounded_rectangle((280, 90, 740, 900), 88, fill=(38, 42, 50, 255))
d.rounded_rectangle((300, 110, 720, 880), 72, fill=(60, 66, 78, 255))
screen = Image.new("RGBA", (380, 640), (0, 0, 0, 0))
sd = ImageDraw.Draw(screen)
for y in range(640):
    t = y / 639.0
    c = (int(34 + (10 - 34) * t), int(48 + (13 - 48) * t), int(64 + (18 - 64) * t), 255)
    sd.line((0, y, 379, y), fill=c)
mask = Image.new("L", (380, 640), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 379, 639), 40, fill=255)
img.paste(screen, (320, 140), mask)

# Two cards on the screen, the way Card View shows apps
d.rounded_rectangle((360, 180, 520, 410), 22, fill=(214, 236, 255, 255))
d.rounded_rectangle((540, 205, 660, 385), 18, fill=(150, 170, 190, 255))

# The gesture area glowing under the screen
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).rounded_rectangle((380, 812, 640, 840), 14, fill=(77, 178, 255, 255))
img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)))
d.rounded_rectangle((390, 816, 630, 836), 10, fill=(150, 210, 255, 255))

# A finger's swipe up: trail and fingertip
trail = Image.new("RGBA", (S, S), (0, 0, 0, 0))
td = ImageDraw.Draw(trail)
for i in range(36):
    y0 = 826 - i * 6
    td.ellipse((490, y0 - 22, 534, y0 + 22), fill=(77, 178, 255, int(150 * (1 - i / 36.0))))
img.alpha_composite(trail.filter(ImageFilter.GaussianBlur(6)))
d.ellipse((452, 580, 572, 700), outline=(255, 255, 255, 255), width=14)
d.ellipse((482, 610, 542, 670), fill=(255, 255, 255, 255))
# Arrow head over the fingertip
d.polygon([(512, 455), (452, 540), (572, 540)], fill=(255, 255, 255, 255))

out = img.resize((256, 256), Image.LANCZOS)
out.save(os.path.join(root, "icon.png"))
out.save(os.path.join(root, "icon-256x256.png"))
