% =========================================================================
% SCRIPT GENÉRICO: FILTRO PASSA-FAIXA 0.5 - 3.0 Hz (Butterworth Ordem 5)
% =========================================================================
% Algoritmo único para qualquer vídeo.
% Edite APENAS a seção de configuração abaixo.
% =========================================================================
clear all; close all; clc;

pkg load image;
try; pkg load video; catch; disp('AVISO: pkg video nao encontrado'); end
try; pkg load signal; catch; disp('AVISO: pkg signal nao encontrado'); end

% =========================================================================
%   <<< CONFIGURAÇÕES (EDITE AQUI) >>>
% =========================================================================

% Arquivo de vídeo
pasta_video           = 'video_input';
nome_arquivo          = 'Rapido_1_5s.mp4';  % << MUDE O NOME DO VÍDEO
fator_redimensionamento = 0.05;

% Linhas do Kymograph (use visualizar_faixa.m para descobrir)
%Rapido
 LINHA_COM_SINAL = 2458;  % << linha com o sinal de interesse
 LINHA_SEM_SINAL = 3200;  % << linha sem sinal (referência)

%Lento
%LINHA_COM_SINAL = 4500;  % << AJUSTAR APÓS VER O GRÁFICO >>
%LINHA_SEM_SINAL = 2299;   % << AJUSTAR APÓS VER O GRÁFICO >>

% Filtro passa-faixa (fixo conforme solicitado pelo orientador)
FREQ_BAIXA  = 0.1;   % Hz
FREQ_ALTA   = 2.5;   % Hz
ORDEM_FILTRO = 5;    % Butterworth ordem 5

% Ativar/desativar detecção de picos no tempo (true = ativa, false = desativa)
DETECTAR_PICOS = false;

% =========================================================================
%   <<< FIM DAS CONFIGURAÇÕES >>>
% =========================================================================

% -------------------------------------------------------------------------
% LEITURA DO VÍDEO
% -------------------------------------------------------------------------
caminho_completo = fullfile(pasta_video, nome_arquivo);
if ~exist(caminho_completo, 'file')
  error(['Arquivo nao encontrado: ' caminho_completo]);
end

disp(['Carregando: ' caminho_completo]);
v   = VideoReader(caminho_completo);
fps = v.FrameRate;
disp(['FPS: ', num2str(fps)]);

video_3d = []; frame_idx = 1;
while hasFrame(v)
  frame = readFrame(v);
  if size(frame,3)==3; frame = rgb2gray(frame); end
  video_3d(:,:,frame_idx) = double(imresize(frame, fator_redimensionamento));
  frame_idx = frame_idx + 1;
end

[Ny, Nx, Nt] = size(video_3d);
Npx = Ny * Nx;
kymograph = reshape(video_3d, Npx, Nt);

disp(['Cubo 3D: ', num2str(Ny),'x',num2str(Nx),'x',num2str(Nt)]);
disp(['Kymograph: ', num2str(Npx),' linhas x ',num2str(Nt),' frames']);
disp(['Duracao: ', num2str(Nt/fps,'%.1f'), 's  |  Resolucao FFT: ', num2str(fps/Nt,'%.4f'),' Hz/bin']);

% -------------------------------------------------------------------------
% FILTRO BUTTERWORTH ORDEM 5
% -------------------------------------------------------------------------
f_nyq     = fps / 2;
freq_norm = [FREQ_BAIXA FREQ_ALTA] / f_nyq;

% A função butter com 'bandpass' e ordem N cria um filtro de ordem 2N internamente
[b, a] = butter(ORDEM_FILTRO, freq_norm, 'bandpass');

% Verifica estabilidade
if any(abs(roots(a)) >= 1)
    disp('AVISO: Filtro instavel (ordem muito alta para o FPS). Reduzindo para ordem 2...');
    [b, a] = butter(2, freq_norm, 'bandpass');
    ORDEM_FILTRO = 2;
end
disp(['Filtro Butterworth ordem ', num2str(ORDEM_FILTRO), ' (', ...
      num2str(FREQ_BAIXA),'-',num2str(FREQ_ALTA),' Hz) - estavel.']);

% -------------------------------------------------------------------------
% FUNÇÃO: Filtra, calcula FFT e detecta pico
% -------------------------------------------------------------------------
function [s_filt, f_fft, espectro, confiabilidade] = analisar(sinal, b, a, fps)
    s = double(sinal(:)') - mean(sinal);
    try; s_filt = filtfilt(b, a, s); catch; s_filt = s; end
    N = length(s_filt);
    espectro = abs(fft(s_filt));
    espectro = espectro(1:floor(N/2));
    
    % Zera APENAS o componente DC (0 Hz). Permite frequências muito baixas.
    busca = espectro; 
    busca(1) = 0;
    
    [~, loc] = max(busca);
    f_fft = (loc - 1) * (fps / N);
    
    % --- Índice de Confiabilidade (Proporção de Variância Explicada) ---
    % Calcula quanta variância do espectro é atribuída exclusivamente ao pico (0 a 100%)
    variancia_total = var(busca);
    
    if variancia_total > 0
        busca_sem_pico = busca;
        idx_pico = max(3, loc-1) : min(length(busca), loc+1);
        busca_sem_pico(idx_pico) = mean(busca); % Suaviza a área do pico para ver apenas o "ruído"
        
        variancia_ruido = var(busca_sem_pico);
        confiabilidade = max(0, (1 - (variancia_ruido / variancia_total)) * 100);
    else
        confiabilidade = 0;
    end
end

% -------------------------------------------------------------------------
% FUNÇÃO: Detecção de picos no tempo
% -------------------------------------------------------------------------
function f_pico = detectar_picos(sinal, fps, nome)
    N = length(sinal);
    janela = min(round(fps * 2), floor(N/4));
    s_suave = conv(sinal - mean(sinal), ones(1,janela)/janela, 'same');
    dist_min = max(round(fps * 1.5), 10);
    limiar = 0.3 * max(abs(s_suave));
    idx_picos = [];
    for i = (dist_min+1):(N-dist_min)
        if s_suave(i) > limiar
            viz = s_suave(max(1,i-dist_min):min(N,i+dist_min));
            if s_suave(i) == max(viz); idx_picos(end+1) = i; end
        end
    end
    if length(idx_picos) >= 2
        periodos = diff(idx_picos) / fps;
        f_pico = 1 / mean(periodos);
        disp([nome ': ' num2str(length(idx_picos)) ' picos | periodos: ' ...
              num2str(periodos,'%.2f ') 's | freq: ' num2str(f_pico,'%.4f') ' Hz']);
    else
        f_pico = NaN;
        disp([nome ': picos insuficientes. Verifique a linha escolhida.']);
    end
end

% -------------------------------------------------------------------------
% 3 TESTES
% -------------------------------------------------------------------------
sinal1 = mean(kymograph, 1);
sinal2 = kymograph(LINHA_COM_SINAL, :);
sinal3 = kymograph(LINHA_SEM_SINAL, :);

[s1, f1, esp1, conf1] = analisar(sinal1, b, a, fps);
[s2, f2, esp2, conf2] = analisar(sinal2, b, a, fps);
[s3, f3, esp3, conf3] = analisar(sinal3, b, a, fps);

disp(' ');
disp('===== RESULTADOS FFT =====');
disp(['Teste 1 (Imagem Inteira):              ' num2str(f1,'%.4f') ' Hz  | Confiabilidade: ' num2str(conf1,'%.1f') '%']);
disp(['Teste 2 (Linha ' num2str(LINHA_COM_SINAL) ' - Com Sinal):    ' num2str(f2,'%.4f') ' Hz  | Confiabilidade: ' num2str(conf2,'%.1f') '%']);
disp(['Teste 3 (Linha ' num2str(LINHA_SEM_SINAL) ' - Sem Sinal):   ' num2str(f3,'%.4f') ' Hz  | Confiabilidade: ' num2str(conf3,'%.1f') '%']);
if DETECTAR_PICOS
    disp(' ');
    disp('===== RESULTADOS PICOS (dominio do tempo) =====');
    fp1 = detectar_picos(s1, fps, 'Imagem Inteira        ');
    fp2 = detectar_picos(s2, fps, ['Linha ' num2str(LINHA_COM_SINAL) ' (com sinal) ']);
    fp3 = detectar_picos(s3, fps, ['Linha ' num2str(LINHA_SEM_SINAL) ' (sem sinal)']);
else
    disp('(Deteccao de picos desativada)');
end

% -------------------------------------------------------------------------
% GRÁFICOS
% -------------------------------------------------------------------------
t  = (0:Nt-1) / fps;
vf = (0:Nt-1) * (fps/Nt);
Nh = floor(Nt/2);
xl = [0, FREQ_ALTA * 1.5];  % eixo X da FFT com margem

figure('Name',['Filtro PB ' num2str(FREQ_BAIXA) '-' num2str(FREQ_ALTA) ...
       'Hz Ordem ' num2str(ORDEM_FILTRO) ' | ' nome_arquivo], ...
       'Position', [50, 50, 1100, 780]);

% Linha 1
subplot(3,2,1); plot(t, s1,'b','LineWidth',1.5);
title('Teste 1: Sinal Filtrado (Imagem Inteira)');
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3,2,2); bar(vf(1:Nh), esp1,'b');
title(['FFT Teste 1 | Pico: ' num2str(f1,'%.3f') ' Hz (Conf: ' num2str(conf1,'%.1f') '%)']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on; xlim(xl);

% Linha 2
subplot(3,2,3); plot(t, s2,'g','LineWidth',1.5);
title(['Teste 2: Linha ' num2str(LINHA_COM_SINAL) ' (Com Sinal)']);
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3,2,4); bar(vf(1:Nh), esp2,'g');
title(['FFT Teste 2 | Pico: ' num2str(f2,'%.3f') ' Hz (Conf: ' num2str(conf2,'%.1f') '%)']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on; xlim(xl);

% Linha 3
subplot(3,2,5); plot(t, s3,'r','LineWidth',1.5);
title(['Teste 3: Linha ' num2str(LINHA_SEM_SINAL) ' (Sem Sinal)']);
xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

subplot(3,2,6); bar(vf(1:Nh), esp3,'r');
title(['FFT Teste 3 | Pico: ' num2str(f3,'%.3f') ' Hz (Conf: ' num2str(conf3,'%.1f') '%)']);
xlabel('Frequência (Hz)'); ylabel('Magnitude'); grid on; xlim(xl);

disp('Concluido! Pressione enter no terminal para fechar.');
pause;
