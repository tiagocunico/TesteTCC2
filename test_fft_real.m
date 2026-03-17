pkg load video;
disp('Loading...');
v = VideoReader('video_input/Rapido_1_raw_copy.mp4');
disp(['FPS: ', num2str(v.FrameRate), ' - Total Frames: ', num2str(v.NumberOfFrames)]);
disp('Reading 150 frames...');
video_3d = [];
for i=1:150
  if hasFrame(v)
    f = readFrame(v);
    if size(f, 3) == 3; f = rgb2gray(f); end
    f_res = imresize(f, 0.1);
    video_3d(:, :, i) = double(f_res);
  else
    break;
  end
end
disp(['Done reading. Size: ', num2str(size(video_3d, 1)), 'x', num2str(size(video_3d, 2)), 'x', num2str(size(video_3d, 3))]);
fft_result = fftn(video_3d);
disp('FFT complete');
