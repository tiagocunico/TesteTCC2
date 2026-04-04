import numpy as np
import cv2

video_path = 'video_input/Rapido_1_5s.mp4'
fator_redimensionamento = 0.05

try:
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("Erro ao abrir vídeo.")
        exit(1)
        
    fps = cap.get(cv2.CAP_PROP_FPS)
    frames = []
    
    while True:
        ret, frame = cap.read()
        if not ret: break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # We need to match imresize(frame, 0.05) from octave.
        # Octave imresize size = ceil(original_size * 0.05)
        h, w = gray.shape
        new_h = int(np.ceil(h * fator_redimensionamento))
        new_w = int(np.ceil(w * fator_redimensionamento))
        
        resized = cv2.resize(gray, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
        frames.append(resized)
        
    cap.release()
    
    video_3d = np.stack(frames, axis=-1)
    H, W, T = video_3d.shape
    
    pixels_por_frame = H * W
    imagem_temporal = video_3d.reshape(pixels_por_frame, T)
    
    print(f"Cubo 3D: {H}x{W}x{T}. Kymograph 2D: {pixels_por_frame}x{T}")
    
    freqs = np.fft.fftfreq(T, d=1.0/fps)
    idx_banda = np.where((freqs >= 0.5) & (freqs <= 3.0))[0]
    
    # Calculate energy in 0.5-3Hz band for each line
    energia_banda = np.zeros(pixels_por_frame)
    for i in range(pixels_por_frame):
        linha = imagem_temporal[i, :]
        linha_no_dc = linha - np.mean(linha)
        linha_fft = np.abs(np.fft.fft(linha_no_dc))
        energia_banda[i] = np.sum(linha_fft[idx_banda]**2)
        
    start_idx = 2000
    end_idx = min(3000, pixels_por_frame)
    
    if start_idx < pixels_por_frame:
        best_line = start_idx + np.argmax(energia_banda[start_idx:end_idx])
        print(f"Linha sugerida COM sinal (Max Energia entre 2000-3000): {best_line+1}") # +1 for 1-based indexing in octave
        print(f"Energia na banda 0.5-3Hz desta linha: {energia_banda[best_line]}")
    else:
        print("Não há 2000 linhas na imagem!")
        
    if pixels_por_frame > 1500:
        print(f"Energia na banda 0.5-3Hz da linha 1500: {energia_banda[1499]}") # 1499 is 1500th element
        
    worst_line = np.argmin(energia_banda)
    print(f"Linha sugerida SEM sinal (Menor Energia): {worst_line+1}")
except Exception as e:
    print(f"Error: {e}")
