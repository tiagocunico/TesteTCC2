% =========================================================================
% ANÁLISE CRUZADA DE LOTES - analise_cruzada_lote.m
% =========================================================================
% Lê todos os arquivos Resultado_*.mat em Resultados/EmLote/ e
% gera uma tabela comparativa com Freq. Esperada, Pico e Erro%
% para cada vídeo e para cada sinal (Video, KLT Max, KLT Directed).
% =========================================================================

PASTA_RESULTADOS = 'Resultados/EmLote';

% -------------------------------------------------------------------------
% 1. Descobre os arquivos .mat disponíveis em subpastas de forma recursiva
% -------------------------------------------------------------------------
arquivos = [];

% Verifica se PASTA_RESULTADOS existe
if ~exist(PASTA_RESULTADOS, 'dir')
    error(['Pasta de resultados não encontrada: ' PASTA_RESULTADOS]);
end

% Busca recursiva em todos os níveis
% Alguns Octave (ou OS) podem não suportar ** dependendo da versão, 
% então vamos tentar o ** e se não der nada, fazemos de novo no root como fallback.
arqs_todos = dir(fullfile(PASTA_RESULTADOS, '**', 'Resultado_*.mat'));

% Se não retornou nada com **, tenta apenas na raiz e no 1o nível manualmente
if isempty(arqs_todos)
    arqs_todos = dir(fullfile(PASTA_RESULTADOS, 'Resultado_*.mat'));
    subdirs = dir(PASTA_RESULTADOS);
    for k = 1:length(subdirs)
        if subdirs(k).isdir && ~strcmp(subdirs(k).name, '.') && ~strcmp(subdirs(k).name, '..')
            sub = fullfile(PASTA_RESULTADOS, subdirs(k).name);
            arqs_sub = dir(fullfile(sub, 'Resultado_*.mat'));
            arqs_todos = [arqs_todos; arqs_sub];
        end
    end
end

% Filtra para garantir que pegamos apenas arquivos (e não diretórios acidentais)
arquivos = arqs_todos(~[arqs_todos.isdir]);

if isempty(arquivos)
    disp(['PASTA PROCURADA: ' PASTA_RESULTADOS]);
    disp(['CWD: ' pwd]);
    error(['Nenhum arquivo Resultado_*.mat encontrado em: ' PASTA_RESULTADOS ' ou subpastas']);
end

disp(['Encontrados ' num2str(length(arquivos)) ' arquivos de resultado:']);
for k = 1:length(arquivos)
    % A estrutura 'dir' retorna o campo 'folder' a partir do Octave 4.4
    % Caso não exista, construímos a partir de PASTA_RESULTADOS (limitado)
    if isfield(arquivos(k), 'folder')
        disp(['  ' fullfile(arquivos(k).folder, arquivos(k).name)]);
    else
        disp(['  ' arquivos(k).name]);
    end
end

% -------------------------------------------------------------------------
% 2. Carrega e agrupa todos os registros em uma lista plana
% -------------------------------------------------------------------------
todas_linhas = {};  % Cada linha: {lote, gotas, freq_esp, vid_pico, vid_err, vid_conf, km_pico, km_err, km_conf, kd_pico, kd_err, kd_conf}

for k = 1:length(arquivos)
    % Reconstrói o caminho completo
    if isfield(arquivos(k), 'folder')
        caminho = fullfile(arquivos(k).folder, arquivos(k).name);
    else
        % Fallback rudimentar para versões muito antigas do Octave
        caminho = fullfile(PASTA_RESULTADOS, arquivos(k).name);
    end
    
    try
        dados = load(caminho);
    catch
        disp(['AVISO: Não foi possível carregar ' caminho '. Pulando.']);
        continue;
    end

    if ~isfield(dados, 'registros') || ~isfield(dados, 'meta')
        disp(['AVISO: Estrutura inesperada em ' arquivos(k).name '. Pulando.']);
        continue;
    end

    nome_lote = dados.meta.nome_pasta;
    regs = dados.registros;

    for i = 1:length(regs)
        r = regs(i);
        linha = {nome_lote, r.nome_arquivo, r.gotas, r.freq_esperada, ...
                 r.video.pico,   r.video.erro_perc,   r.video.conf, ...
                 r.klt_max.pico, r.klt_max.erro_perc, r.klt_max.conf, ...
                 r.klt_dir.pico, r.klt_dir.erro_perc, r.klt_dir.conf};
        todas_linhas{end+1} = linha;
    end
end

if isempty(todas_linhas)
    error('Nenhum registro válido encontrado nos arquivos .mat.');
end

% Ordena por (gotas, lote)
n = length(todas_linhas);
gotas_vec = cellfun(@(l) l{3}, todas_linhas);
lote_vec  = cellfun(@(l) l{1}, todas_linhas, 'UniformOutput', false);
[~, idx] = sortrows([gotas_vec(:), (1:n)'], 1);
todas_linhas = todas_linhas(idx);

% -------------------------------------------------------------------------
% 3. Imprime a tabela no terminal
% -------------------------------------------------------------------------
sep = repmat('-', 1, 120);
fmt_h = '%-8s %-16s %6s %8s | %8s %7s %6s | %8s %7s %6s | %8s %7s %6s\n';
fmt_d = '%-8s %-16s %6.0f %8.4f | %8.4f %6.1f%% %5.1f%% | %8.4f %6.1f%% %5.1f%% | %8.4f %6.1f%% %5.1f%%\n';

disp('');
disp(sep);
fprintf(fmt_h, 'Lote', 'Video', 'Gotas', 'Esp(Hz)', ...
        'Vid Pico', 'Err%', 'Conf%', ...
        'Max Pico', 'Err%', 'Conf%', ...
        'Dir Pico', 'Err%', 'Conf%');
disp(sep);

gotas_atual = -1;
for i = 1:length(todas_linhas)
    l = todas_linhas{i};
    if l{3} ~= gotas_atual
        if gotas_atual ~= -1
            disp(sep);
        end
        gotas_atual = l{3};
    end

    % Trata NaN no erro (quando freq_esperada=NaN)
    ve = l{6};  if isnan(ve); ve = 0; end
    ke = l{9};  if isnan(ke); ke = 0; end
    de = l{12}; if isnan(de); de = 0; end

    fprintf(fmt_d, l{1}, l{2}, l{3}, l{4}, ...
            l{5}, ve, l{7}, ...
            l{8}, ke, l{10}, ...
            l{11}, de, l{13});
end
disp(sep);

% -------------------------------------------------------------------------
% 4. Resumo: Média e desvio do erro por sinal e por quantidade de gotas
% -------------------------------------------------------------------------
gotas_unicas = unique(gotas_vec);
gotas_unicas(gotas_unicas == 999) = [];  % Remove "desconhecido"

disp('');
disp('=== RESUMO POR QUANTIDADE DE GOTAS ===');
disp('  (Média ± DP do Erro%  |  C=Confiança Média, sobre todos os lotes com aquela qtd)');
disp('');
fmt_r = '  Gotas=%-4.0f | Video: %5.1f%% ± %4.1f%% (C=%4.1f%%) | KLT Max: %5.1f%% ± %4.1f%% (C=%4.1f%%) | KLT Dir: %5.1f%% ± %4.1f%% (C=%4.1f%%)\n';

for g = gotas_unicas(:)'
    mask = cellfun(@(l) l{3} == g, todas_linhas);
    grupo = todas_linhas(mask);
    
    ve_arr = cellfun(@(l) l{6},  grupo); ve_arr(isnan(ve_arr)) = [];
    vc_arr = cellfun(@(l) l{7},  grupo); vc_arr(isnan(vc_arr)) = [];
    ke_arr = cellfun(@(l) l{9},  grupo); ke_arr(isnan(ke_arr)) = [];
    kc_arr = cellfun(@(l) l{10}, grupo); kc_arr(isnan(kc_arr)) = [];
    de_arr = cellfun(@(l) l{12}, grupo); de_arr(isnan(de_arr)) = [];
    dc_arr = cellfun(@(l) l{13}, grupo); dc_arr(isnan(dc_arr)) = [];

    fprintf(fmt_r, g, ...
            mean(ve_arr), std(ve_arr), mean(vc_arr), ...
            mean(ke_arr), std(ke_arr), mean(kc_arr), ...
            mean(de_arr), std(de_arr), mean(dc_arr));
end

% -------------------------------------------------------------------------
% 5. Conclusão Final: O que funcionou melhor?
% -------------------------------------------------------------------------
% Coleta métricas por tipo para cada quantidade de gotas
v_erros_g = []; v_dps_g = []; v_confs_g = [];
k_erros_g = []; k_dps_g = []; k_confs_g = [];
d_erros_g = []; d_dps_g = []; d_confs_g = [];

for g = gotas_unicas(:)'
    mask = cellfun(@(l) l{3} == g, todas_linhas);
    grupo = todas_linhas(mask);
    
    ve = cellfun(@(l) l{6},  grupo);  ve(isnan(ve)) = [];
    vc = cellfun(@(l) l{7},  grupo);  vc(isnan(vc)) = [];
    ke = cellfun(@(l) l{9},  grupo);  ke(isnan(ke)) = [];
    kc = cellfun(@(l) l{10}, grupo);  kc(isnan(kc)) = [];
    de = cellfun(@(l) l{12}, grupo);  de(isnan(de)) = [];
    dc = cellfun(@(l) l{13}, grupo);  dc(isnan(dc)) = [];

    v_erros_g(end+1) = mean(ve); v_dps_g(end+1) = std(ve); v_confs_g(end+1) = mean(vc);
    k_erros_g(end+1) = mean(ke); k_dps_g(end+1) = std(ke); k_confs_g(end+1) = mean(kc);
    d_erros_g(end+1) = mean(de); d_dps_g(end+1) = std(de); d_confs_g(end+1) = mean(dc);
end

% 1. Melhor quantidade de gotas geral (média aritmética dos erros)
media_geral_por_g = (v_erros_g + k_erros_g + d_erros_g) ./ 3;
[melhor_err_g, idx_g] = min(media_geral_por_g);
melhor_g = gotas_unicas(idx_g);

% 2. Melhor tipo de medição na média total
v_all = cellfun(@(l) l{6}, todas_linhas);
k_all = cellfun(@(l) l{9}, todas_linhas);
d_all = cellfun(@(l) l{12}, todas_linhas);
med_medias = [mean(v_all), mean(k_all), mean(d_all)];
tipos = {'Video', 'KLT Max', 'KLT Dir'};
[melhor_err_tipo, idx_t] = min(med_medias);
melhor_tipo = tipos{idx_t};

% 4. MELHOR CONJUNTO ABSOLUTO (Apenas pelo menor erro médio)
erros_todas_comb = [v_erros_g, k_erros_g, d_erros_g];
[m_err_abs, idx_abs] = min(erros_todas_comb);
idx_g_abs = mod(idx_abs - 1, length(gotas_unicas)) + 1;
idx_t_abs = floor((idx_abs - 1) / length(gotas_unicas)) + 1;
melhor_g_abs = gotas_unicas(idx_g_abs);
melhor_tipo_abs = tipos{idx_t_abs};

% 5. MELHOR CONJUNTO EQUILIBRADO (Peso: 50% Erro, 30% DP, 20% Incerteza da Confiança)
W_ERR = 0.50; W_DP = 0.30; W_CONF = 0.20;
scores_v = (v_erros_g * W_ERR) + (v_dps_g * W_DP) + ((100 - v_confs_g) * W_CONF);
scores_k = (k_erros_g * W_ERR) + (k_dps_g * W_DP) + ((100 - k_confs_g) * W_CONF);
scores_d = (d_erros_g * W_ERR) + (d_dps_g * W_DP) + ((100 - d_confs_g) * W_CONF);

scores_todas = [scores_v, scores_k, scores_d];
[best_score, idx_bal] = min(scores_todas);
idx_g_bal = mod(idx_bal - 1, length(gotas_unicas)) + 1;
idx_t_bal = floor((idx_bal - 1) / length(gotas_unicas)) + 1;
melhor_g_bal = gotas_unicas(idx_g_bal);
melhor_tipo_bal = tipos{idx_t_bal};

disp('---------------------------------------------------------');
disp('=== CONCLUSÃO FINAL DA ANÁLISE CRUZADA ===');
fprintf('  > Melhor Qtd. de Gotas (Geral):   %.0f gotas (Erro Médio: %.2f%%)\n', melhor_g, melhor_err_g);
fprintf('  > Melhor Tipo de Medição:         %s (Erro Médio Total: %.2f%%)\n', melhor_tipo, melhor_err_tipo);
fprintf('  > MELHOR CONJUNTO (ABS):          %s com %.0f gotas (Erro: %.2f%%)\n', melhor_tipo_abs, melhor_g_abs, m_err_abs);
fprintf('  > MELHOR CONJUNTO EQUILIBRADO:    %s com %.0f gotas (Score: %.2f)\n', melhor_tipo_bal, melhor_g_bal, best_score);
disp('  (Critério: 50%% Erro, 30%% DP, 20%% Incerteza de Confiança)');
disp('---------------------------------------------------------');
disp('Análise cruzada concluída.');
