pkg load image;
try
    pkg load video;
catch
    disp('AVISO: Pacote video nao encontrado.');
end

pasta_video = 'video_input';
nome_arquivo = 'Rapido_1_5s.mp4';
caminho_completo = fullfile(pasta_video, nome_arquivo);

fator_redimensionamento = 0.05;

v = VideoReader(caminho_completo);
fps = v.FrameRate;
video_3d = [];
frame_idx = 1;

while hasFrame(v)
  frame = readFrame(v);
  if size(frame, 3) == 3
      frame = rgb2gray(frame);
  end
  frame_redimensionado = imresize(frame, fator_redimensionamento);
  video_3d(:, :, frame_idx) = double(frame_redimensionado);
  frame_idx = frame_idx + 1;
end

[dim_altura, dim_largura, total_frames] = size(video_3d);
pixels_por_frame = dim_altura * dim_largura;
imagem_temporal = reshape(video_3d, pixels_por_frame, total_frames);

% Analyze energy in 0.5 to 3.0 Hz band for all lines
N = total_frames;
f = (0:N-1)*(fps/N);

% Find indices for 0.5 to 3.0 Hz
freq_indices = find(f >= 0.5 & f <= 3.0);

energia_banda = zeros(pixels_por_frame, 1);
for i = 1:pixels_por_frame
    linha = imagem_temporal(i, :);
    linha_fft = abs(fft(linha - mean(linha))); % remove DC
    energia_banda(i) = sum(linha_fft(freq_indices).^2);
end

% Find max energy in range 2000-3000
start_idx = 2000;
end_idx = min(3000, pixels_por_frame);
[max_energy, best_line_idx] = max(energia_banda(start_idx:end_idx));
best_line_idx = best_line_idx + start_idx - 1;

disp(['Linha sugerida COM sinal (Max Energia entre 2000-3000): ' num2str(best_line_idx)]);
disp(['Energia na banda 0.5-3Hz da referida linha: ' num2str(max_energy)]);

disp(['Energia na banda 0.5-3Hz da linha 1500: ' num2str(energia_banda(1500))]);

% Optionally, find overall minimum energy line (sem sinal)
[min_energy, worst_line_idx] = min(energia_banda);
disp(['Linha com MENOR sinal globalmente: ' num2str(worst_line_idx)]);
