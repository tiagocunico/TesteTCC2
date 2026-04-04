% -------------------------------------------------------------------------
% GERADOR SINTÉTICO E FFT 3D PARA ANÁLISE MATEMÁTICA
% -------------------------------------------------------------------------
% Este script cria um vídeo matemático puro na memória.
% Permite testar matrizes de qualquer dimensão (pares ou ímpares)
% e analisar o pico luminoso (FFT 3D) isolado de arquivos MP4/MKV.
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% 1. PARÂMETROS DO "VÍDEO" (Modifique as variáveis abaixo)
% -------------------------------------------------------------------------
dim_altura = 10;            % Altura da imagem em pixels (Ny)
dim_largura = 10;           % Largura da imagem em pixels (Nx)

% Padrão de um ciclo único (Ex: Y pretos, Z brancos, W pretos)
frames_pretos_inicio = 20;  % Quantos frames TOTALMENTE PRETOS rodam antes do flash
frames_brancos = 1;         % Quantos frames o centro ficará ACESO (Branco)
frames_pretos_fim = 0;      % Quantos frames TOTALMENTE PRETOS rodam depois do flash

% Repetição
ciclos_totais = 5;          % Quantas vezes esse padrão inteiro vai se repetir (X)

% Visualização
mostrar_frames_gerados = false; % Mude para false se não quiser ver a janela de preview dos frames

% -------------------------------------------------------------------------
% 2. GERAÇÃO DA MATRIZ DO VÍDEO (CÍCLICA)
% -------------------------------------------------------------------------
frames_por_ciclo = frames_pretos_inicio + frames_brancos + frames_pretos_fim;
total_frames = frames_por_ciclo * ciclos_totais;

disp(['Criando matriz sintetica ', num2str(dim_altura), 'x', num2str(dim_largura), ...
      ' com ', num2str(total_frames), ' frames totais (', num2str(ciclos_totais), ' ciclos)...']);

% Inicializa tudo preto (tudo zero)
video_3d = zeros(dim_altura, dim_largura, total_frames);

% Calcula os índices do centro (1 pixel se ímpar, 4 pixels se par)
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

% Acende o(s) pixel(s) central(is) nos frames especificados repetindo por cada ciclo
for ciclo = 1:ciclos_totais
    % Calcula onde o ciclo atual começa no tempo global
    offset_ciclo = (ciclo - 1) * frames_por_ciclo;

    inicio_do_flash = offset_ciclo + frames_pretos_inicio + 1;
    fim_do_flash = inicio_do_flash + frames_brancos - 1;

    for t = inicio_do_flash : fim_do_flash
        video_3d(y_idx, x_idx, t) = 255; % Valor máximo de brilho (Branco)
    end
end

disp(['Luz central pulsou ', num2str(ciclos_totais), ' vezes.']);

% -------------------------------------------------------------------------
% 2.5 VISUALIZAÇÃO DA LISTA DE FRAMES GERADOS
% -------------------------------------------------------------------------
if mostrar_frames_gerados
    disp('Gerando preview dos frames (pode demorar um instante se houver muitos)...');
    figure('Name', 'Lista de Frames Gerados', 'Position', [50, 50, 1000, 800]);

    % Calcula quantas linhas e colunas precisamos para o mosaico (máximo 10 colunas)
    colunas_mosaic = min(10, total_frames);
    linhas_mosaic = ceil(total_frames / colunas_mosaic);

    for f = 1:total_frames
        subplot(linhas_mosaic, colunas_mosaic, f);

        % Mostra o frame em preto (0) e branco (255)
        imshow(video_3d(:,:,f), [0 255]);

        % Coloca o número do frame bem pequeno embaixo
        title(num2str(f), 'FontSize', 8);
    end
    drawnow;
end

% -------------------------------------------------------------------------
% 3. CÁLCULO DA FFT 3D NORMAL (Com Shift e Log)
% -------------------------------------------------------------------------
disp('Calculando a FFT 3D...');
fft_result = fftn(video_3d);

% Análise Normal: Com fftshift (origem no centro) e log (escala logarítmica)
fft_shifted = fftshift(fft_result);
magnitude = abs(fft_shifted);
magnitude_log = log10(1 + magnitude);

% -------------------------------------------------------------------------
% 4. GERAÇÃO DO GRÁFICO 3D
% -------------------------------------------------------------------------
disp('Preparando o gráfico 3D...');

% Eixos normalizados e centralizados da FFT (bins reais calculados de acordo com N par ou ímpar)
if mod(dim_altura, 2) == 0
    fy = (-dim_altura/2 : dim_altura/2 - 1) / dim_altura;
else
    fy = (-(dim_altura-1)/2 : (dim_altura-1)/2) / dim_altura;
end

if mod(dim_largura, 2) == 0
    fx = (-dim_largura/2 : dim_largura/2 - 1) / dim_largura;
else
    fx = (-(dim_largura-1)/2 : (dim_largura-1)/2) / dim_largura;
end

if mod(total_frames, 2) == 0
    ft = (-total_frames/2 : total_frames/2 - 1) / total_frames;
else
    ft = (-(total_frames-1)/2 : (total_frames-1)/2) / total_frames;
end

[X, Y, T] = meshgrid(fx, fy, ft);

% Coleta apenas os pontos dominantes em escala log
threshold = prctile(magnitude_log(:), 99);
idx = find(magnitude_log > threshold);

% =========================================================================
% EXTRAÇÃO DA FREQUÊNCIA A PARTIR DOS DADOS DA FFT
% =========================================================================
% Achata os eixos espaciais (tira a média) para avaliar onde há picos puramente no eixo do tempo (Z)
espectro_tempo = squeeze(mean(mean(magnitude, 1), 2));

% Em matrizes matematicamente tão puras e curtas, a ladeira da componente DC (Frequência Zero)
% escorre maciçamente para os lados (Vazamento Espectral). Para não detectar
% um ponto na ladeira da DC ao invés do próprio pico de frequência que buscamos,
% nós filtramos o vetor ignorando ladeiras e salvando APENAS Picos Locais (Topos de morro):
picos = zeros(size(espectro_tempo));

% Se for um sinal no limite temporal de Nyquist (ex: 1 frame preto, 1 branco repetindo),
% O harmônico verdadeiro estará literalmente colado na borda absoluta da matriz.
% Avaliamos as subidas com >= para permitir ombros planos na resolução discreta.
for i = 1:length(espectro_tempo)
    % Verifica vizinho da esquerda (se existir)
    maior_esq = (i == 1) || (espectro_tempo(i) >= espectro_tempo(i-1));
    % Verifica vizinho da direita (se existir)
    maior_dir = (i == length(espectro_tempo)) || (espectro_tempo(i) >= espectro_tempo(i+1));

    if maior_esq && maior_dir
        picos(i) = espectro_tempo(i);
    end
end

% A Frequência Zero também é um pico gigante. Achamos o índice matematicamente exato dela (0 Hz)
% CUIDADO: Valores em ponto flutuante na criação do vetor podem não ser exatamente 0.000...
% Buscamos o índice mais próximo de zero por diferença absoluta.
[~, idx_dc] = min(abs(ft));
picos(idx_dc) = 0;
% Zeramos o pico DC absoluto do nosso vetor de busca

% Em matrizes pares, o zero da FFT não fica no centro exato matemático,
% então por segurança zeramos também os 2 vizinhos contíguos do topo DC
picos(idx_dc + 1) = 0;
picos(max(1, idx_dc - 1)) = 0;

% O próximo maior pico de energia restante é garantidamente a nossa Frequência Fundamental.
% IMPORTANTE: Em vídeos sintéticos "puros" de flashes muito curtos (1 frame),
% os harmônicos gerados na FFT podem ter todos a mesmíssima energia máxima.
% A função max() comum traria apenas o "primeiro" vetor (a frequência mais negativa e errada).
[val_max, ~] = max(picos);

% Encontramos todos os picos de energia que empatam no máximo (tolerância de precisão float)
idx_empatados = find(picos >= val_max * 0.999);

% Dentre os picos de energia máxima, a Frequência Fundamental é obrigatóriamente a mais próxima do Zero!
[~, i_min] = min(abs(ft(idx_empatados)));
loc_max = idx_empatados(i_min);

% Associa o índice encontrado ao valor real da frequência convertendo pro eixo centralizado (ft)
freq_fft_encontrada = abs(ft(loc_max));
% =========================================================================

figure('Name', 'Gerador Sintetico - FFT 3D Normal', 'Position', [150, 150, 800, 600]);

scatter3(X(idx), Y(idx), T(idx), 30, magnitude_log(idx), 'filled');
xlabel('Freq. Espacial X');
ylabel('Freq. Espacial Y');
zlabel('Freq. Temporal Z');
title(['Espectro FFT 3D Normal (Matriz ', num2str(dim_altura), 'x', num2str(dim_largura), ...
       ', Flash: ', num2str(frames_brancos), ' frame)']);
colormap('jet');
c = colorbar;
ylabel(c, 'Magnitude Logaritmica');
grid on;

% Realça a origem DC Normal (Com Shift) na posição (0,0,0)
hold on;
plot3(0, 0, 0, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');

% Destaca a Frequência Fundamental (Descoberta cegamente pela FFT) no eixo do Tempo
plot3(0, 0, freq_fft_encontrada, 'gp', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
plot3(0, 0, -freq_fft_encontrada, 'gp', 'MarkerSize', 12, 'MarkerFaceColor', 'g');

legend('Frequências Dominantes', 'Origem (Componente DC)', 'Frequência Extraída da FFT (+/-)');
hold off;

disp('-------------------------------------------------------------------------');
disp('ANÁLISE DE FREQUÊNCIA:');
disp([' A taxa de repeticao configurada no video foi de 1 flash a cada ', ...
      num2str(frames_por_ciclo), ' frames.']);
disp([' Matematicamente, a frequencia temporal real esperada seria de: 1 / ', ...
      num2str(frames_por_ciclo), ' = ', num2str(1/frames_por_ciclo, '%.4f'), ' (Normalizada).']);
disp(' ');
disp([' ----> Frequencia Fundamental EXTRAIDA CEGAMENTE PELA FFT: ', ...
      num2str(freq_fft_encontrada, '%.4f')]);
disp(' ');

if abs(freq_fft_encontrada - (1/frames_por_ciclo)) < 1e-4
    disp(' SUCESSO! A Transformada de Fourier reconstruiu os ciclos do seu');
    disp(' vídeo puramente lendo os picos de energia e acertou em cheio a Frequencia!');
else
    disp(' ALERTA: A FFT detectou uma frequencia proxima. (Discrepancia minima gerada pela resolucao finita de blocos de tempo).');
end

disp(' ');
disp(' Verifique no grafico 3D: as ESTRELAS VERDES correspondem ao pico exato Detectado/Extraido pela FFT!');
disp('-------------------------------------------------------------------------');

disp('Processo finalizado com sucesso! Pressione "Enter" no terminal para fechar e sair.');
pause;
