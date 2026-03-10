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
dim_altura = 3;             % Altura da imagem em pixels (Ny)
dim_largura = 3;            % Largura da imagem em pixels (Nx)

% Padrão de um ciclo único (Ex: Y pretos, Z brancos, W pretos)
frames_pretos_inicio = 9;   % Quantos frames TOTALMENTE PRETOS rodam antes do flash
frames_brancos = 1;         % Quantos frames o centro ficará ACESO (Branco)
frames_pretos_fim = 0;      % Quantos frames TOTALMENTE PRETOS rodam depois do flash

% Repetição
ciclos_totais = 5;          % Quantas vezes esse padrão inteiro vai se repetir (X)

% Visualização
mostrar_frames_gerados = true; % Mude para false se não quiser ver a janela de preview dos frames

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
% 3. CÁLCULO DA FFT 3D "PURA"
% -------------------------------------------------------------------------
disp('Calculando a FFT 3D...');
fft_result = fftn(video_3d);

% Análise Pura: Sem fftshift (origem no canto) e Sem log (escala linear)
magnitude = abs(fft_result);

% -------------------------------------------------------------------------
% 4. GERAÇÃO DO GRÁFICO 3D
% -------------------------------------------------------------------------
disp('Preparando o gráfico 3D...');

fy = 1:dim_altura;
fx = 1:dim_largura;
ft = 1:total_frames;

[X, Y, T] = meshgrid(fx, fy, ft); 

% Coleta apenas os pontos dominantes
threshold = prctile(magnitude(:), 99);
idx = find(magnitude > threshold);

% =========================================================================
% EXTRAÇÃO DA FREQUÊNCIA A PARTIR DOS DADOS DA FFT
% =========================================================================
% Achata os eixos espaciais (tira a média) para avaliar o eixo z do tempo
espectro_tempo = squeeze(mean(mean(magnitude, 1), 2));

% Filtramos a matriz garantindo buscar apenas picos locais (reais subidas de energia na matriz)
% Se o sinal oscilar 1 frame branco / 1 preto, a frequência de Nyquist máxima estará
% no limite central do array na FFT pura, formando um "pico plano" no vetor.
picos = zeros(size(espectro_tempo));
for i = 1:length(espectro_tempo)
    % Cobre os dois lados permitindo patamares (>=) e lida com as pontas
    maior_esq = (i == 1) || (espectro_tempo(i) >= espectro_tempo(i-1));
    maior_dir = (i == length(espectro_tempo)) || (espectro_tempo(i) >= espectro_tempo(i+1));
    
    if maior_esq && maior_dir
        picos(i) = espectro_tempo(i);
    end
end

% O DC é obrigatoriamente o maior absurdo de energia na casa 1, 
% e a sua franja vaza pros primeiros índices, bem como pro final rebatido
vizinhanca_segura_dc = min(3, ceil(length(picos)*0.05));
for i = 1:vizinhanca_segura_dc
   picos(i) = 0;
   picos(max(1, length(picos) - i + 1)) = 0; % zera o correspondente espelhado no final
end

% O pico isolado restante onde se concentra a maior força luminosa será nossa fundamental.
% IMPORTANTE: Flashes ultracurtos geram energia máxima igual para os harmônicos na FFT pura.
[val_max, ~] = max(picos);

% Pegamos todos os picos empatados em energia máxima (tolerando precisão float)
idx_empatados = find(picos >= val_max * 0.999);

% Na matriz pura (sem fftshift), as frequências crescem a partir do índice 1. 
% O primeiro índice com o pico de energia máxima já é imediatamente o harmônico fundamental!
loc_max = idx_empatados(1);

% Como a FFT é cíclica e não está centralizada, o pico achado é diretamente o nosso alvo temporal em Índice Base-1
idx_fft_encontrada = loc_max;

% E a cópia rebatida pro fim do ciclo (simetria espelhada) será:
passos = idx_fft_encontrada - 1;
idx_fft_rebatido = total_frames - passos + 1;
% =========================================================================

figure('Name', 'Gerador Sintetico - FFT 3D', 'Position', [150, 150, 800, 600]);

scatter3(X(idx), Y(idx), T(idx), 30, magnitude(idx), 'filled');
xlabel('Eixo X Espacial (Pixels)');
ylabel('Eixo Y Espacial (Pixels)');
zlabel('Eixo Z Temporal (Frames)');
title(['Espectro FFT 3D Puro (Matriz ', num2str(dim_altura), 'x', num2str(dim_largura),...
       ', Flash: ', num2str(frames_brancos), ' frame)']);
colormap('jet');
colorbar;
grid on;

% Realça a origem DC Pura (Sem Shift) na posição (1,1,1)
hold on;
plot3(1, 1, 1, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');

% Destaca a Frequência detectada e extraída cegamente da matriz da FFT (Lembrando que usamos Índices)
plot3(1, 1, idx_fft_encontrada, 'gp', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
plot3(1, 1, idx_fft_rebatido, 'gp', 'MarkerSize', 12, 'MarkerFaceColor', 'g');

legend('Frequências Dominantes', 'Origem (Componente DC)', 'Frequência Extraída da FFT (+/-)');
hold off;

disp('-------------------------------------------------------------------------');
disp('ANÁLISE DE FREQUÊNCIA:');
disp([' A contagem original que configuramos foi de ', num2str(ciclos_totais), ' ciclos.']);
disp(' Dentro de uma FFT que nao foi deslocada (base-1), isso ESPERÁVELMENTE faria a FFT explodir de energia nos sub-grupos cíclicos:');
disp([' -> ÍNDICE: 1 + Ciclos Totais = ', num2str(ciclos_totais + 1), ' e [Espelho rebatido no final da matriz] = ', num2str(total_frames - ciclos_totais + 1)]);
disp(' ');
disp([' ----> Índices Fundamentais EXTRAÍDOS CEGAMENTE LENDO DENTRO DA FFT: ', num2str(idx_fft_encontrada), ' e ', num2str(idx_fft_rebatido)]);
disp(' ');

if idx_fft_encontrada == (ciclos_totais + 1)
    disp(' SUCESSO! A Transformada de Fourier pura processou os seus blocos orgânicos soltos e cravou, sozinha, os andares temporais exatos!');
else
    disp(' AVISO: A contagem divergiu. Verifique as configurações de ciclo e se os recortes estao em quantidades fechadas.');
end
disp(' ');
disp(' Em resumo, as ESTRELAS VERDES são formadas agora lendo a matriz da própria energia detectada!');
disp('-------------------------------------------------------------------------');

disp('Processo finalizado com sucesso! Pressione "Enter" no terminal para fechar e sair.');
pause;
