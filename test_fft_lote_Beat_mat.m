% =========================================================================
% SCRIPT DE LOTE: BEAT TRACKING (AUTOCORRELAÇÃO) + SINAIS KLT
% =========================================================================
% Versão baseada no test_fft_lote_pasta_com_mat.m, mas usando a lógica
% de detecção de frequência por autocorrelação do Teste_beat.m.
% =========================================================================
clear all; close all; clc;

% Pacotes necessários
pkg load image;
try; pkg load video; catch; disp('AVISO: pkg video nao encontrado'); end
try; pkg load signal; catch; disp('AVISO: pkg signal nao encontrado'); end

% =========================================================================
%   <<< CONFIGURAÇÕES (EDITE AQUI) >>>
% =========================================================================

% Pasta contendo os vídeos e os arquivos .mat 
pasta_alvo = 'video_input/VideosContados/A1';

% Filtro passa-faixa (Para visualização do sinal filtrado)
FREQ_BAIXA  = 0.1;   % Hz
FREQ_ALTA   = 2.5;   % Hz
ORDEM_FILTRO = 4;    % Butterworth ordem 4

% Margem para o filtro dinâmico
MARGEM_DINAMICA = 0.20;

% FPS assumido para os sinais do .mat KLT
FPS_MAT = 30;

% Configurações de exibição
MOSTRAR_VIDEO   = true;
MOSTRAR_KLT_MAX = true;
MOSTRAR_KLT_DIR = true;

% Fontes
FONTE_TITULO = 12;
FONTE_INFO   = 9;
FONTE_EIXO   = 9;

% =========================================================================

if ~exist(pasta_alvo, 'dir')
    error(['A pasta não existe: ' pasta_alvo]);
end

% Extrai nome da pasta
pasta_limpa = regexprep(pasta_alvo, '[/\\]$', '');
[~, nome_pasta, ~] = fileparts(pasta_limpa);

% =========================================================================
% FUNÇÃO DE ANÁLISE BEAT (Autocorrelação)
% =========================================================================
function [s_filt, f_beat, r_pos, lags_pos, conf] = analisar_beat(sinal, b, a, fps)
    s = double(sinal(:)') - mean(sinal);
    
    % 1. Filtragem Bandpass (para exibição)
    try; s_filt = filtfilt(b, a, s); catch; s_filt = s; end
    
    % 2. Lógica Beat (Extração de Envelope + Autocorrelação)
    x_rect = abs(s);
    % Filtro passa-baixa de 5Hz para envelope (como no Teste_beat.m)
    [b_lp, a_lp] = butter(2, 5/(fps/2));
    envelope = filtfilt(b_lp, a_lp, x_rect);
    
    % Autocorrelação do envelope
    % Garante que o envelope seja puramente positivo
    envelope = max(0, envelope);
    [r, lags] = xcorr(envelope, 'coeff');
    meio = floor(length(lags)/2) + 1;
    r_pos = r(meio:end);
    lags_pos = lags(meio:end);
    
    % Busca de pico (Primeiro pico significativo após o lag zero)
    % Octave findpeaks pode reclamar de valores negativos (ruído numérico do filtro)
    r_pos_find = max(0, r_pos); 
    dist_min = 0.3 * fps; % Mínimo ~200 BPM
    [pks, locs] = findpeaks(r_pos_find, "MinPeakDistance", dist_min, "MinPeakHeight", 0.15);
    
    if ~isempty(locs)
        lag_batida = lags_pos(locs(1));
        periodo = lag_batida / fps;
        f_beat = 1 / periodo;
        conf = pks(1) * 100; % Altura do pico como confiança (%)
    else
        f_beat = 0;
        conf = 0;
    end
end

% =========================================================================
% PARTE 1: PROCESSAMENTO DOS VÍDEOS
% =========================================================================

% Busca arquivos de vídeo
arquivos = dir(fullfile(pasta_alvo, '*.mp4'));
arquivos = [arquivos; dir(fullfile(pasta_alvo, '*.MP4'))];
arquivos = [arquivos; dir(fullfile(pasta_alvo, '*.avi'))];
nomes = unique({arquivos.name});

if isempty(nomes)
    error(['Nenhum video encontrado na pasta: ' pasta_alvo]);
end

% Ordenar por gotas
infos = struct();
for i = 1:length(nomes)
    nome = nomes{i};
    tok = regexp(nome, '(\d+)g\.', 'tokens');
    gotas = 999; if ~isempty(tok); gotas = str2double(tok{1}{1}); end
    infos(i).nome = nome;
    infos(i).gotas = gotas;
end
[~, idx_sort] = sort([infos.gotas]);
nomes = {infos(idx_sort).nome};
gotas_array = [infos(idx_sort).gotas];
QTD_VIDEOS = length(nomes);

% Estruturas para resultados
resultados_sinais = struct();
freq_esperada_arr = zeros(1, QTD_VIDEOS);
freq_baixa_arr    = zeros(1, QTD_VIDEOS);
freq_alta_arr     = zeros(1, QTD_VIDEOS);

% --- Verifica Cache ---
nome_cache = sprintf('SinaisBeat_%s.mat', nome_pasta);
caminho_cache_pasta = fullfile(pasta_alvo, nome_cache);
caminho_cache_local = nome_cache;

usar_cache = false;
caminho_final_cache = '';

if exist(caminho_cache_local, 'file')
    caminho_final_cache = caminho_cache_local;
    usar_cache = true;
elseif exist(caminho_cache_pasta, 'file')
    caminho_final_cache = caminho_cache_pasta;
    usar_cache = true;
end

if usar_cache
    disp(['>>> Cache encontrado: ' caminho_final_cache '. Pulando leitura de videos...']);
    load(caminho_final_cache);
end

if ~usar_cache
    for i = 1:QTD_VIDEOS
        nome_arq = nomes{i};
        caminho = fullfile(pasta_alvo, nome_arq);
        disp(['Processando Video ' num2str(i) '/' num2str(QTD_VIDEOS) ': ' nome_arq]);

        v = VideoReader(caminho);
        fps = v.FrameRate;
        disp(['  > FPS: ' num2str(fps)]);
        
        estimativa_frames = ceil(v.Duration * fps);
        sinal_inteiro = zeros(1, estimativa_frames);
        idx_frame = 0;
        
        tic;
        while hasFrame(v) && idx_frame < estimativa_frames
            idx_frame = idx_frame + 1;
            frame = readFrame(v);
            sinal_inteiro(idx_frame) = mean(frame(:));
            if mod(idx_frame, 100) == 0
                fprintf('.');
                fflush(stdout);
            end
        end
        fprintf('\n');
        fflush(stdout);
        t_leitura = toc;
        
        sinal_inteiro = sinal_inteiro(1:idx_frame);
        
        resultados_sinais(i).nome_arquivo = nome_arq;
        resultados_sinais(i).fps = fps;
        resultados_sinais(i).sinal_bruto = sinal_inteiro;
    end
    disp(['Salvando cache em ' nome_cache '...']);
    save('-v7', nome_cache, 'resultados_sinais');
end

% --- Processamento (com ou sem cache) ---
for i = 1:QTD_VIDEOS
    nome_arq = resultados_sinais(i).nome_arquivo;
    sinal_inteiro = resultados_sinais(i).sinal_bruto;
    fps = resultados_sinais(i).fps;
    Nt = length(sinal_inteiro);
    duracao = Nt / fps;

    % Frequência esperada
    qtd_gotas = gotas_array(i);
    if qtd_gotas ~= 999
        freq_esperada = qtd_gotas / duracao;
        freq_baixa_uso = freq_esperada * (1 - MARGEM_DINAMICA);
        freq_alta_uso  = freq_esperada * (1 + MARGEM_DINAMICA);
    else
        freq_esperada = NaN;
        freq_baixa_uso = FREQ_BAIXA;
        freq_alta_uso  = FREQ_ALTA;
    end
    freq_esperada_arr(i) = freq_esperada;
    freq_baixa_arr(i)    = freq_baixa_uso;
    freq_alta_arr(i)     = freq_alta_arr(i); % Fix: should be freq_alta_uso
    freq_alta_arr(i)     = freq_alta_uso;

    % Filtro Butterworth (para visualização)
    f_nyq = fps / 2;
    freq_norm = [max(0.01, freq_baixa_uso) min(0.99*f_nyq, freq_alta_uso)] / f_nyq;
    [b, a] = butter(ORDEM_FILTRO, freq_norm, 'bandpass');
    
    [s_filt, f_beat, r_pos, lags_pos, conf] = analisar_beat(sinal_inteiro, b, a, fps);
    
    % Atualiza resultados_sinais com os dados de análise
    resultados_sinais(i).s_filt = s_filt;
    resultados_sinais(i).f_beat = f_beat;
    resultados_sinais(i).r_pos = r_pos;
    resultados_sinais(i).lags_pos = lags_pos;
    resultados_sinais(i).conf = conf;
end

% =========================================================================
% PARTE 2: PROCESSAMENTO KLT (.MAT)
% =========================================================================
disp('Processando arquivos KLT .mat...');
arquivos_mat_dir = dir(fullfile(pasta_alvo, '*.mat'));
nomes_mat = {arquivos_mat_dir.name};

klt_resultados = struct();

for i = 1:QTD_VIDEOS
    [~, base_video, ~] = fileparts(nomes{i});
    nome_mat = '';
    for k = 1:length(nomes_mat)
        if ~isempty(strfind(nomes_mat{k}, base_video)) && isempty(strfind(nomes_mat{k}, 'SinaisComFiltro'))
            nome_mat = nomes_mat{k}; break;
        end
    end
    
    if ~isempty(nome_mat)
        dados = load(fullfile(pasta_alvo, nome_mat));
        
        freq_baixa_uso = freq_baixa_arr(i);
        freq_alta_uso  = freq_alta_arr(i);
        f_nyq_klt = FPS_MAT / 2;
        freq_norm = [max(0.01, freq_baixa_uso) min(0.99*f_nyq_klt, freq_alta_uso)] / f_nyq_klt;
        [b_k, a_k] = butter(ORDEM_FILTRO, freq_norm, 'bandpass');

        % Processa KLT Max
        if isfield(dados, 'klt_max')
            [s_filt, f_beat, r, lags, conf] = analisar_beat(dados.klt_max, b_k, a_k, FPS_MAT);
            klt_resultados(i).max.f_beat = f_beat;
            klt_resultados(i).max.r_pos = r;
            klt_resultados(i).max.lags_pos = lags;
            klt_resultados(i).max.conf = conf;
            klt_resultados(i).max.s_filt = s_filt;
            klt_resultados(i).max.s_bruto = double(dados.klt_max(:)');
        end
        
        % Processa KLT Directed
        if isfield(dados, 'klt_directed')
            [s_filt, f_beat, r, lags, conf] = analisar_beat(dados.klt_directed, b_k, a_k, FPS_MAT);
            klt_resultados(i).dir.f_beat = f_beat;
            klt_resultados(i).dir.r_pos = r;
            klt_resultados(i).dir.lags_pos = lags;
            klt_resultados(i).dir.conf = conf;
            klt_resultados(i).dir.s_filt = s_filt;
            klt_resultados(i).dir.s_bruto = double(dados.klt_directed(:)');
        end
    end
end

% =========================================================================
% PARTE 3: FIGURA CONSOLIDADA (AUTOCORRELAÇÃO)
% =========================================================================
fig_cons = figure('Name', ['COMPARACAO BEAT - ' pasta_alvo], 'Position', [10, 10, 1900, max(1000, QTD_VIDEOS * 450)]);

% Margens
margem_esq = 0.05; gap_h = 0.03; gap_v = 0.05;
margem_top = 0.04; margem_bot = 0.05;
n_cols = 3; n_rows = QTD_VIDEOS;
larg_plot = (1 - margem_esq - 0.02 - gap_h*(n_cols-1)) / n_cols;
alt_plot  = (1 - margem_top - margem_bot - gap_v*(n_rows-1)) / n_rows;

for i = 1:QTD_VIDEOS
    pos_y = 1 - margem_top - i*alt_plot - (i-1)*gap_v;
    freq_esp = freq_esperada_arr(i);

    % --- Auxiliar para normalizar sinal Z-Score ---
    normz = @(s) (s - mean(s)) / (std(s) + 1e-9);

    % 1. BRUTO
    subplot(n_rows, n_cols, (i-1)*3 + 1);
    set(gca, 'Position', [margem_esq, pos_y, larg_plot, alt_plot]);
    hold on;
    if MOSTRAR_VIDEO
        t_v = (0:length(resultados_sinais(i).sinal_bruto)-1)/resultados_sinais(i).fps;
        plot(t_v, normz(resultados_sinais(i).sinal_bruto), 'b');
    end
    if MOSTRAR_KLT_MAX && isfield(klt_resultados(i), 'max')
        t_k = (0:length(klt_resultados(i).max.s_bruto)-1)/FPS_MAT;
        plot(t_k, normz(klt_resultados(i).max.s_bruto), 'r');
    end
    if MOSTRAR_KLT_DIR && isfield(klt_resultados(i), 'dir')
        t_k = (0:length(klt_resultados(i).dir.s_bruto)-1)/FPS_MAT;
        plot(t_k, normz(klt_resultados(i).dir.s_bruto), 'g');
    end
    title(['Bruto - ' nomes{i}], 'Interpreter', 'none'); grid on;

    % 2. FILTRADO
    subplot(n_rows, n_cols, (i-1)*3 + 2);
    set(gca, 'Position', [margem_esq + larg_plot + gap_h, pos_y, larg_plot, alt_plot]);
    hold on;
    if MOSTRAR_VIDEO
        plot(t_v, normz(resultados_sinais(i).s_filt), 'b');
    end
    if MOSTRAR_KLT_MAX && isfield(klt_resultados(i), 'max')
        plot(t_k, normz(klt_resultados(i).max.s_filt), 'r');
    end
    if MOSTRAR_KLT_DIR && isfield(klt_resultados(i), 'dir')
        plot(t_k, normz(klt_resultados(i).dir.s_filt), 'g');
    end
    title(sprintf('Filtrado [%.2f-%.2f Hz]', freq_baixa_arr(i), freq_alta_arr(i))); grid on;

    % 3. AUTOCORRELAÇÃO (Onde mora o Beat)
    subplot(n_rows, n_cols, (i-1)*3 + 3);
    set(gca, 'Position', [margem_esq + 2*(larg_plot + gap_h), pos_y, larg_plot, alt_plot]);
    hold on;
    info_txt = '';
    
    if MOSTRAR_VIDEO
        plot(resultados_sinais(i).lags_pos/resultados_sinais(i).fps, resultados_sinais(i).r_pos, 'b');
        err = abs(resultados_sinais(i).f_beat - freq_esp)/freq_esp*100;
        info_txt = [info_txt sprintf('Vid: %.3fHz (E: %.1f%%) ', resultados_sinais(i).f_beat, err)];
    end
    if MOSTRAR_KLT_MAX && isfield(klt_resultados(i), 'max')
        plot(klt_resultados(i).max.lags_pos/FPS_MAT, klt_resultados(i).max.r_pos, 'r');
        err = abs(klt_resultados(i).max.f_beat - freq_esp)/freq_esp*100;
        info_txt = [info_txt sprintf('| Max: %.3fHz (E: %.1f%%) ', klt_resultados(i).max.f_beat, err)];
    end
    if MOSTRAR_KLT_DIR && isfield(klt_resultados(i), 'dir')
        plot(klt_resultados(i).dir.lags_pos/FPS_MAT, klt_resultados(i).dir.r_pos, 'g');
        err = abs(klt_resultados(i).dir.f_beat - freq_esp)/freq_esp*100;
        info_txt = [info_txt sprintf('| Dir: %.3fHz (E: %.1f%%)', klt_resultados(i).dir.f_beat, err)];
    end
    title({['Autocorrelação - Esp: ' num2str(freq_esp, '%.3f') ' Hz'], info_txt}, 'FontSize', FONTE_INFO);
    xlabel('Lag (s)'); ylabel('Corr'); grid on; xlim([0, 5]); % Mostra lags até 5s
end

% Salva imagem
nome_img = sprintf('ComparacaoBeat_%s.png', nome_pasta);
print(fig_cons, nome_img, '-dpng', '-r150');
disp(['Imagem salva: ' nome_img]);

% =========================================================================
% EXPORTAÇÃO (.MAT)
% =========================================================================
pasta_saida = 'Resultados/EmLote';
if ~exist(pasta_saida, 'dir'); mkdir(pasta_saida); end

registros = struct();
for i = 1:QTD_VIDEOS
    registros(i).nome_arquivo = nomes{i};
    registros(i).freq_esperada = freq_esperada_arr(i);
    
    if MOSTRAR_VIDEO
        registros(i).video.f_beat = resultados_sinais(i).f_beat;
        registros(i).video.conf = resultados_sinais(i).conf;
    end
    if MOSTRAR_KLT_MAX && isfield(klt_resultados(i), 'max')
        registros(i).klt_max.f_beat = klt_resultados(i).max.f_beat;
        registros(i).klt_max.conf = klt_resultados(i).max.conf;
    end
    if MOSTRAR_KLT_DIR && isfield(klt_resultados(i), 'dir')
        registros(i).klt_dir.f_beat = klt_resultados(i).dir.f_beat;
        registros(i).klt_dir.conf = klt_resultados(i).dir.conf;
    end
end

meta.tipo = 'BeatTracking';
meta.pasta = pasta_alvo;
meta.gerado_em = datestr(now, 'yyyy-mm-dd HH:MM:SS');

nome_resultado = sprintf('%s/ResultadoBeat_%s.mat', pasta_saida, nome_pasta);
save(nome_resultado, 'registros', 'meta');
disp(['Fim! Resultados salvos em ' nome_resultado]);
pause;
