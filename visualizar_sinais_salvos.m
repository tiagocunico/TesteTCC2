% =========================================================================
% SCRIPT PARA VISUALIZAR OS SINAIS SALVOS (do arquivo .mat)
% =========================================================================
% Esse script apenas carrega o arquivo .mat gerado pelo lote
% e cria um painel mostrando rapidamente todos os sinais salvos.
% =========================================================================
clear all; close all; clc;

% =========================================================================
% CONFIGURAÇÕES
% =========================================================================
% O nome do arquivo que geramos no passo anterior (ex: _L1.mat ou _R2.mat)
arquivo_mat = 'SinaisComFiltro_L1.mat'; 

% =========================================================================

if ~exist(arquivo_mat, 'file')
    error(['Arquivo não encontrado: ' arquivo_mat '. Verifique o nome ou rode o outro script primeiro.']);
end

disp(['Carregando dados de: ' arquivo_mat ' ...']);
load(arquivo_mat);

% Verifica se o arquivo tem a variável correta
if ~exist('resultados_sinais', 'var')
    error('Problema: O arquivo .mat não tem a estrutura "resultados_sinais".');
end

qtd_videos = length(resultados_sinais);
disp(['Sucesso! Foram encontrados os dados brutos de ' num2str(qtd_videos) ' vídeos.']);

% Configuração da Janela (Dinâmica, dependendo de quantos vídeos existem)
altura_janela = max(400, qtd_videos * 200);
figure('Name', ['Visualizacao dos Sinais: ' arquivo_mat], 'Position', [100, 100, 1000, altura_janela]);

for i = 1:qtd_videos
    % Extrai os dados em variáveis normais
    nome_vid = resultados_sinais(i).nome_arquivo;
    sinal_bruto = resultados_sinais(i).sinal_bruto_absoluto;
    fps = resultados_sinais(i).fps;
    
    if isfield(resultados_sinais, 'sinal_media_removida')
        sinal_secundario = resultados_sinais(i).sinal_media_removida;
        titulo_secundario = 'Sinal AC (Média Removida)';
    elseif isfield(resultados_sinais, 'sinal_filtrado')
        sinal_secundario = resultados_sinais(i).sinal_filtrado;
        titulo_secundario = 'Sinal Filtrado (Passa-Faixa)';
    else
        sinal_secundario = sinal_bruto;
        titulo_secundario = 'Sinal Secundário Desconhecido';
    end
    
    % Recria o eixo do tempo para a plotagem exata
    t_vetor = (0:(length(sinal_bruto)-1)) / fps;
    
    % Coluna 1 da Imagem: O Sinal Bruto Original (Só positivo)
    subplot(qtd_videos, 2, i*2 - 1);
    plot(t_vetor, sinal_bruto, 'b', 'LineWidth', 1.5);
    title(['Sinal Absoluto Bruto - ' nome_vid], 'Interpreter', 'none');
    ylabel('Amplitude (Total)'); 
    xlabel('Tempo (s)');
    grid on;
    
    % Coluna 2 da Imagem: O Sinal Processado (Média Removida ou Filtrado)
    subplot(qtd_videos, 2, i*2);
    plot(t_vetor, sinal_secundario, 'r', 'LineWidth', 1.5);
    title([titulo_secundario ' - ' nome_vid], 'Interpreter', 'none');
    ylabel('Variação de Luz'); 
    xlabel('Tempo (s)');
    grid on;
end

disp('Todos os gráficos foram desenhados na interface visual.');
disp('Pressione Enter no terminal para fechar e terminar.');
pause;
