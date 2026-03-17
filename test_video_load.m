pkg load video;
v = VideoReader('video_input/Rapido 1.mp4');
disp(['FPS: ', num2str(v.FrameRate)]);
disp(['Duration: ', num2str(v.Duration)]);
disp(['Height: ', num2str(v.Height)]);
disp(['Width: ', num2str(v.Width)]);

disp('Reading 50 frames...');
for i = 1:50
  if hasFrame(v)
    frame = readFrame(v);
  else
    break;
  end
end
disp('Success!');
