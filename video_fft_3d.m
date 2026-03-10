% Script para calcular a FFT 3D (Espaço-Tempo) de um vídeo
% Certifique-se de que o pacote 'video' e 'image' (para imresize) estejam instalados.
% Para instalar no Octave: pkg install -forge image video

% Carrega os pacotes necessarios
pkg load image;
try
    pkg load video;
catch
    disp('AVISO: Pacote video nao encontrado. Tente rodar: pkg install -forge video');
end

% -------------------------------------------------------------------------
% CONFIGURAÇÕES
% -------------------------------------------------------------------------
pasta_video = 'video_input';
nome_arquivo = 'Sequencia3x3.mkv'; % <-- COLOQUE O NOME DO SEU VÍDEO AQUI
caminho_completo = fullfile(pasta_video, nome_arquivo);

% -------------------------------------------------------------------------
% VERIFICAÇÃO E LEITURA
% -------------------------------------------------------------------------
if ~exist(caminho_completo, 'file')
  error(['Arquivo não encontrado: ' caminho_completo ...
         '. Coloque seu vídeo na pasta "video_input" e altere o nome do arquivo no script.']);
end

disp(['Carregando vídeo: ' caminho_completo]);
try
  v = VideoReader(caminho_completo);
catch e
  disp('Erro ao abrir o vídeo. Verifique se o formato é suportado ou instale os pacotes necessários.');
  rethrow(e);
end

video_3d = [];
frame_idx = 1;

disp('Lendo e pré-processando frames...');
while hasFrame(v)
  frame = readFrame(v);
  
  if size(frame, 3) == 3
      frame = rgb2gray(frame); % Converte para tons de cinza
  end
  
  video_3d(:, :, frame_idx) = double(frame);
  frame_idx = frame_idx + 1;
end

[Ny, Nx, Nt] = size(video_3d);
disp(['Tamanho da matriz 3D final (Y x X x Tempo): ', num2str(Ny), ' x ', num2str(Nx), ' x ', num2str(Nt)]);

% -------------------------------------------------------------------------
% CÁLCULO DA FFT 3D
% -------------------------------------------------------------------------
disp('Calculando a FFT 3D. Isso pode demorar alguns segundos...');
fft_result = fftn(video_3d);
fft_shifted = fftshift(fft_result); % Centraliza a frequência zero (DC)

% Calcula a magnitude aplicando escala logarítmica (para compressão visual)
magnitude = abs(fft_shifted);
magnitude_log = log10(1 + magnitude);

% -------------------------------------------------------------------------
% GERAÇÃO DO GRÁFICO 3D
% -------------------------------------------------------------------------
disp('Preparando o gráfico 3D...');

% Criação dos eixos de frequências (normalizados de -0.5 a 0.5)
fy = linspace(-0.5, 0.5, Ny);
fx = linspace(-0.5, 0.5, Nx);
ft = linspace(-0.5, 0.5, Nt);

% Malha de grade 3D para as coordenadas
[X, Y, T] = meshgrid(fx, fy, ft); 

% Encontra um limiar (threshold) para plotar apenas os pontos mais relevantes
% Vamos mostrar apenas o "top 1%" das frequências com maior magnitude
threshold = prctile(magnitude_log(:), 99);
idx = find(magnitude_log > threshold);

figure('Name', 'Analise FFT 3D Espaco-Tempo', 'Position', [100, 100, 800, 600]);

% Gráfico de dispersão 3D (Scatter3D)
scatter3(X(idx), Y(idx), T(idx), 20, magnitude_log(idx), 'filled');
xlabel('Freq. Espacial X');
ylabel('Freq. Espacial Y');
zlabel('Freq. Temporal');
title('Espectro FFT 3D do Vídeo (Frequências Dominantes)');
colormap('jet');
c = colorbar;
ylabel(c, 'Magnitude Logarítmica');
grid on;

% Realça o eixo DC (origem 0,0,0)
hold on;
plot3(0, 0, 0, 'rp', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
legend('Frequências Dominantes', 'Origem (Componente DC)');
hold off;

disp('Processo finalizado com sucesso! Pressione "Enter" no terminal para fechar o gráfico e sair.');
pause;
