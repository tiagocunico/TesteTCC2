import cv2
import os

video_path = "video_input/Rapido 1.mp4"
output_dir = "video_input/frames"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

cap = cv2.VideoCapture(video_path)
fps = cap.get(cv2.CAP_PROP_FPS)

print(f"FPS: {fps}")

count = 0
max_frames = int(fps * 5) # 5 seconds

while cap.isOpened() and count < max_frames:
    ret, frame = cap.read()
    if not ret:
        break
        
    # Resize to something manageable like 160x120
    small_frame = cv2.resize(frame, (160, 120))
    gray_frame = cv2.cvtColor(small_frame, cv2.COLOR_BGR2GRAY)
    
    cv2.imwrite(f"{output_dir}/frame_{count:04d}.png", gray_frame)
    count += 1
    
    if count % 30 == 0:
        print(f"Extracted {count} frames...")

cap.release()
print(f"Done! Extracted {count} frames.")
