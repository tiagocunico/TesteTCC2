clear all; close all; clc;

% --- Parametros de Simulacao ---
fs = 20;            % FPS do video
T_total = 100;      % Tempo total em segundos
Ts = 1/fs;
t = 0:Ts:T_total-Ts;
N = length(t);
delta_f = 1/T_total; % Resolucao real da FFT (0.01 Hz)

% FREQUENCIA DESAFIO: 1.005 Hz (Cai entre os bins 1.00 e 1.01)
f_alvo = 1.005; 

x_correto = zeros(1,N);
x_antigo = zeros(1,N);

% --- 1. SINAL COM PASSO = DELTA F (0.01) ---
for f = 0.1 : delta_f : 2.5
    if abs(f - f_alvo) < 0.006
        k = 1.0;
    else
        k = 0.1;
    end
    x_correto = x_correto + k * sin(2 * pi * f * t + 2 * pi * rand());
end

% --- 2. SINAL AMONTOADO (PASSO 0.001) ---
passo_antigo = 0.001;
for f = 0.1 : passo_antigo : 2.5
    if abs(f - f_alvo) < 0.006
        k = 1.0;
    else
        k = 0.1;
    end
    x_antigo = x_antigo + k * sin(2 * pi * f * t + 2 * pi * rand());
end

% --- Processamento FFT ---
X_correto = abs(fft(x_correto));
X_antigo = abs(fft(x_antigo));
eixo_f = (0:N-1) * (fs/N);

% --- 3. REFINAMENTO GAUSSIANO (Matteis 2020) ---
[mag_max, idx_max] = max(X_antigo(1:floor(N/2)));
% Seleciona 5 pontos ao redor do pico para a curva
janela = idx_max-2 : idx_max+2;
f_janela = eixo_f(janela);
mag_janela = X_antigo(janela);

% Ajuste parabolico no logaritmo (Metodologia Matteis)
% ln(Gaussiana) = Parabola
p = polyfit(f_janela, log(mag_janela), 2);
f_estimada_gauss = -p(2) / (2 * p(1));

% --- GRAFICOS ---
figure('Name', 'Analise de Precisao: FFT vs Gaussian Fitting');

% Linha 1: Resolucao Sincronizada
subplot(3,2,1); plot(t, x_correto); 
title(['Tempo: Passo = ', num2str(delta_f)]);
subplot(3,2,2); stem(eixo_f(1:floor(N/10)), X_correto(1:floor(N/10)));
title(['FFT: Bins em ', num2str(delta_f), ' Hz']); grid on;

% Linha 2: Amontoado com Passo 0.001
subplot(3,2,3); plot(t, x_antigo); 
title(['Tempo: Passo = ', num2str(passo_antigo), ' (Amontoado)']);
subplot(3,2,4); stem(eixo_f(1:floor(N/10)), X_antigo(1:floor(N/10)));
title(['FFT: Amontoamento (Passo: ', num2str(passo_antigo), ')']); grid on;

% Linha 3: O "Pulo do Gato" - Gaussian Fitting
subplot(3,2,5); 
plot(f_janela, mag_janela, 'bo', 'MarkerSize', 8); hold on;
f_curva = linspace(min(f_janela), max(f_janela), 100);
mag_curva = exp(polyval(p, f_curva));
plot(f_curva, mag_curva, 'r-', 'LineWidth', 2);
title('Refinamento: Ajuste de Curva no Pico'); xlabel('Frequencia (Hz)');

subplot(3,2,6);
text(0.1, 0.8, ['Frequencia Real: ', num2str(f_alvo), ' Hz'], 'FontSize', 12);
text(0.1, 0.5, ['Pico Bruto FFT: ', num2str(eixo_f(idx_max)), ' Hz'], 'FontSize', 12);
text(0.1, 0.2, ['Estimativa Gauss: ', num2str(f_estimada_gauss), ' Hz'], 'FontSize', 12, 'Color', 'red');
axis off; title('Comparativo de Precisao Sub-bin');

disp(['Concluido! Frequencia estimada: ', num2str(f_estimada_gauss), ' Hz']);
pause;