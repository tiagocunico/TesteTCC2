% =========================================================================
% SCRIPT DE LOTE: ANÁLISE FFT EM MÚLTIPLOS VÍDEOS (SEM FILTRO TEMPORAL)
% =========================================================================
% Lê todos os arquivos de uma pasta, tira a média da imagem inteira,
% faz a FFT pura e busca o pico de frequência apenas dentro da faixa esperada.
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
pasta_alvo = 'video_input/VideosContados/L1';

% Faixa de busca (Fixa, caso não tenha informação de gotas no nome)
FREQ_BAIXA  = 0.1;   % Hz
FREQ_ALTA   = 2.5;   % Hz

% =========================================================================
% VARIÁVEIS DA FAIXA DINÂMICA
% =========================================================================
% Percentual de margem para buscar o pico em torno da frequência esperada.
% Ex: 0.20 significa +/- 20%.
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
    % Tenta achar padrao "_Xg" ou "Xg" no nome (ex: L1_10g.MP4 -> 10)
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

% Ordena a lista pela quantidade de gotas (crescente)
[~, idx_sort] = sort([infos.gotas]);
nomes = {infos(idx_sort).nome};
gotas_array = [infos(idx_sort).gotas];

% -------------------------------------------------------------------------
% FUNÇÃO DE ANÁLISE (Sem Filtro Temporal, Cortando Direto na FFT)
% -------------------------------------------------------------------------
function [s_media, f_fft, espectro, confiabilidade, f_vetor, idx_pico] = analisar_sem_filtro(sinal, fps, f_min, f_max)
    % Remove a componente contínua
    s_media = double(sinal(:)') - mean(sinal);
    N = length(s_media);
    
    % FFT do sinal bruto
    espectro = abs(fft(s_media));
    Nh = floor(N/2);
    espectro = espectro(1:Nh);
    
    % Frequências correspondentes a cada ponto da FFT
    f_vetor = (0:Nh-1) * (fps / N);
    
    % Máscara para manter apenas frequências dentro da janela desejada
    busca = espectro; 
    busca(1) = 0; % Zera DC explicitamente por segurança
    
    indices_validos = (f_vetor >= f_min) & (f_vetor <= f_max);
    busca(~indices_validos) = 0; % Zera tudo o que estiver fora da faixa
    
    % Busca o pico APENAS na região que não foi zerada (a janela desejada)
    [valor_pico, idx_pico] = max(busca);
    
    if valor_pico > 0
        f_fft = f_vetor(idx_pico);
        
        % Cálculo de confiabilidade (focado na janela de frequências válidas)
        busca_sem_pico = busca;
        % Remove o pico e seus vizinhos imediatos para ter a "média de ruído" da janela
        vizinhanca = max(1, idx_pico-1) : min(length(busca), idx_pico+1);
        busca_sem_pico(vizinhanca) = mean(busca(indices_validos)); 
        
        variancia_janela = var(busca(indices_validos));
        if variancia_janela > 0
            variancia_ruido = var(busca_sem_pico(indices_validos));
            confiabilidade = max(0, (1 - (variancia_ruido / variancia_janela)) * 100);
        else
            confiabilidade = 0;
        end
    else
        f_fft = 0;
        confiabilidade = 0;
        idx_pico = 1;
    end
end

% -------------------------------------------------------------------------
% LOOP EM TODOS OS VÍDEOS
% -------------------------------------------------------------------------
QTD_VIDEOS = length(nomes);

% Cria uma única janela alta o suficiente para acomodar todos os gráficos
altura_janela = max(400, QTD_VIDEOS * 250);
figure('Name', ['Analise Lote (Sem Filtro): ' pasta_alvo], 'Position', [50, 50, 1100, altura_janela]);

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
    
    tic; % Cronômetro de leitura
    while hasFrame(v)
        idx_frame = idx_frame + 1;
        frame = readFrame(v);
        % Tira a média direta de todos os pixels
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
        
        % Faixa Dinamica (+/- MARGEM_DINAMICA em torno da frequencia alvo)
        freq_baixa_uso = freq_esperada * (1 - MARGEM_DINAMICA);
        freq_alta_uso  = freq_esperada * (1 + MARGEM_DINAMICA);
    else
        freq_esperada = NaN;
        disp(['  > Duracao: ' num2str(duracao, '%.1f') 's | Freq Esperada: Desconhecida']);
        
        freq_baixa_uso = FREQ_BAIXA;
        freq_alta_uso  = FREQ_ALTA;
    end
    
    disp(['  > Janela Validada na FFT: ' num2str(freq_baixa_uso, '%.3f') ' a ' num2str(freq_alta_uso, '%.3f') ' Hz']);
    
    % Processamento (Aplicacao da FFT em vez de Filtro Temporal)
    tic; % Cronometro do calculo bruto
    [s_media, f_pico, esp, conf, f_vetor, idx_pico] = analisar_sem_filtro(sinal_inteiro, fps, freq_baixa_uso, freq_alta_uso);
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
    xl = [0, freq_alta_uso * 1.5]; % Da zoom ate um pouco acima da alta freq da janela
    
    subplot(QTD_VIDEOS, 2, i*2 - 1);
    plot(t_vetor, s_media, 'b', 'LineWidth', 1.5);
    title(['Sinal Bruto (Sem Filtro Espacial/Temporal) - ' nome_arq]);
    xlabel('Tempo (s)'); ylabel('Amplitude da media'); grid on;
    
    subplot(QTD_VIDEOS, 2, i*2);
    % Plota o espectro original completo em cinza
    plot(f_vetor, esp, 'color', [0.7 0.7 0.7]); 
    hold on;
    
    % Realca apenas a porta de passagem (a janela escolhida)
    idx_janela = (f_vetor >= freq_baixa_uso) & (f_vetor <= freq_alta_uso);
    plot(f_vetor(idx_janela), esp(idx_janela), 'b', 'LineWidth', 1.5);
    
    % Marca o pico encontrado com uma bolinha vermelha
    if f_pico > 0
        plot(f_pico, esp(idx_pico), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    end
    hold off;
    
    if ~isnan(freq_esperada)
        erro_perc = abs(f_pico - freq_esperada) / freq_esperada * 100;
        texto_title = {['FFT ' nome_arq ' | Pico: ' num2str(f_pico,'%.3f') ' Hz | Esp: ' num2str(freq_esperada,'%.3f') ' Hz (Erro: ' num2str(erro_perc,'%.1f') '%)'], ...
                       ['Janela Ativa: [' num2str(freq_baixa_uso,'%.2f') ' - ' num2str(freq_alta_uso,'%.2f') ' Hz] | Conf: ' num2str(conf,'%.1f') '%']};
    else
        texto_title = {['FFT ' nome_arq ' | Pico: ' num2str(f_pico,'%.3f') ' Hz (Conf: ' num2str(conf,'%.1f') '%)'], ...
                       ['Janela Ativa: [' num2str(freq_baixa_uso,'%.2f') ' - ' num2str(freq_alta_uso,'%.2f') ' Hz]']};
    end
    title(texto_title, 'FontSize', 10);
    
    xlabel('Frequencia (Hz)'); ylabel('Magnitude'); grid on; xlim(xl);
end

disp('---------------------------------------------------------');
disp('Processamento em lote concluido! ');
disp('Verifique a janela gerada.');
disp('Pressione enter no terminal para fechar tudo e sair.');
pause;
