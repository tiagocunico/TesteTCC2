% =========================================================================
% SCRIPT: VISUALIZAR FAIXA DE LINHAS (2000 a 3000)
% =========================================================================
% Objetivo: Gerar o Kymograph apenas da faixa de linhas de 2000 a 3000
% para que o usuario possa dar zoom e escolher visualmente a linha exata.
% =========================================================================
clear all; close all; clc;

% Carrega os pacotes necessarios
pkg load image;
try
    pkg load video;
catch
    disp('AVISO: Pacote video nao encontrado. Tente rodar: pkg install -forge video');
end

% Configurações
pasta_video = 'video_input';
nome_arquivo = 'Rapido_1_5s.mp4';
caminho_completo = fullfile(pasta_video, nome_arquivo);

fator_redimensionamento = 0.05;

if ~exist(caminho_completo, 'file')
  error(['Arquivo não encontrado: ' caminho_completo]);
end

disp(['Carregando vídeo: ' caminho_completo '...']);
v = VideoReader(caminho_completo);

video_3d = [];
frame_idx = 1;

disp('Processando frames (aguarde)...');
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

% Recorta apenas as linhas de 2000 a 3000
linha_inicio = 2000;
linha_fim = min(3000, pixels_por_frame);
faixa_temporal = imagem_temporal(linha_inicio:linha_fim, :);

disp(['Plotando recorte do Kymograph (Linhas ' num2str(linha_inicio) ' a ' num2str(linha_fim) ')']);

figure('Name', 'Analise Visual das Linhas 2000-3000', 'Position', [100, 100, 1000, 600]);

% Mapeia os eixos X (tempo) e Y (numero real da linha)
eixo_y = linha_inicio:linha_fim;
eixo_x = 1:total_frames;

% Mostra a imagem vinculada aos eixos reais
imagesc(eixo_x, eixo_y, faixa_temporal);
colormap(gray);
c = colorbar;
ylabel(c, 'Brilho (0-255)');

xlabel('Tempo (Frames)');
ylabel('Número Oficial da Linha');
title('Zoom nas linhas 2000 a 3000 do Kymograph');
grid on; box on;

disp('-------------------------------------------------------------------------');
disp(' INSTRUCOES:');
disp(' 1 - Use as ferramentas de "Zoom In" (Sinal de +) nativas do Grafico');
disp(' 2 - Arraste um retangulo sobre a parte clara/vibrante da imagem');
disp(' 3 - Olhe o eixo Y na vertical para descobrir o Numero Exato da linha');
disp(' 4 - Feche esta janela e anote o numero para usar no script Principal!');
disp('-------------------------------------------------------------------------');

pause; % Espera no terminal para não fechar a janela abruptamente
