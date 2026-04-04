% =========================================================================
% SCRIPT DE LOTE: FILTRO PASSA-FAIXA + SINAIS KLT (.MAT EXTERNOS)
% =========================================================================
% Versão estendida do test_fft_lote_pasta.m:
%   1. Se já existir SinaisComFiltro_<pasta>.mat, CARREGA os resultados
%      pré-calculados em vez de re-ler os vídeos.
%   2. Busca arquivos .mat KLT na pasta e associa ao vídeo pelo nome.
%   3. Plota klt_max e klt_directed: Sinal Bruto | Filtrado | FFT
%      com as mesmas informações de frequência esperada.
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
pasta_alvo = 'video_input/VideosContados/L1';

% Filtro passa-faixa (Fixo, usado quando não se conhece a freq esperada)
FREQ_BAIXA  = 0.1;   % Hz
FREQ_ALTA   = 2.5;   % Hz
ORDEM_FILTRO = 4;    % Butterworth ordem 4

% Percentual de margem para o filtro dinâmico (+/- em torno da freq esperada)
MARGEM_DINAMICA = 0.20;

% FPS assumido para os sinais do .mat KLT
FPS_MAT = 30;

% =========================================================================

if ~exist(pasta_alvo, 'dir')
    error(['A pasta não existe: ' pasta_alvo]);
end

% Limpa barras finais e extrai nome da pasta
pasta_limpa = regexprep(pasta_alvo, '[/\\]$', '');
[~, nome_pasta, ~] = fileparts(pasta_limpa);

% =========================================================================
% FUNÇÃO DE ANÁLISE (com filtro Butterworth)
% =========================================================================
function [s_filt, f_fft, espectro, confiabilidade] = analisar(sinal, b, a, fps)
    s = double(sinal(:)') - mean(sinal);
    try; s_filt = filtfilt(b, a, s); catch; s_filt = s; end
    N = length(s_filt);
    espectro = abs(fft(s_filt));
    espectro = espectro(1:floor(N/2));
    busca = espectro;
    busca(1) = 0;
    [~, loc] = max(busca);
    f_fft = (loc - 1) * (fps / N);

    variancia_total = var(busca);
    if variancia_total > 0
        busca_sem_pico = busca;
        idx_pico = max(2, loc-1) : min(length(busca), loc+1);
        busca_sem_pico(idx_pico) = mean(busca);
        variancia_ruido = var(busca_sem_pico);
        confiabilidade = max(0, (1 - (variancia_ruido / variancia_total)) * 100);
    else
        confiabilidade = 0;
    end
end

% =========================================================================
% PARTE 1: RESULTADOS DOS VÍDEOS (cache ou processamento)
% =========================================================================

% Verifica se já existe um .mat pré-calculado na pasta OU no diretório atual
nome_cache = sprintf('SinaisComFiltro_%s.mat', nome_pasta);
caminho_cache_pasta = fullfile(pasta_alvo, nome_cache);
caminho_cache_local = nome_cache; % no diretorio atual

usar_cache = false;
caminho_cache = '';

if exist(caminho_cache_pasta, 'file')
    caminho_cache = caminho_cache_pasta;
    usar_cache = true;
elseif exist(caminho_cache_local, 'file')
    caminho_cache = caminho_cache_local;
    usar_cache = true;
end

if usar_cache
    % -----------------------------------------------------------------
    % CAMINHO RÁPIDO: carrega resultados pré-calculados
    % -----------------------------------------------------------------
    disp(['>>> Cache encontrado: ' caminho_cache]);
    disp('>>> Pulando leitura de videos, usando resultados pre-calculados.');
    load(caminho_cache);
    if ~exist('resultados_sinais', 'var')
        error('O arquivo de cache nao contem a variavel "resultados_sinais".');
    end
    QTD_VIDEOS = length(resultados_sinais);

    % Reconstroi arrays de nomes e gotas a partir do cache
    nomes = cell(1, QTD_VIDEOS);
    gotas_array = zeros(1, QTD_VIDEOS);
    for i = 1:QTD_VIDEOS
        nomes{i} = resultados_sinais(i).nome_arquivo;
        tok = regexp(nomes{i}, '(\d+)g\.', 'tokens');
        if ~isempty(tok)
            gotas_array(i) = str2double(tok{1}{1});
        else
            gotas_array(i) = 999;
        end
    end

    % Reordena por gotas (caso o cache não esteja ordenado)
    [gotas_array, idx_sort] = sort(gotas_array);
    nomes = nomes(idx_sort);
    resultados_sinais = resultados_sinais(idx_sort);

    disp(['Carregados dados de ' num2str(QTD_VIDEOS) ' videos do cache.']);

    % Arrays para guardar as faixas calculadas (serão reutilizadas nos KLT)
    freq_esperada_arr = zeros(1, QTD_VIDEOS);
    freq_baixa_arr    = zeros(1, QTD_VIDEOS);
    freq_alta_arr     = zeros(1, QTD_VIDEOS);

    % Plota os resultados do cache (mesma visualização do processamento normal)
    altura_janela = max(400, QTD_VIDEOS * 250);
    figure('Name', ['Analise Lote (Cache): ' pasta_alvo], 'Position', [50, 50, 1100, altura_janela]);

    for i = 1:QTD_VIDEOS
        nome_arq = nomes{i};
        fps = resultados_sinais(i).fps;
        sinal_inteiro = resultados_sinais(i).sinal_bruto_absoluto;
        Nt = length(sinal_inteiro);
        duracao = Nt / fps;

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
        freq_alta_arr(i)     = freq_alta_uso;

        % Recalcula filtro e FFT a partir do sinal bruto cacheado
        f_nyq = fps / 2;
        freq_norm = [freq_baixa_uso freq_alta_uso] / f_nyq;
        [b, a] = butter(ORDEM_FILTRO, freq_norm, 'bandpass');
        [s_filt, f_pico, esp, conf] = analisar(sinal_inteiro, b, a, fps);

        t_vetor = (0:Nt-1) / fps;
        vf = (0:Nt-1) * (fps/Nt);
        Nh = floor(Nt/2);
        xl = [0, freq_alta_uso * 1.5];

        subplot(QTD_VIDEOS, 2, i*2 - 1);
        plot(t_vetor, s_filt, 'b', 'LineWidth', 1.5);
        title(['Sinal Filtrado - ' nome_arq]);
        xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

        subplot(QTD_VIDEOS, 2, i*2);
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

        disp(['  [Cache] ' nome_arq ' | Pico: ' num2str(f_pico,'%.4f') ' Hz | Conf: ' num2str(conf,'%.1f') '%']);
    end

else
    % -----------------------------------------------------------------
    % CAMINHO COMPLETO: lê e processa os vídeos
    % -----------------------------------------------------------------
    disp('>>> Nenhum cache encontrado. Processando videos...');

    % Busca arquivos de vídeo
    arquivos = dir(fullfile(pasta_alvo, '*.mp4'));
    arquivos_caps = dir(fullfile(pasta_alvo, '*.MP4'));
    arquivos = [arquivos; arquivos_caps];
    arquivos_avi = dir(fullfile(pasta_alvo, '*.avi'));
    arquivos = [arquivos; arquivos_avi];
    nomes = unique({arquivos.name});

    if isempty(nomes)
        disp(['Nenhum video encontrado na pasta: ' pasta_alvo]);
        return;
    end

    disp(['Encontrados ' num2str(length(nomes)) ' videos na pasta ' pasta_alvo]);

    % Extrair gotas e ordenar
    infos = struct();
    for i = 1:length(nomes)
        nome = nomes{i};
        tok = regexp(nome, '(\d+)g\.', 'tokens');
        if ~isempty(tok)
            gotas = str2double(tok{1}{1});
        else
            gotas = 999;
        end
        infos(i).nome = nome;
        infos(i).gotas = gotas;
    end
    [~, idx_sort] = sort([infos.gotas]);
    nomes = {infos(idx_sort).nome};
    gotas_array = [infos(idx_sort).gotas];

    QTD_VIDEOS = length(nomes);
    resultados_sinais = struct();
    freq_esperada_arr = zeros(1, QTD_VIDEOS);
    freq_baixa_arr    = zeros(1, QTD_VIDEOS);
    freq_alta_arr     = zeros(1, QTD_VIDEOS);

    % Janela principal de vídeo
    altura_janela = max(400, QTD_VIDEOS * 250);
    figure('Name', ['Analise Lote (Filtrado): ' pasta_alvo], 'Position', [50, 50, 1100, altura_janela]);

    for i = 1:QTD_VIDEOS
        nome_arq = nomes{i};
        caminho = fullfile(pasta_alvo, nome_arq);
        disp('---------------------------------------------------------');
        disp(['Processando ' num2str(i) '/' num2str(QTD_VIDEOS) ': ' nome_arq]);

        v = VideoReader(caminho);
        fps = v.FrameRate;
        disp(['  > FPS: ' num2str(fps)]);

        estimativa_frames = ceil(v.Duration * fps);
        sinal_inteiro = zeros(1, estimativa_frames);
        idx_frame = 0;

        tic;
        while hasFrame(v)
            idx_frame = idx_frame + 1;
            frame = readFrame(v);
            sinal_inteiro(idx_frame) = mean(frame(:));
        end
        t_leitura = toc;

        sinal_inteiro = sinal_inteiro(1:idx_frame);
        Nt = length(sinal_inteiro);
        duracao = Nt / fps;
        disp(['  > Leitura concluida em: ' num2str(t_leitura, '%.2f') 's']);

        qtd_gotas = gotas_array(i);
        if qtd_gotas ~= 999
            freq_esperada = qtd_gotas / duracao;
            disp(['  > Duracao: ' num2str(duracao, '%.1f') 's | Gotas: ' num2str(qtd_gotas) ' | Freq Esperada: ' num2str(freq_esperada, '%.4f') ' Hz']);
            freq_baixa_uso = freq_esperada * (1 - MARGEM_DINAMICA);
            freq_alta_uso  = freq_esperada * (1 + MARGEM_DINAMICA);
        else
            freq_esperada = NaN;
            disp(['  > Duracao: ' num2str(duracao, '%.1f') 's | Freq Esperada: Desconhecida']);
            freq_baixa_uso = FREQ_BAIXA;
            freq_alta_uso  = FREQ_ALTA;
        end
        freq_esperada_arr(i) = freq_esperada;
        freq_baixa_arr(i)    = freq_baixa_uso;
        freq_alta_arr(i)     = freq_alta_uso;

        f_nyq = fps / 2;
        freq_norm = [freq_baixa_uso freq_alta_uso] / f_nyq;
        [b, a] = butter(ORDEM_FILTRO, freq_norm, 'bandpass');
        if any(abs(roots(a)) >= 1)
            disp(['  > AVISO: Filtro instavel na ordem ' num2str(ORDEM_FILTRO)]);
        end
        disp(['  > Filtro Aplicado: ' num2str(freq_baixa_uso, '%.3f') ' a ' num2str(freq_alta_uso, '%.3f') ' Hz']);

        tic;
        [s_filt, f_pico, esp, conf] = analisar(sinal_inteiro, b, a, fps);
        t_proc = toc;

        t_total = t_leitura + t_proc;
        disp(['  > Tempo de Processamento Total: ' num2str(t_total, '%.2f') 's']);

        if ~isnan(freq_esperada)
            erro_perc = abs(f_pico - freq_esperada) / freq_esperada * 100;
            disp(['  > Pico FFT: ' num2str(f_pico, '%.4f') ' Hz | Freq Esp: ' num2str(freq_esperada, '%.4f') ' Hz | Erro: ' num2str(erro_perc, '%.1f') '% | Conf: ' num2str(conf, '%.1f') '%']);
        else
            disp(['  > Pico FFT: ' num2str(f_pico, '%.4f') ' Hz | Conf: ' num2str(conf, '%.1f') '%']);
        end

        % Graficos do vídeo
        t_vetor = (0:Nt-1) / fps;
        vf = (0:Nt-1) * (fps/Nt);
        Nh = floor(Nt/2);
        xl = [0, freq_alta_uso * 1.5];

        subplot(QTD_VIDEOS, 2, i*2 - 1);
        plot(t_vetor, s_filt, 'b', 'LineWidth', 1.5);
        title(['Sinal Filtrado - ' nome_arq]);
        xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

        subplot(QTD_VIDEOS, 2, i*2);
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

        % Armazena
        resultados_sinais(i).nome_arquivo = nome_arq;
        resultados_sinais(i).fps = fps;
        resultados_sinais(i).sinal_bruto_absoluto = sinal_inteiro;
        resultados_sinais(i).sinal_filtrado = s_filt;
    end

    % Salva cache
    disp(['Salvando cache em: ' nome_cache ' ...']);
    save('-v7', nome_cache, 'resultados_sinais');
    disp('Cache salvo com sucesso!');
end

% =========================================================================
% PARTE 2: SINAIS KLT DOS ARQUIVOS .MAT (klt_max e klt_directed)
% =========================================================================
disp('');
disp('=========================================================');
disp('CARREGANDO SINAIS KLT DOS ARQUIVOS .MAT ...');
disp('=========================================================');

% Busca arquivos .mat KLT na pasta (ignora os SinaisComFiltro/SinaisSemFiltro)
arquivos_mat_dir = dir(fullfile(pasta_alvo, '*.mat'));
nomes_mat = {};
for m = 1:length(arquivos_mat_dir)
    nm = arquivos_mat_dir(m).name;
    % Ignora os caches gerados por este script
    if isempty(strfind(nm, 'SinaisComFiltro')) && isempty(strfind(nm, 'SinaisSemFiltro'))
        nomes_mat{end+1} = nm;
    end
end
disp(['Encontrados ' num2str(length(nomes_mat)) ' arquivos .mat KLT na pasta']);

% Nomes dos sinais KLT que queremos
sinais_klt = {'klt_max', 'klt_directed'};
labels_klt = {'KLT Max', 'KLT Directed'};
cores_klt  = {'r', [0 0.6 0]};

% Cria uma figura para cada sinal KLT (klt_max e klt_directed)
for sig_idx = 1:length(sinais_klt)
    nome_sinal = sinais_klt{sig_idx};
    label_sinal = labels_klt{sig_idx};
    cor_sinal = cores_klt{sig_idx};

    altura_fig = max(400, QTD_VIDEOS * 220);
    fig_klt = figure('Name', [label_sinal ' - ' pasta_alvo], ...
                     'Position', [50 + sig_idx*60, 30, 1400, altura_fig]);

    videos_plotados = 0;

    for i = 1:QTD_VIDEOS
        nome_arq = nomes{i};
        [~, base_video, ~] = fileparts(nome_arq);

        % Busca o .mat correspondente
        nome_mat_encontrado = '';
        for k = 1:length(nomes_mat)
            if ~isempty(strfind(nomes_mat{k}, base_video))
                nome_mat_encontrado = nomes_mat{k};
                break;
            end
        end

        if isempty(nome_mat_encontrado)
            disp(['  [' label_sinal '] [' nome_arq '] Nenhum .mat KLT encontrado para "' base_video '"']);
            continue;
        end

        caminho_mat = fullfile(pasta_alvo, nome_mat_encontrado);

        % Carrega o .mat (com fallback de formatos)
        dados_mat = [];
        load_ok = false;
        try; dados_mat = load(caminho_mat); load_ok = true;
        catch; end
        if ~load_ok
            try; dados_mat = load('-v7', caminho_mat); load_ok = true;
            catch; end
        end
        if ~load_ok
            try; dados_mat = load('-hdf5', caminho_mat); load_ok = true;
            catch; end
        end
        if ~load_ok
            disp(['  [' label_sinal '] ERRO: Nao foi possivel carregar ' nome_mat_encontrado '. Pulando...']);
            continue;
        end

        % Verifica se a variável existe no .mat
        if ~isfield(dados_mat, nome_sinal)
            disp(['  [' label_sinal '] AVISO: Variavel "' nome_sinal '" nao encontrada em ' nome_mat_encontrado]);
            continue;
        end

        sinal_bruto = double(dados_mat.(nome_sinal)(:)');
        N_klt = length(sinal_bruto);
        duracao_klt = N_klt / FPS_MAT;
        t_klt = (0:N_klt-1) / FPS_MAT;

        videos_plotados = videos_plotados + 1;
        disp(['  [' label_sinal '] [' nome_arq '] Carregado de ' nome_mat_encontrado ' (' num2str(N_klt) ' amostras, ' num2str(duracao_klt, '%.1f') 's)']);

        % Usa as mesmas faixas calculadas a partir do vídeo
        freq_esperada  = freq_esperada_arr(i);
        freq_baixa_uso = freq_baixa_arr(i);
        freq_alta_uso  = freq_alta_arr(i);

        % Filtro Butterworth (mesmas faixas do vídeo)
        f_nyq = FPS_MAT / 2;
        freq_norm = [freq_baixa_uso freq_alta_uso] / f_nyq;
        [b, a] = butter(ORDEM_FILTRO, freq_norm, 'bandpass');

        % Aplica filtro e calcula FFT
        [s_filt_klt, f_pico_klt, esp_klt, conf_klt] = analisar(sinal_bruto, b, a, FPS_MAT);

        % Vetores de frequência para o plot da FFT
        Nh_klt = floor(N_klt / 2);
        f_vetor_klt = (0:Nh_klt-1) * (FPS_MAT / N_klt);
        xl_klt = [0, freq_alta_uso * 1.5];

        % Calcula erro se possível
        if ~isnan(freq_esperada)
            erro_perc = abs(f_pico_klt - freq_esperada) / freq_esperada * 100;
            info_freq = sprintf('Esp: %.3f Hz | Pico: %.3f Hz | Erro: %.1f%% | Conf: %.1f%%', ...
                                freq_esperada, f_pico_klt, erro_perc, conf_klt);
            info_filtro = sprintf('[%.2f - %.2f Hz]', freq_baixa_uso, freq_alta_uso);
        else
            info_freq = sprintf('Pico: %.3f Hz | Conf: %.1f%%', f_pico_klt, conf_klt);
            info_filtro = sprintf('[%.2f - %.2f Hz]', freq_baixa_uso, freq_alta_uso);
        end

        % --- Subplot 1: Sinal Bruto ---
        subplot(QTD_VIDEOS, 3, (i-1)*3 + 1);
        plot(t_klt, sinal_bruto, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);
        title({[label_sinal ' Bruto - ' nome_arq], info_freq}, 'FontSize', 9, 'Interpreter', 'none');
        xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

        % --- Subplot 2: Sinal Filtrado ---
        subplot(QTD_VIDEOS, 3, (i-1)*3 + 2);
        plot(t_klt, s_filt_klt, 'Color', cor_sinal, 'LineWidth', 1.2);
        title({[label_sinal ' Filtrado - ' nome_arq], ['Filtro: ' info_filtro]}, 'FontSize', 9, 'Interpreter', 'none');
        xlabel('Tempo (s)'); ylabel('Amplitude'); grid on;

        % --- Subplot 3: FFT ---
        subplot(QTD_VIDEOS, 3, (i-1)*3 + 3);
        plot(f_vetor_klt, esp_klt, 'Color', cor_sinal, 'LineWidth', 1.2);
        if ~isnan(freq_esperada)
            titulo_fft = {['FFT ' label_sinal ' | Pico: ' num2str(f_pico_klt,'%.3f') ' Hz | Esp: ' num2str(freq_esperada,'%.3f') ' Hz (Erro: ' num2str(erro_perc,'%.1f') '%)'], ...
                          ['Filtro: ' info_filtro ' | Conf: ' num2str(conf_klt,'%.1f') '%']};
        else
            titulo_fft = {['FFT ' label_sinal ' | Pico: ' num2str(f_pico_klt,'%.3f') ' Hz (Conf: ' num2str(conf_klt,'%.1f') '%)'], ...
                          ['Filtro: ' info_filtro]};
        end
        title(titulo_fft, 'FontSize', 9, 'Interpreter', 'none');
        xlabel('Frequencia (Hz)'); ylabel('Magnitude'); grid on;
        xlim(xl_klt);
    end

    if videos_plotados == 0
        close(fig_klt);
        disp(['  Nenhum dado KLT encontrado para ' label_sinal '. Figura fechada.']);
    end
end

% =========================================================================
% FINALIZAÇÃO
% =========================================================================
disp('---------------------------------------------------------');
disp('Processamento completo!');
disp('Verifique as janelas geradas.');
disp('Pressione Enter no terminal para fechar tudo e sair.');
pause;
