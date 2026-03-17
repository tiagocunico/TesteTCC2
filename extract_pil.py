from PIL import Image
import imageio.v3 as iio
import os
import numpy as np

video_path = "video_input/Rapido 1.mp4"
output_dir = "video_input/frames"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

print("Reading video info...")
try:
    count = 0
    for frame in iio.imiter(video_path, plugin="pyav"):
        img = Image.fromarray(frame).convert('L')
        img = img.resize((160, 120))
        img.save(f"{output_dir}/frame_{count:04d}.png")
        count += 1
        if count >= 150:
            break
        if count % 30 == 0:
            print(f"Extracted {count} frames...")
    print(f"Done! Extracted {count} frames.")
except Exception as e:
    print(f"Error: {e}")
