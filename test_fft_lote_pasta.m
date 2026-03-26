% =========================================================================
% SCRIPT DE LOTE: FILTRO PASSA-FAIXA EM MÚLTIPLOS VÍDEOS (Imagem Inteira)
% =========================================================================
% Lê todos os arquivos de uma pasta, tira a média da imagem inteira,
% aplica o filtro e gera um gráfico para cada vídeo.
% =========================================================================
clear all; close all; clc;

% Pacotes necessários
pkg load image;
try; pkg load video; catch; disp('AVISO: pkg video nao encontrado'); end
try; pkg load signal; catch; disp('AVISO: pkg signal nao encontrado'); end

% =========================================================================
%   <<< CONFIGURAÇÕES (EDITE AQUI) >>>
% =========================================================================

% Pasta contendo os vídeos
pasta_alvo = 'video_input/VideosContados/R2';

% Filtro passa-faixa (Fixo conforme desejado)
FREQ_BAIXA  = 0.1;   % Hz
FREQ_ALTA   = 2.5;   % Hz
ORDEM_FILTRO = 4;    % Butterworth ordem 5

% =========================================================================
% VARIÁVEIS DO FILTRO DINÂMICO
% =========================================================================
% Percentual de margem para criar a banda do filtro dinâmico em torno da
% frequência esperada. Ex: 0.50 significa +/- 50%.
MARGEM_DINAMICA = 0.20; 

% =========================================================================

if ~exist(pasta_alvo, 'dir')
    error(['A pasta não existe: ' pasta_alvo]);
end

% Busca arquivos mp4 (extensão em minúsculo e maiúsculo)
arquivos = dir(fullfile(pasta_alvo, '*.mp4'));
arquivos_caps = dir(fullfile(pasta_alvo, '*.MP4'));
arquivos = [arquivos; arquivos_caps];
arquivos_avi = dir(fullfile(pasta_alvo, '*.avi'));
arquivos = [arquivos; arquivos_avi];
% Remover duplicatas se houver
nomes = unique({arquivos.name});

if isempty(nomes)
    disp(['Nenhum video encontrado na pasta: ' pasta_alvo]);
    return;
end

disp(['Encontrados ' num2str(length(nomes)) ' videos na pasta ' pasta_alvo]);

% -------------------------------------------------------------------------
% EXTRAIR GOTAS DO NOME E ORDENAR (do menor para o maior)
% -------------------------------------------------------------------------
infos = struct();
for i = 1:length(nomes)
    nome = nomes{i};
    % Tenta achar padrao "_Xg" ou "Xg" no nome (ex: M1_10g.MP4 -> 10)
    tok = regexp(nome, '(\d+)g\.', 'tokens');
    if ~isempty(tok)
        gotas = str2double(tok{1}{1});
    else
        % Se não achar, usa 999 para ficar no final da lista
        gotas = 999; 
    end
    infos(i).nome = nome;
    infos(i).gotas = gotas;
end

% Ordena a lista de structs pela quantidade de gotas (crescente)
[~, idx_sort] = sort([infos.gotas]);
nomes = {infos(idx_sort).nome};
gotas_array = [infos(idx_sort).gotas];

% -------------------------------------------------------------------------
% FUNÇÃO DE ANÁLISE (Otimizada sem remover limites para baixar memoria)
% -------------------------------------------------------------------------
function [s_filt, f_fft, espectro, confiabilidade] = analisar(sinal, b, a, fps)
    %s_filt = double(sinal(:)') - mean(sinal);
    s = double(sinal(:)') - mean(sinal);
    try; s_filt = filtfilt(b, a, s); catch; s_filt = s; end
    N = length(s_filt);
    espectro = abs(fft(s_filt));
    espectro = espectro(1:floor(N/2));
    busca = espectro; 
    busca(1) = 0; % Zera Apenas o DC (0 Hz)
    [~, loc] = max(busca);
    f_fft = (loc - 1) * (fps / N);
    
    variancia_total = var(busca);
    if variancia_total > 0
        busca_sem_pico = busca;
        idx_pico = max(2, loc-1) : min(length(busca), loc+1);
        busca_sem_pico(idx_pico) = mean(busca); % Substitui área do pico pela média
        variancia_ruido = var(busca_sem_pico);
        confiabilidade = max(0, (1 - (variancia_ruido / variancia_total)) * 100);
    else
        confiabilidade = 0;
    end
end

% -------------------------------------------------------------------------
% LOOP EM TODOS OS VÍDEOS
% -------------------------------------------------------------------------
QTD_VIDEOS = length(nomes);

% Cria uma única janela alta o suficiente para acomodar todos os gráficos
altura_janela = max(400, QTD_VIDEOS * 250);
figure('Name', ['Analise Lote: ' pasta_alvo], 'Position', [50, 50, 1100, altura_janela]);

for i = 1:QTD_VIDEOS
    nome_arq = nomes{i};
    caminho = fullfile(pasta_alvo, nome_arq);
    disp('---------------------------------------------------------');
    disp(['Processando ' num2str(i) '/' num2str(QTD_VIDEOS) ': ' nome_arq]);
    
    v = VideoReader(caminho);
    fps = v.FrameRate;
    disp(['  > FPS: ' num2str(fps)]);
    
    % Leitura ULTRA RÁPIDA: sem rgb2gray e sem imresize!
    % A média dos canais RGB já capta perfeitamente as variações de luz.
    estimativa_frames = ceil(v.Duration * fps);
    sinal_inteiro = zeros(1, estimativa_frames);
    idx_frame = 0;
    
    tic; % Cronômetro de leitura
    while hasFrame(v)
        idx_frame = idx_frame + 1;
        frame = readFrame(v);
        % Tira a média direta de todos os pixels (super rápido)
        sinal_inteiro(idx_frame) = mean(frame(:)); 
    end
    t_leitura = toc;
    
    sinal_inteiro = sinal_inteiro(1:idx_frame); % Corta o excesso
    Nt = length(sinal_inteiro);
    duracao = Nt / fps;
    disp(['  > Leitura concluida em: ' num2str(t_leitura, '%.2f') 's']);
    
    % Calculo da Frequencia Esperada
    qtd_gotas = gotas_array(i);
    if qtd_gotas ~= 999
        freq_esperada = qtd_gotas / duracao;
        disp(['  > Duracao: ' num2str(duracao, '%.1f') 's | Gotas: ' num2str(qtd_gotas) ' | Freq Esperada: ' num2str(freq_esperada, '%.4f') ' Hz']);
        
        % Filtro Dinamico (+/- MARGEM_DINAMICA em torno da frequencia alvo)
        freq_baixa_uso = freq_esperada * (1 - MARGEM_DINAMICA);
        freq_alta_uso  = freq_esperada * (1 + MARGEM_DINAMICA);
    else
        freq_esperada = NaN;
        disp(['  > Duracao: ' num2str(duracao, '%.1f') 's | Freq Esperada: Desconhecida']);
        
        freq_baixa_uso = FREQ_BAIXA;
        freq_alta_uso  = FREQ_ALTA;
    end
    
    % Filtro Butterworth
    f_nyq = fps / 2;
    freq_norm = [freq_baixa_uso freq_alta_uso] / f_nyq;
    [b, a] = butter(ORDEM_FILTRO, freq_norm, 'bandpass');
    if any(abs(roots(a)) >= 1)
        disp(['  > AVISO: Filtro instavel na ordem ' num2str(ORDEM_FILTRO) ' (mantendo a ordem conforme solicitado)']);
    end
    disp(['  > Filtro Aplicado: ' num2str(freq_baixa_uso, '%.3f') ' a ' num2str(freq_alta_uso, '%.3f') ' Hz']);
    
    % Processamento (Aplicacao da FFT e Filtro e Confiabilidade)
    tic; % Cronometro do calculo bruto
    [s_filt, f_pico, esp, conf] = analisar(sinal_inteiro, b, a, fps);
    t_proc = toc;
    
    t_total = t_leitura + t_proc;
    disp(['  > Tempo de Processamento Total: ' num2str(t_total, '%.2f') 's']);
    
    if ~isnan(freq_esperada)
        erro_perc = abs(f_pico - freq_esperada) / freq_esperada * 100;
        disp(['  > Pico FFT: ' num2str(f_pico, '%.4f') ' Hz | Freq Esp: ' num2str(freq_esperada, '%.4f') ' Hz | Erro: ' num2str(erro_perc, '%.1f') '% | Confiabilidade: ' num2str(conf, '%.1f') '%']);
    else
        disp(['  > Pico FFT: ' num2str(f_pico, '%.4f') ' Hz | Confiabilidade: ' num2str(conf, '%.1f') '%']);
    end
    
    % Graficos unificados (1 linha por vídeo)
    t_vetor = (0:Nt-1) / fps;
    vf = (0:Nt-1) * (fps/Nt);
    Nh = floor(Nt/2);
    xl = [0, freq_alta_uso * 1.5]; % Da zoom ate um pouco acima da alta freq do filtro
    
    subplot(QTD_VIDEOS, 2, i*2 - 1);
    plot(t_vetor, s_filt, 'b', 'LineWidth', 1.5);
    title(['Sinal Filtrado - ' nome_arq]);
    xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;
    
    subplot(QTD_VIDEOS, 2, i*2);
    %plot(vf(1:Nh)), esp, 'b');
    plot(vf(1:Nh), esp, 'b');
    
    if ~isnan(freq_esperada)
        erro_perc = abs(f_pico - freq_esperada) / freq_esperada * 100;
        texto_title = {['FFT ' nome_arq ' | Pico: ' num2str(f_pico,'%.3f') ' Hz | Esp: ' num2str(freq_esperada,'%.3f') ' Hz (Erro: ' num2str(erro_perc,'%.1f') '%)'], ...
                       ['Filtro: [' num2str(freq_baixa_uso,'%.2f') ' - ' num2str(freq_alta_uso,'%.2f') ' Hz] | Conf: ' num2str(conf,'%.1f') '%']};
    else
        texto_title = {['FFT ' nome_arq ' | Pico: ' num2str(f_pico,'%.3f') ' Hz (Conf: ' num2str(conf,'%.1f') '%)'], ...
                       ['Filtro: [' num2str(freq_baixa_uso,'%.2f') ' - ' num2str(freq_alta_uso,'%.2f') ' Hz]']};
    end
    title(texto_title, 'FontSize', 10);
    
    xlabel('Frequencia (Hz)'); ylabel('Magnitude'); grid on; xlim(xl);
end

disp('---------------------------------------------------------');
disp('Processamento em lote concluido! ');
disp('Verifique a janela gerada.');
disp('Pressione enter no terminal para fechar tudo e sair.');
pause;
