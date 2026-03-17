% =========================================================================
% SCRIPT: TESTES DE FILTRO PASSA-FAIXA - VÍDEO LENTO (Baixa Frequência)
% Video: Lento 1.mp4
% Objetivo: Analisar sinal de baixa frequência (~0.17 Hz) com:
%   Teste 1: Imagem Inteira
%   Teste 2: Linha COM o sinal
%   Teste 3: Linha SEM o sinal
%   + Detecção de Picos no domínio do tempo (mais confiável para poucos ciclos)
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
    disp('AVISO: Pacote signal nao encontrado. Tente rodar: pkg install -forge signal');
end

% =========================================================================
% CONFIGURAÇÕES E LEITURA DO VÍDEO
% =========================================================================
pasta_video = 'video_input';
nome_arquivo = 'Lento 1.mp4';
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
disp(['Duracao total do video: ', num2str(total_frames/fps, '%.1f'), ' segundos']);

% =========================================================================
% CRIAÇÃO DO FILTRO PASSA-FAIXA
% =========================================================================
% NOTA: Para frequências muito baixas (< 0.5Hz), o Butterworth pode ser
% numericamente instável. Aqui usamos ordem 1 para maior estabilidade,
% e um filtro simples de média móvel como alternativa.
f_nyquist = fps / 2;
freq_corte = [0.05 2.1] / f_nyquist;  % Faixa 0.05 a 0.5 Hz

% Butterworth ordem 1 (mais estável para frequências muito baixas)
[b, a] = butter(1, freq_corte, 'bandpass');

% Verifica estabilidade do filtro
if any(abs(roots(a)) >= 1)
    disp('AVISO: Filtro Butterworth instavel! Usando filtro alternativo...');
    % Fallback: janela de media movel larga (equivalente a LP) menos HP simples
    b = ones(1, round(fps)) / round(fps);
    a = 1;
end

% =========================================================================
% FUNÇÃO AUXILIAR: Processar e extrair frequência via FFT
% =========================================================================
function [sinal_filtrado, freq_pico, espectro_1d] = processar_sinal(sinal, b, a, fps)
    sinal = double(sinal(:)') - mean(sinal);

    % Aplicar Filtro
    try
        sinal_filtrado = filtfilt(b, a, sinal);
    catch
        sinal_filtrado = sinal;
        disp('AVISO: filtfilt falhou, usando sinal bruto');
    end

    % FFT sem remoção agressiva do DC
    N = length(sinal_filtrado);
    fft_1d = fft(sinal_filtrado);
    espectro_1d = abs(fft_1d(1:floor(N/2)));

    % Remover apenas os primeiros 2 bins (DC e vizinho imediato)
    espectro_busca = espectro_1d;
    espectro_busca(1:2) = 0;

    [~, loc] = max(espectro_busca);
    freq_pico = (loc - 1) * (fps / N);
end

% =========================================================================
% FUNÇÃO AUXILIAR: Detecção de Picos no Tempo (mais confiável para baixa freq)
% =========================================================================
function freq_detectada = detectar_picos(sinal, fps, nome)
    sinal_norm = sinal - mean(sinal);
    N = length(sinal_norm);

    % Suavização com média móvel (janela ~2 segundos para sinal lento)
    janela = min(round(fps * 2), floor(N / 4));
    kernel = ones(1, janela) / janela;
    sinal_suave = conv(sinal_norm, kernel, 'same');

    % Detecção de máximos locais com distância mínima entre picos (3s)
    dist_minima = round(fps * 3);
    picos_idx = [];
    threshold = 0.3 * max(sinal_suave);

    for i = (dist_minima+1):(N-dist_minima)
        if sinal_suave(i) > threshold
            janela_local = sinal_suave(max(1,i-dist_minima):min(N,i+dist_minima));
            if sinal_suave(i) == max(janela_local)
                picos_idx(end+1) = i;
            end
        end
    end

    if length(picos_idx) >= 2
        periodos = diff(picos_idx) / fps;
        periodo_medio = mean(periodos);
        freq_detectada = 1 / periodo_medio;

        disp(['  ' nome ': ' num2str(length(picos_idx)), ' picos detectados']);
        for k = 1:length(picos_idx)
            disp(['    Pico ' num2str(k) ': frame=' num2str(picos_idx(k)) ...
                  ' (t=' num2str(picos_idx(k)/fps, '%.2f') 's)']);
        end
        disp(['  Periodos entre picos (s): ' num2str(periodos, '%.2f ')]);
        disp(['  Frequencia estimada (picos): ', num2str(freq_detectada, '%.4f'), ' Hz']);
    else
        freq_detectada = 0;
        disp(['  ' nome ': picos insuficientes detectados (< 2). Ajuste a linha escolhida.']);
    end
end

% =========================================================================
% SELEÇÃO DAS LINHAS (MANUAL)
% =========================================================================
% << RODE visualizar_faixa_lento.m PRIMEIRO PARA VER AS LINHAS DESTE VIDEO >>
LINHA_COM_SINAL = 2299;  % << AJUSTAR APÓS VER O GRÁFICO >>
LINHA_SEM_SINAL = 666;   % << AJUSTAR APÓS VER O GRÁFICO >>

% =========================================================================
% CÁLCULO DOS SINAIS
% =========================================================================
sinal_inteiro = mean(imagem_temporal, 1);
sinal_linha_com = imagem_temporal(LINHA_COM_SINAL, :);
sinal_linha_sem = imagem_temporal(LINHA_SEM_SINAL, :);

[sinal_inteiro_filtrado, freq1, espectro1] = processar_sinal(sinal_inteiro, b, a, fps);
[sinal_linha_com_filtrado, freq2, espectro2] = processar_sinal(sinal_linha_com, b, a, fps);
[sinal_linha_sem_filtrado, freq3, espectro3] = processar_sinal(sinal_linha_sem, b, a, fps);

disp('=========================================================================');
disp('RESULTADOS - FFT:');
disp(['  Teste 1 (Imagem Inteira):           ', num2str(freq1, '%.4f'), ' Hz']);
disp(['  Teste 2 (Linha ', num2str(LINHA_COM_SINAL), ' - Com Sinal):  ', num2str(freq2, '%.4f'), ' Hz']);
disp(['  Teste 3 (Linha ', num2str(LINHA_SEM_SINAL), ' - Sem Sinal): ', num2str(freq3, '%.4f'), ' Hz']);
disp('=========================================================================');
disp(' ');
disp('RESULTADOS - DETECÇÃO DE PICOS (domínio do tempo):');
freq_picos1 = detectar_picos(sinal_inteiro_filtrado, fps, 'Imagem Inteira');
freq_picos2 = detectar_picos(sinal_linha_com_filtrado, fps, ['Linha ' num2str(LINHA_COM_SINAL)]);
freq_picos3 = detectar_picos(sinal_linha_sem_filtrado, fps, ['Linha ' num2str(LINHA_SEM_SINAL)]);
disp('=========================================================================');

% =========================================================================
% GRÁFICOS
% =========================================================================
disp('Preparando gráficos...');

tempo = (0:total_frames-1) * (1/fps);
vetor_freq = (0:total_frames-1) * (fps / total_frames);
N_half = floor(total_frames/2);

figure('Name', 'Testes Filtro Passa-Faixa - Video Lento', 'Position', [50, 50, 1100, 800]);

% Teste 1: Imagem Inteira
subplot(3, 2, 1);
plot(tempo, sinal_inteiro_filtrado, 'b', 'LineWidth', 1.5);
title('Teste 1: Sinal Filtrado (Imagem Inteira)');
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3, 2, 2);
bar(vetor_freq(1:N_half), espectro1, 'b');
title(['Espectro FFT Teste 1 | Pico: ', num2str(freq1, '%.3f'), ' Hz']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on;
xlim([0, 1]);  % zoom em 0-1 Hz para ver a frequência baixa

% Teste 2: Linha COM Sinal
subplot(3, 2, 3);
plot(tempo, sinal_linha_com_filtrado, 'g', 'LineWidth', 1.5);
title(['Teste 2: Sinal Filtrado (Linha ', num2str(LINHA_COM_SINAL), ' - Com Sinal)']);
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3, 2, 4);
bar(vetor_freq(1:N_half), espectro2, 'g');
title(['Espectro FFT Teste 2 | Pico: ', num2str(freq2, '%.3f'), ' Hz']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on;
xlim([0, 1]);

% Teste 3: Linha SEM Sinal
subplot(3, 2, 5);
plot(tempo, sinal_linha_sem_filtrado, 'r', 'LineWidth', 1.5);
title(['Teste 3: Sinal Filtrado (Linha ', num2str(LINHA_SEM_SINAL), ' - Sem Sinal)']);
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3, 2, 6);
bar(vetor_freq(1:N_half), espectro3, 'r');
title(['Espectro FFT Teste 3 | Pico: ', num2str(freq3, '%.3f'), ' Hz']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on;
xlim([0, 1]);

disp('Concluído! Pressione enter no terminal para fechar.');
pause;
