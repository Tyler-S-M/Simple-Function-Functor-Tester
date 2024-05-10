all:
	nvcc -D CUDA_FORCE_CDP1_IF_SUPPORTED -lcuda -lcudart -rdc=true main.cu -o main
clean:
	rm main
