% Script para calcular a FFT 3D de um vídeo real
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
nome_arquivo = 'Rapido_1_5s.mp4'; % <-- Nosso vídeo recortado
caminho_completo = fullfile(pasta_video, nome_arquivo);

fator_redimensionamento = 0.1; % 10% do tamanho original para não estourar a RAM!
mostrar_grafico = true;

% -------------------------------------------------------------------------
% VERIFICAÇÃO E LEITURA
% -------------------------------------------------------------------------
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

% Extrai informações do VideoReader
fps = v.FrameRate;
disp(['Taxa de quadros do vídeo (FPS): ', num2str(fps)]);

video_3d = [];
frame_idx = 1;

disp(['Lendo e pré-processando frames (Redimensionando para ', num2str(fator_redimensionamento*100), '%)...']);
while hasFrame(v)
  frame = readFrame(v);
  
  if size(frame, 3) == 3
      frame = rgb2gray(frame); % Converte para tons de cinza
  end
  
  % Redimensiona o frame para poupar muita memória e acelerar a FFT 3D
  frame_redimensionado = imresize(frame, fator_redimensionamento);
  
  video_3d(:, :, frame_idx) = double(frame_redimensionado);
  frame_idx = frame_idx + 1;
end

[Ny, Nx, Nt] = size(video_3d);
disp(['Tamanho da matriz 3D final para cálculo (Y x X x Tempo): ', num2str(Ny), ' x ', num2str(Nx), ' x ', num2str(Nt)]);

% -------------------------------------------------------------------------
% CÁLCULO DA FFT 3D
% -------------------------------------------------------------------------
disp('Calculando a FFT 3D. Isso pode demorar alguns segundos...');
fft_result = fftn(video_3d);
fft_shifted = fftshift(fft_result); % Centraliza a frequência zero (DC)

% Calcula a magnitude
magnitude = abs(fft_shifted);
magnitude_log = log10(1 + magnitude);

% -------------------------------------------------------------------------
% EXTRAÇÃO DA FREQUÊNCIA A PARTIR DOS DADOS DA FFT
% -------------------------------------------------------------------------
disp('Extraindo Frequência Fundamental do Tempo...');
% Eixos reais em HZ
fy = (-Ny/2 : Ny/2 - 1) * (1 / Ny); % Normalizado provisório
fx = (-Nx/2 : Nx/2 - 1) * (1 / Nx);
% O eixo do tempo já em Hz de verdade (ciclos por segundo):
ft = linspace(-fps/2, fps/2, Nt);

% Achata as dimensões espaciais (tira a média) para criar apenas o vetor temporal (Z)
if mod(Ny, 2) ~= 0 || mod(Nx, 2) ~= 0 || mod(Nt, 2) ~= 0
   % Pra simplificar o plot de teste assumimos sinal par pro shift ficar inteiro
   disp('AVISO: Matrix com dimensão impar, eixos aproximados');
end

espectro_tempo = squeeze(mean(mean(magnitude, 1), 2));

% Filtra apenas Picos Locais
picos = zeros(size(espectro_tempo));
for i = 1:length(espectro_tempo)
    maior_esq = (i == 1) || (espectro_tempo(i) >= espectro_tempo(i-1));
    maior_dir = (i == length(espectro_tempo)) || (espectro_tempo(i) >= espectro_tempo(i+1));

    if maior_esq && maior_dir
        picos(i) = espectro_tempo(i);
    end
end

% Acha e remove DC
[~, idx_dc] = min(abs(ft));
picos(idx_dc) = 0; 
picos(idx_dc + 1) = 0;
picos(max(1, idx_dc - 1)) = 0;
% Dá mais margem para vídeo real tirando o vizinho próximo
picos(min(length(picos), idx_dc + 2)) = 0;
picos(max(1, idx_dc - 2)) = 0;

% O próximo maior pico de energia restante é a nossa Frequência Fundamental.
[val_max, loc_max] = max(picos);

% Associa o índice encontrado ao valor real da frequência em Hz
freq_fft_encontrada = abs(ft(loc_max));

disp('-------------------------------------------------------------------------');
disp([' Frequência Fundamental EXTRAÍDA CEGAMENTE PELA FFT 3D: ', num2str(freq_fft_encontrada, '%.4f'), ' Hz']);
disp('-------------------------------------------------------------------------');

% -------------------------------------------------------------------------
% GERAÇÃO DO GRÁFICO 3D
% -------------------------------------------------------------------------
if mostrar_grafico
    disp('Preparando o gráfico 3D...');
    
    [X, Y, T] = meshgrid(fx, fy, ft); 
    
    threshold = prctile(magnitude_log(:), 99);
    idx = find(magnitude_log > threshold);
    
    figure('Name', 'Analise FFT 3D Real', 'Position', [100, 100, 800, 600]);
    
    scatter3(X(idx), Y(idx), T(idx), 20, magnitude_log(idx), 'filled');
    xlabel('Freq. Espacial X');
    ylabel('Freq. Espacial Y');
    zlabel('Freq. Temporal (Hz)');
    title(['Espectro FFT 3D - Vídeo Real (' num2str(Ny), 'x', num2str(Nx), 'px)']);
    colormap('jet');
    c = colorbar;
    ylabel(c, 'Magnitude Logarítmica');
    grid on;
    
    hold on;
    plot3(0, 0, 0, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r'); % DC normal
    plot3(0, 0, freq_fft_encontrada, 'gp', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
    plot3(0, 0, -freq_fft_encontrada, 'gp', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
    legend('Frequências Dominantes', 'Origem (DC)', 'Frequência Detectada');
    hold off;
    
    disp('Processo finalizado com sucesso! Pressione "Enter" no terminal para fechar o gráfico e sair.');
    pause;
end
