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
nome_arquivo = 'Lento 1_17s.mp4';
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
linha_inicio = 1;
linha_fim = min(3000, pixels_por_frame);
faixa_temporal = imagem_temporal(linha_inicio:linha_fim, :);

disp(['Plotando recorte do Kymograph (Linhas ' num2str(linha_inicio) ' a ' num2str(linha_fim) ')']);

figure('Name', 'Analise Visual das Linhas 2000-3000 - Lento', 'Position', [100, 100, 1000, 600]);

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
clear all; close all; clc;

fs = 20;            % Frequência de amostragem (FPS do seu vídeo)
T_total = 10;       % Tempo total em segundos
Ts = 1/fs;
t = 0:Ts:T_total-Ts;
N = length(t);

% Resolução da FFT (O "passo" real da sua análise)
delta_f = 1/T_total; 

x = zeros(1,N);

% CORREÇÃO: Passo do loop igual à resolução da FFT (0.1 Hz)
for f = 0.1 : delta_f : 2.5
    if abs(f - 1.0) < 0.01  % Destaca a frequência de 1Hz (simulando a gota)
        k = 1;
    else
        k = 0.1;            % Outras frequências como ruído de fundo menor
    end
    
    % Gerando a senoide limpa (sem fase aleatória para teste inicial)
    x = x + k * sin(2 * pi * f * t);
end

% Janelamento (Opcional, mas ajuda muito na vida real) [cite: 316, 382]
% w = hamming(N);
% x = x .* w';

X = fft(x);
eixo_f = (0:N-1) * (fs/N);

subplot(2,1,1);
plot(t, x);
title('Sinal no Tempo (Soma de Senoides)');
xlabel('Tempo (s)');

subplot(2,1,2);
% Mostra apenas até fs/2 (Nyquist) [cite: 289, 391]
stem(eixo_f(1:floor(N/2)), abs(X(1:floor(N/2))));
title(['Espectro de Frequência - Resolução: ', num2str(delta_f), ' Hz']);
xlabel('Frequência (Hz)');