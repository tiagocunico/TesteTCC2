import subprocess
import os

video_path = "video_input/Rapido 1.mp4"
output_dir = "video_input/frames"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

print("Running ffmpeg...")
cmd = [
    "ffmpeg", "-y",
    "-t", "5",
    "-r", "30",
    "-i", video_path,
    "-vf", "scale=160:120",
    "-vframes", "150",
    "-progress", "-",
    "-nostats",
    f"{output_dir}/frame_%04d.png"
]

process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
for line in process.stderr:
    print(line.strip())

process.wait()
print("Done!")
