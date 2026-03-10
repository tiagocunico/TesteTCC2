% Script para calcular a FFT 3D (Espaço-Tempo) "Pura" de um vídeo
% Sem escala de cinza, sem log, e sem fftshift.

pkg load image;
try
    pkg load video;
catch
    disp('AVISO: Pacote video nao encontrado.');
end

% -------------------------------------------------------------------------
% CONFIGURAÇÕES
% -------------------------------------------------------------------------
pasta_video = 'video_input';
nome_arquivo = 'Sequencia3x3.mkv'; % <-- COLOQUE O NOME DO SEU VÍDEO AQUI
caminho_completo = fullfile(pasta_video, nome_arquivo);

if ~exist(caminho_completo, 'file')
  error(['Arquivo não encontrado: ' caminho_completo]);
end

v = VideoReader(caminho_completo);
video_3d = [];
frame_idx = 1;

disp('Lendo e pré-processando frames...');
while hasFrame(v)
  frame = readFrame(v);
  
  if size(frame, 3) == 3
      % Como você pediu sem escala de cinza, precisamos escolher um dos
      % canais (R, G ou B) ou somá-los, pois a FFT 3D espera 3 dimensões (X, Y, Tempo).
      % Se passarmos X, Y, Cor (3) e Tempo, seria uma FFT 4D.
      % Como a imagem é de um brilho branco, vamos usar o canal R (G ou B dariam no mesmo)
      frame = frame(:,:,1); 
  end
  
  video_3d(:, :, frame_idx) = double(frame);
  frame_idx = frame_idx + 1;
end

[Ny, Nx, Nt] = size(video_3d);
disp(['Tamanho da matriz 3D final: ', num2str(Ny), ' x ', num2str(Nx), ' x ', num2str(Nt)]);

% -------------------------------------------------------------------------
% CÁLCULO DA FFT 3D "PURA"
% -------------------------------------------------------------------------
disp('Calculando a FFT 3D...');
fft_result = fftn(video_3d);

% SEM fftshift, SEM log10
magnitude = abs(fft_result);

% -------------------------------------------------------------------------
% GERAÇÃO DO GRÁFICO 3D
% -------------------------------------------------------------------------
disp('Preparando o gráfico 3D...');

% Como não teve fftshift, os eixos de frequência vão de 0 a 1 (ou de 0 a N-1)
% Aqui usamos apenas os índices exatos de 1 até N.
fy = 1:Ny;
fx = 1:Nx;
ft = 1:Nt;

[X, Y, T] = meshgrid(fx, fy, ft); 

% Ainda precisamos de um threshold porque se plotarmos tudo vira um bloco sólido,
% mas agora a magnitude é linear na escala, então os picos extremos vão sobressair muito.
threshold = prctile(magnitude(:), 99);
idx = find(magnitude > threshold);

figure('Name', 'Analise FFT 3D Pura', 'Position', [150, 150, 800, 600]);

scatter3(X(idx), Y(idx), T(idx), 20, magnitude(idx), 'filled');
xlabel('Índice X');
ylabel('Índice Y');
zlabel('Índice Temporal (Frames)');
title('Espectro FFT 3D Puro (Sem Shift, Sem Log)');
colormap('jet');
colorbar;
grid on;

% Realça a origem (Componente DC na posição 1,1,1 já que não houve shift)
hold on;
plot3(1, 1, 1, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
legend('Frequências Dominantes', 'Origem (Componente DC)');
hold off;

disp('Processo finalizado com sucesso! Pressione "Enter" no terminal para fechar e sair.');
pause;
