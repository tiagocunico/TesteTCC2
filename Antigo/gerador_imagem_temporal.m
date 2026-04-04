% =========================================================================
% SCRIPT: GERADOR SINTÉTICO - IMAGEM ESPAÇO-TEMPO
% =========================================================================
% Objetivo: Gerar o vídeo sintético matricial de flash contínuo e transformá-lo
% em uma imagem 2D única (Pixels Vetorizados x Tempo).
% =========================================================================
clear all;
close all;
clc;

% =========================================================================
% PARÂMETROS DE GERAÇÃO SINTÉTICA
% =========================================================================
% Dimensões espaciais do frame de simulação
dim_altura = 5;             % Altura da imagem em pixels (Ny)
dim_largura = 5;            % Largura da imagem em pixels (Nx)

% Padrão de um ciclo único (Ex: Y pretos, Z brancos, W pretos)
frames_pretos_inicio = 4;   % Quantos frames TOTALMENTE PRETOS rodam antes do flash
frames_brancos = 1;         % Quantos frames o centro ficará ACESO (Branco)
frames_pretos_fim = 0;      % Quantos frames TOTALMENTE PRETOS rodam depois do flash

% Número de vezes que o ciclo vai repetir
ciclos_totais = 5;

% Configurações de Visualização
mostrar_frames_gerados = true; % Mostra o mosaico com os quadros originais do video gerado

% =========================================================================
% INICIALIZAÇÃO E ALOCAÇÃO
% =========================================================================
frames_por_ciclo = frames_pretos_inicio + frames_brancos + frames_pretos_fim;
total_frames = frames_por_ciclo * ciclos_totais;

disp('-------------------------------------------------------------------------');
disp(['Criando matriz sintetica ', num2str(dim_altura), 'x', num2str(dim_largura), ...
      ' com ', num2str(total_frames), ' frames totais...']);

% Alocação do vídeo tridimensional Y, X, T:
video_3d = zeros(dim_altura, dim_largura, total_frames);

% Encontrando o(s) pixel(s) central(is)
if mod(dim_altura, 2) == 0
    y_idx = [dim_altura/2, dim_altura/2 + 1];
else
    y_idx = ceil(dim_altura/2);
end

if mod(dim_largura, 2) == 0
    x_idx = [dim_largura/2, dim_largura/2 + 1];
else
    x_idx = ceil(dim_largura/2);
end

% Preenchimento orgânico de repetições
contador_pluses = 0;
for ciclo = 1:ciclos_totais
    offset_ciclo = (ciclo - 1) * frames_por_ciclo;

    inicio_do_flash = offset_ciclo + frames_pretos_inicio + 1;
    fim_do_flash = inicio_do_flash + frames_brancos - 1;

    for t = inicio_do_flash : fim_do_flash
        video_3d(y_idx, x_idx, t) = 255; % Branco Intenso
        contador_pluses = contador_pluses + 1;
    end
end
disp(['Luz central pulsou ', num2str(contador_pluses), ' vezes.']);

% =========================================================================
% TRANSFORMAÇÃO ESPAÇO-TEMPO (VETORIZAÇÃO DOS FRAMES)
% =========================================================================
disp('Vetorizando matriz de video 3D para imagem 2D...');

% A nova matriz cortará a geometria espacial, transformando Altura e Largura numa lista reta só.
pixels_por_frame = dim_altura * dim_largura;

% Em matemática pura de processamento de imagem, o algoritmo sequencial seria:
% imagem_temporal = zeros(pixels_por_frame, total_frames);
% for t = 1:total_frames
%    frame_atual = video_3d(:, :, t);
%    imagem_temporal(:, t) = frame_atual(:); % O operador (:) espalma a matriz 2D em 1D
% end

% PORÉM, o MATLAB/Octave é absurdamente poderoso nisso, fazemos a mesma coisa
% nativamente em 1 linha e incrivelmente rápido usando reshape:
imagem_temporal = reshape(video_3d, pixels_por_frame, total_frames);

% =========================================================================
% EXTRAÇÃO DE FREQUÊNCIA DIRETO DA NOVA IMAGEM 2D VECTORIZADA
% =========================================================================
disp('---');
disp('>> EXTRAINDO FREQUENCIA DIRETO DA IMAGEM 2D (SEM USAR 3D) <<');
% Achata todos os pixels combinados verticalmente para um único array 1D no tempo
sinal_1d = mean(imagem_temporal, 1);

% Aplica a FFT 1D clássica pura
fft_1d = fft(sinal_1d);
espectro_1d = abs(fft_1d);

% Procura os picos locais para pular a DC e ruídos da borda
picos_1d = zeros(size(espectro_1d));
for i = 1:length(espectro_1d)
    maior_esq = (i == 1) || (espectro_1d(i) >= espectro_1d(i-1));
    maior_dir = (i == length(espectro_1d)) || (espectro_1d(i) >= espectro_1d(i+1));
    if maior_esq && maior_dir
        picos_1d(i) = espectro_1d(i);
    end
end

% Cegueira dinâmica pro DC Leak de 5% da borda na FFT pura
dist_segura_bins = max(3, ceil(total_frames * 0.05));
for i = 1:dist_segura_bins
    if i <= length(picos_1d)
        picos_1d(i) = 0;
    end
    if (length(picos_1d) - i + 1) >= 1
        picos_1d(length(picos_1d) - i + 1) = 0;
    end
end

% Acha os harmônicos de energia máxima na FFT 1D indexada (Base 1)
[val_max_1d, ~] = max(picos_1d);
idx_empatados_1d = find(picos_1d >= val_max_1d * 0.999);
loc_max_1d = idx_empatados_1d(1);

% Converte o índice encontrado para Frequência Normalizada Real (Hz temporal)
freq_extraida_img = (loc_max_1d - 1) / total_frames;
freq_esperada = 1 / frames_por_ciclo;

disp(['Frequencia extraida puramente do Kymograph (Imagem 2D): ', num2str(freq_extraida_img, '%.4f')]);
disp(['Frequencia matemática esperada (Configuração): ', num2str(freq_esperada, '%.4f')]);
disp('---');

% =========================================================================
% PLOT DA IMAGEM TEMPORAL
% =========================================================================
disp('Preparando o grafico 2D espaço-tempo...');

% Cria Janela Gráfica Maximizada (se possível) para exibir o resultado
fig = figure('Name', 'Imagem Espaco-Tempo (Kymograph)', 'NumberTitle', 'off', ...
             'Position', [100, 100, 1000, 600]);

% A função imagesc escalona perfeitamente matrizes numa paleta de cor
imagesc(imagem_temporal);
colormap(gray);
% Pede pro matlab printar como fotografia em preto e branco clássica

% Embelezamento do Gráfico
title('Representação Espaço-Temporal: Pixels Vetorizados ao longo do Tempo', ...
      'FontSize', 12, 'FontWeight', 'bold');
xlabel('Pico de Tempo (Frames \rightarrow)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Espaço Pixel Vetorizado (\downarrow)', 'FontSize', 11, 'FontWeight', 'bold');

% Mostra os valores reais nos ticks ao invés do limite padrao apenas
xticks(1:1:total_frames);
grid on;

% Define um box em volta pro acabamento
box on;

% Traz barra de força luminosa
colorbar;

disp('-------------------------------------------------------------------------');
disp(' SUCESSO! A matriz 3D inteira do seu video acaba de virar uma única Imagem de pixels');
disp(' mostrando exatamente quais leds acendem, por quanto tempo, e em quais andares temporais!');
disp('-------------------------------------------------------------------------');
disp('Processo finalizado com sucesso! Pressione "Enter" no terminal para fechar e sair.');

% =========================================================================
% VISUALIZAÇÃO DOS FRAMES (GRELHA 2D) E LOG CORINGADO
% =========================================================================
if mostrar_frames_gerados
    disp('Gerando grelha visual de frames individuais...');
    % Se tiver muitos frames, capamos para não travar a plotagem do grid
    limite_plot_frames = min(total_frames, 64); % Evita abrir centenas de subplots

    colunas_plot = ceil(sqrt(limite_plot_frames));
    linhas_plot = ceil(limite_plot_frames / colunas_plot);

    fig_frames = figure('Name', 'Preview dos Frames Gerados', 'NumberTitle', 'off', ...
                        'Position', [150, 150, 900, 700]);
    colormap(gray);

    ja_printou_coordenadas = false; % Flag de controle

    for t = 1:limite_plot_frames
        subplot(linhas_plot, colunas_plot, t);

        % Conta quantos pixels estao acesos (maior que 0) neste frame específico
        frame_atual = video_3d(:, :, t);
        num_pixels_acesos = sum(frame_atual(:) > 0);

        % Printa no terminal APENAS SE TIVER LUZ E FOI O PRIMEIRO REGISTRO
        if num_pixels_acesos > 0 && ~ja_printou_coordenadas
            % find() no MATLAB rastreia por Coluna primeiro (Linear Indexing "de pé")
            [y_acos, x_acos] = find(frame_atual > 0);
            disp(['Exemplo do 1º Frame com luz (t=', num2str(t), '): ', ...
                  num2str(num_pixels_acesos), ' pixels brancos nas Coordenadas [Y/Linha, X/Coluna]: ']);
            for p = 1:length(y_acos)
                disp(['  -> [Linha: ', num2str(y_acos(p)), ', Coluna: ', num2str(x_acos(p)), ']']);
            end
            ja_printou_coordenadas = true;
            % Trava pra não spammar os próximos frames brancos iguais
        end

        % Função image desenhando diretamente o mapa de calor escalonado
        imagesc(frame_atual, [0 255]);

        axis off;
        % Removemos os eixos pra parecer um vídeo puro

        % Titulo pequeno para cada frame com a contagem de pixels nela
        title(['t:', num2str(t), ' (', num2str(num_pixels_acesos), 'px)'], 'FontSize', 8);
    end

    % Titulo principal da superfigura (com fallback de segurança pro Octave)
    try
        sgtitle(['Preview Espacial: Primeiros ', num2str(limite_plot_frames), ...
                 ' Frames do Vídeo Sintético'], 'FontSize', 12, 'FontWeight', 'bold');
    catch
    end

    drawnow;
end

% Segura o script rodando pra manter a janela aberta (Bloqueia até usuário pressionar tecla)
pause;
