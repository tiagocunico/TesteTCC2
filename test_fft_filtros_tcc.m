% =========================================================================
% SCRIPT: TESTES DE FILTRO PASSA-FAIXA (0.5 - 3.0 Hz) NO VÍDEO
% Objetivo: Fazer 3 testes de extração de sinal de um vídeo Real:
% Teste 1: Da imagem inteira (média de todas as linhas)
% Teste 2: De uma linha com o sinal (Ex: Linha sugerida pelo Python/Octave)
% Teste 3: De uma linha sem o sinal (Ex: Linha 1500)
% =========================================================================
clear all; close all; clc;

% Carrega os pacotes necessarios
pkg load image;
try
    pkg load video;
catch
    disp('AVISO: Pacote video nao encontrado. Tente rodar: pkg install -forge video');
end
try
    pkg load signal;
catch
    disp('AVISO: Pacote signal nao encontrado. O filtro bandpass requer esse pacote.');
    disp('Tente rodar: pkg install -forge signal');
end

% =========================================================================
% CONFIGURAÇÕES E LEITURA DO VÍDEO
% =========================================================================
pasta_video = 'video_input';
nome_arquivo = 'Rapido_1_5s.mp4';
caminho_completo = fullfile(pasta_video, nome_arquivo);

fator_redimensionamento = 0.05;

if ~exist(caminho_completo, 'file')
  error(['Arquivo não encontrado: ' caminho_completo]);
end

disp(['Carregando vídeo: ' caminho_completo]);
v = VideoReader(caminho_completo);
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
  frame_redimensionado = imresize(frame, fator_redimensionamento);
  video_3d(:, :, frame_idx) = double(frame_redimensionado);
  frame_idx = frame_idx + 1;
end

[dim_altura, dim_largura, total_frames] = size(video_3d);
pixels_por_frame = dim_altura * dim_largura;
imagem_temporal = reshape(video_3d, pixels_por_frame, total_frames);

disp(['Tamanho do Cubo 3D: ', num2str(dim_altura), 'x', num2str(dim_largura), 'x', num2str(total_frames)]);
disp(['Tamanho da Matriz 2D (Kymograph): ', num2str(pixels_por_frame), ' linhas x ', num2str(total_frames), ' colunas']);

% =========================================================================
% CRIAÇÃO DO FILTRO PASSA-FAIXA (0.5 a 3.0 Hz)
% =========================================================================
f_nyquist = fps / 2;
freq_corte = [0.5 3.0] / f_nyquist;

% Usaremos um filtro Butterworth de ordem 2 para o bandpass
[b, a] = butter(2, freq_corte, 'bandpass');

% Função para aplicar filtro, calcular FFT e encontrar pico
function [sinal_filtrado, freq_pico, picos_1d] = processar_sinal(sinal, b, a, fps)
    % Ignorar possíveis NaNs e remover DC (embora o bandpass já o faça)
    sinal = sinal - mean(sinal);
    
    % Aplicar Filtro Passa Faixas
    sinal_filtrado = filtfilt(b, a, sinal);
    
    % Calcular FFT
    fft_1d = fft(sinal_filtrado);
    espectro_1d = abs(fft_1d);
    
    % Remover DC e metade superior (Nyquist)
    total_frames = length(sinal);
    dist_segura_bins = max(3, ceil(total_frames * 0.05));
    
    picos_1d = zeros(size(espectro_1d));
    for i = 1:length(espectro_1d)
        maior_esq = (i == 1) || (espectro_1d(i) >= espectro_1d(i-1));
        maior_dir = (i == length(espectro_1d)) || (espectro_1d(i) >= espectro_1d(i+1));
        if maior_esq && maior_dir
            picos_1d(i) = espectro_1d(i);
        end
    end
    
    for i = 1:dist_segura_bins
        if i <= length(picos_1d)
            picos_1d(i) = 0;
        end
        if (length(picos_1d) - i + 1) >= 1
            picos_1d(length(picos_1d) - i + 1) = 0;
        end
    end
    
    [~, loc_max_1d] = max(picos_1d);
    freq_pico = (loc_max_1d - 1) * (fps / total_frames);
end

% =========================================================================
% SELEÇÃO DAS LINHAS (MANUAL)
% =========================================================================
% << DEFINA AQUI A LINHA EXATA VISTA NO SCRIPT visualizar_faixa.m >>
LINHA_COM_SINAL = 2458; 

% << DEFINA AQUI A LINHA SEM SINAL QUE O SEU ORIENTADOR PEDIU >>
LINHA_SEM_SINAL = 3200;

% =========================================================================
% TESTE 0: Verificação (Média 3D vs Média 2D/Kymograph)
% =========================================================================
disp('--- TESTE 0: VERIFICANDO VETORIZAÇÃO 3D vs 2D ---');
% Calculando a média antes de vetorizar (direto no Cubo 3D)
sinal_cubo_3d = squeeze(mean(mean(video_3d, 1), 2))';

% Calculando a média depos de vetorizar (no Kymograph 2D)
sinal_inteiro_2d = mean(imagem_temporal, 1);

% Verifica a diferença matemática
erro_maximo = max(abs(sinal_cubo_3d - sinal_inteiro_2d));
disp(['Diferenca maxima entre calcular antes ou depois de vetorizar: ', num2str(erro_maximo)]);
disp('Conclusao: Matematicamente as duas operacoes geram o MESMO sinal!');
disp(' ');

% =========================================================================
% TESTE 1: Da Imagem Inteira
% =========================================================================
disp('--- TESTE 1: IMAGEM INTEIRA ---');
sinal_inteiro = sinal_inteiro_2d;
[sinal_inteiro_filtrado, freq1, espectro1] = processar_sinal(sinal_inteiro, b, a, fps);
disp(['Frequencia extraída (Imagem Inteira): ', num2str(freq1, '%.4f'), ' Hz']);

% =========================================================================
% TESTE 2: De uma linha COM O SINAL 
% =========================================================================
disp(['--- TESTE 2: LINHA ', num2str(LINHA_COM_SINAL), ' (COM SINAL) ---']);
sinal_linha_com = imagem_temporal(LINHA_COM_SINAL, :);
[sinal_linha_com_filtrado, freq2, espectro2] = processar_sinal(sinal_linha_com, b, a, fps);
disp(['Frequencia extraída (Linha ', num2str(LINHA_COM_SINAL), '): ', num2str(freq2, '%.4f'), ' Hz']);

% =========================================================================
% TESTE 3: De uma linha SEM O SINAL
% =========================================================================
disp(['--- TESTE 3: LINHA ', num2str(LINHA_SEM_SINAL), ' (SEM SINAL) ---']);
sinal_linha_sem = imagem_temporal(LINHA_SEM_SINAL, :);
[sinal_linha_sem_filtrado, freq3, espectro3] = processar_sinal(sinal_linha_sem, b, a, fps);
disp(['Frequencia extraída (Linha ', num2str(LINHA_SEM_SINAL), '): ', num2str(freq3, '%.4f'), ' Hz']);

% =========================================================================
% PLOT DOS RESULTADOS
% =========================================================================
disp('Preparando gráficos dos 3 testes...');

figure('Name', 'Testes de Filtro Passa-Faixa (0.5 - 3Hz)', 'Position', [100, 100, 1000, 800]);
tempo = (0:total_frames-1) * (1/fps);
vetor_freq = (0:total_frames-1) * (fps / total_frames);

% Plot 1: Imagem Inteira
subplot(3, 2, 1);
plot(tempo, sinal_inteiro_filtrado, 'b', 'LineWidth', 1.5);
title('Teste 1: Sinal Filtrado (Imagem Inteira)');
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3, 2, 2);
bar(vetor_freq(1:floor(end/2)), espectro1(1:floor(end/2)), 'b');
title(['Espectro Teste 1 | Pico: ', num2str(freq1, '%.3f'), ' Hz']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on;
xlim([0, 5]); % Mostrando apenas de 0 a 5Hz para dar "zoom" no filtro

% Plot 2: Linha COM Sinal
subplot(3, 2, 3);
plot(tempo, sinal_linha_com_filtrado, 'g', 'LineWidth', 1.5);
title(['Teste 2: Sinal Filtrado (Linha ', num2str(LINHA_COM_SINAL), ' - Com Sinal)']);
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3, 2, 4);
bar(vetor_freq(1:floor(end/2)), espectro2(1:floor(end/2)), 'g');
title(['Espectro Teste 2 | Pico: ', num2str(freq2, '%.3f'), ' Hz']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on;
xlim([0, 5]);

% Plot 3: Linha SEM Sinal
subplot(3, 2, 5);
plot(tempo, sinal_linha_sem_filtrado, 'r', 'LineWidth', 1.5);
title(['Teste 3: Sinal Filtrado (Linha ', num2str(LINHA_SEM_SINAL), ' - Sem Sinal)']);
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3, 2, 6);
bar(vetor_freq(1:floor(end/2)), espectro3(1:floor(end/2)), 'r');
title(['Espectro Teste 3 | Pico: ', num2str(freq3, '%.3f'), ' Hz']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on;
xlim([0, 5]);

disp('Concluído! Pressione enter no terminal para fechar.');
pause;
