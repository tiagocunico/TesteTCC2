import cv2
import sys

print("cv2 version:", cv2.__version__)

cap = cv2.VideoCapture("video_input/Rapido 1.mp4")
if not cap.isOpened():
    print("Failed to open video")
    sys.exit(1)

fps = cap.get(cv2.CAP_PROP_FPS)
print("FPS:", fps)

count = 0
while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    frame = cv2.resize(frame, (160, 120))
    cv2.imwrite(f"video_input/frames/frame_{count:04d}.png", frame)
    count += 1
    
    if count >= 150:
        break
        
    if count % 30 == 0:
        print(f"Extracted {count} frames")

print(f"Extraction complete! {count} frames saved.")
