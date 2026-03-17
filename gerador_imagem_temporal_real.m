% =========================================================================
% SCRIPT: GERADOR IMAGEM TEMPORAL (Vídeo Real)
% =========================================================================
% Objetivo: Ler o vídeo real (Rapido_1_5s.mp4), vetorizar os pixels e plotar
% o Kymograph (Imagem 2D de Pixels x Tempo).
% =========================================================================
clear all; close all; clc;

% Carrega os pacotes necessarios
pkg load image;
try
    pkg load video;
catch
    disp('AVISO: Pacote video nao encontrado. Tente rodar: pkg install -forge video');
end

% =========================================================================
% CONFIGURAÇÕES
% =========================================================================
pasta_video = 'video_input';
nome_arquivo = 'Rapido_1_5s.mp4';
caminho_completo = fullfile(pasta_video, nome_arquivo);

fator_redimensionamento = 0.05; % Reduz ainda mais (5%) para facilitar a vetorização em uma imagem 2D

% =========================================================================
% LEITURA DO VÍDEO REAL
% =========================================================================
if ~exist(caminho_completo, 'file')
  error(['Arquivo não encontrado: ' caminho_completo]);
end

disp(['Carregando vídeo: ' caminho_completo]);
try
  v = VideoReader(caminho_completo);
catch e
  disp('Erro ao abrir o vídeo. Verifique se os pacotes estão instalados.');
  rethrow(e);
end

fps = v.FrameRate;
disp(['Taxa de quadros do vídeo (FPS): ', num2str(fps)]);

video_3d = [];
frame_idx = 1;

disp(['Lendo e pré-processando frames (Redimensionando para ', num2str(fator_redimensionamento*100), '%)...']);
while hasFrame(v)
  frame = readFrame(v);
  
  if size(frame, 3) == 3
      frame = rgb2gray(frame);
  end
  
  % Redimensiona com imresize
  frame_redimensionado = imresize(frame, fator_redimensionamento);
  
  video_3d(:, :, frame_idx) = double(frame_redimensionado);
  frame_idx = frame_idx + 1;
end

[dim_altura, dim_largura, total_frames] = size(video_3d);
disp(['Tamanho do Cubo 3D de Análise: ', num2str(dim_altura), 'x', num2str(dim_largura), 'x', num2str(total_frames)]);

% =========================================================================
% TRANSFORMAÇÃO ESPAÇO-TEMPO (VETORIZAÇÃO DOS FRAMES)
% =========================================================================
disp('Vetorizando matriz de video 3D para imagem 2D...');
pixels_por_frame = dim_altura * dim_largura;

% Achatamento do espaço: Transforma a matriz 3D inteira numa imagem 2D (PixelsVet x Tempo)
imagem_temporal = reshape(video_3d, pixels_por_frame, total_frames);

% =========================================================================
% EXTRAÇÃO DE FREQUÊNCIA DIRETO DA NOVA IMAGEM 2D VECTORIZADA
% =========================================================================
disp('---');
disp('>> EXTRAINDO FREQUÊNCIA DIRETO MATRIZ 2D (SINAL MÉDIO) <<');

% Achata todos os pixels combinados verticalmente para um único vetor temporal 1D
sinal_1d = mean(imagem_temporal, 1);

% Aplica a FFT 1D clássica pura
fft_1d = fft(sinal_1d);
espectro_1d = abs(fft_1d);

% Procura os picos locais reais
picos_1d = zeros(size(espectro_1d));
for i = 1:length(espectro_1d)
    maior_esq = (i == 1) || (espectro_1d(i) >= espectro_1d(i-1));
    maior_dir = (i == length(espectro_1d)) || (espectro_1d(i) >= espectro_1d(i+1));
    if maior_esq && maior_dir
        picos_1d(i) = espectro_1d(i);
    end
end

% Remover o componente DC vazado manualmente (Os primeiros bins da FFT comum sem shift)
dist_segura_bins = max(3, ceil(total_frames * 0.05));
for i = 1:dist_segura_bins
    if i <= length(picos_1d)
        picos_1d(i) = 0;
    end
    % Como não usamos shift, a frequência espelha nas bordas altas
    if (length(picos_1d) - i + 1) >= 1
        picos_1d(length(picos_1d) - i + 1) = 0;
    end
end

% Acha o maior pico harmônico real (em valor indexado 1)
[val_max_1d, loc_max_1d] = max(picos_1d);

% Converte o bin em Frequência (Hz) = (Bin - 1) * (FPS / N_frames)
freq_extraida_img = (loc_max_1d - 1) * (fps / total_frames);

disp(['Frequencia extraída do Kymograph: ', num2str(freq_extraida_img, '%.4f'), ' Hz']);
disp('---');

% =========================================================================
% PLOT DA IMAGEM TEMPORAL
% =========================================================================
disp('Preparando o gráfico 2D espaço-tempo...');

fig = figure('Name', 'Imagem Espaco-Tempo (Kymograph) - Real', 'NumberTitle', 'off', ...
             'Position', [100, 100, 1000, 600]);

% A função imagesc escalona a cor para a intensidade
imagesc(imagem_temporal);
colormap(gray);

title(['Kymograph (' num2str(pixels_por_frame) ' pixels redimensionados \times ' num2str(total_frames) ' frames)'], ...
      'FontSize', 12, 'FontWeight', 'bold');
xlabel(['Tempo (Frames, FPS=', num2str(fps), ')'], 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Pixels do Frame Espalmados', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on; colorbar;

disp('Processo finalizado com sucesso! Pressione "Enter" no terminal para fechar e sair.');
pause;
