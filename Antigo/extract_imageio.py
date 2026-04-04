import imageio.v3 as iio
import cv2
import os

video_path = "video_input/Rapido 1.mp4"
output_dir = "video_input/frames"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

print("Reading video info...")
props = iio.improps(video_path, plugin="pyav")
print(props)

count = 0
for frame in iio.imiter(video_path, plugin="pyav"):
    small_frame = cv2.resize(frame, (160, 120))
    gray_frame = cv2.cvtColor(small_frame, cv2.COLOR_BGR2GRAY)
    cv2.imwrite(f"{output_dir}/frame_{count:04d}.png", gray_frame)
    count += 1
    if count >= 150:
        break
    if count % 30 == 0:
        print(f"Extracted {count} frames...")

print(f"Done! Extracted {count} frames.")
