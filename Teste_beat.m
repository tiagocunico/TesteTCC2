pkg load signal; % Necessario para a funcao findpeaks no Octave
clear all; close all; clc;

% --- 1. Parametros e Sinal de Teste ---
fs = 100;               % Frequencia de amostragem (Hz)
T_total = 20;           % 20 segundos de video
t = 0:1/fs:T_total-1/fs;

% Simulando gotas reais (pulsos curtos) a 1.2 Hz (72 BPM)
f_real = 1.2; 
sinal_puro = mod(t, 1/f_real) < 0.05; % Gera pulsos de 50ms
ruido = 0.5 * randn(size(t));         % Ruido branco forte
x = sinal_puro + ruido;

% --- 2. Pre-processamento (Extracao de Envelope) ---
x_rect = abs(x);
[b, a] = butter(2, 5/(fs/2)); % Filtro passa-baixa de 5Hz para limpar o ruido
envelope = filtfilt(b, a, x_rect);

% --- 3. Autocorrelacao ---
% r eh o vetor de correlacao, lags eh o atraso em amostras
[r, lags] = xcorr(envelope, 'coeff');

% Pegamos apenas a metade positiva (atrasos de tempo reais)
meio = floor(length(lags)/2) + 1;
r_pos = r(meio:end);
lags_pos = lags(meio:end);

% --- 4. Busca do "Beat" (Primeiro Pico Significativo) ---
% Ignoramos o lag zero (correlacao 1.0) e ruidos de curtissimo prazo
dist_min = 0.25 * fs; % Considera no maximo 240 BPM
[pks, locs] = findpeaks(r_pos, "MinPeakDistance", dist_min, "MinPeakHeight", 0.2);

% O primeiro pico apos o zero representa o periodo (intervalo entre gotas)
if !isempty(locs)
    lag_batida = lags_pos(locs(1)); % Distancia em amostras
    periodo_segundos = lag_batida / fs;
    bpm_estimado = 60 / periodo_segundos;
    freq_estimado = 1 / periodo_segundos;
else
    bpm_estimado = 0;
    freq_estimado = 0;
end

% --- 5. Graficos ---
figure('Name', 'Beat Tracking por Autocorrelacao');

subplot(3,1,1);
plot(t, x, 'color', [0.7 0.7 0.7]); hold on;
plot(t, envelope, 'r', 'LineWidth', 1.5);
title('Sinal Original e Envelope (Filtro Passa-Baixa)');
legend('Sinal Bruto', 'Envelope');

subplot(3,1,2);
plot(lags_pos/fs, r_pos); hold on;
if !isempty(locs)
    plot(lags_pos(locs(1))/fs, r_pos(locs(1)), 'ro', 'MarkerSize', 10);
end
title('Autocorrelacao: O Pico indica o Intervalo entre Gotas');
xlabel('Atraso (Segundos)'); ylabel('Similaridade');

subplot(3,1,3);
text(0.1, 0.7, ['Frequencia Real: ', num2str(f_real), ' Hz'], 'FontSize', 12);
text(0.1, 0.4, ['Frequencia Estimada: ', num2str(freq_estimado), ' Hz'], 'FontSize', 12, 'Color', 'red');
text(0.1, 0.1, ['BPM Estimado: ', num2str(bpm_estimado)], 'FontSize', 12);
axis off; title('Resultado Final do Beat Tracking');

disp(['BPM Estimado: ', num2str(bpm_estimado)]);
pause;