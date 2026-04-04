dim_altura = 2; dim_largura = 2;
frames_pretos_inicio = 1; frames_brancos = 1; frames_pretos_fim = 0; ciclos_totais = 5;
frames_por_ciclo = frames_pretos_inicio + frames_brancos + frames_pretos_fim;
total_frames = frames_por_ciclo * ciclos_totais;

video_3d = zeros(dim_altura, dim_largura, total_frames);
y_idx = [1, 2]; x_idx = [1, 2];

for ciclo = 1:ciclos_totais
    offset_ciclo = (ciclo - 1) * frames_por_ciclo;
    inicio_do_flash = offset_ciclo + frames_pretos_inicio + 1;
    fim_do_flash = inicio_do_flash + frames_brancos - 1;
    for t = inicio_do_flash : fim_do_flash
        video_3d(1, 1, t) = 255;
    end
end
fft_result = fftn(video_3d);
fft_shifted = fftshift(fft_result);
magnitude = abs(fft_shifted);
if mod(total_frames, 2) == 0, ft = (-total_frames/2 : total_frames/2 - 1) / total_frames; else, ft = (-(total_frames-1)/2 : (total_frames-1)/2) / total_frames; end

espectro_tempo = squeeze(mean(mean(magnitude, 1), 2));

disp('ALL FREQS:');
for i=1:length(espectro_tempo)
    disp(['idx: ', num2str(i), ' freq: ', num2str(ft(i)), ' mag: ', num2str(espectro_tempo(i))]);
end

picos = zeros(size(espectro_tempo));
for i = 2:length(espectro_tempo)-1
    if espectro_tempo(i) > espectro_tempo(i-1) && espectro_tempo(i) > espectro_tempo(i+1)
        picos(i) = espectro_tempo(i);
    end
end

[~, idx_dc] = min(abs(ft));
picos(idx_dc) = 0; % Zeramos o pico DC absoluto do nosso vetor de busca
if mod(total_frames, 2) == 0
    picos(idx_dc + 1) = 0;
    picos(max(1, idx_dc - 1)) = 0;
end

[val_max, ~] = max(picos);
idx_empatados = find(picos >= val_max * 0.999);
[~, i_min] = min(abs(ft(idx_empatados)));
loc_max = idx_empatados(i_min);
disp(['Target Freq: ', num2str(abs(ft(loc_max)))]);
