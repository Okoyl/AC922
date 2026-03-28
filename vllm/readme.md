# vLLM on AC922 with CUDA 

vLLM is working, pretty fast, it is able to build models on the fly (from .safetensors format), as long as they fit the VRAM capacity we have.

It seems at this point there is no unified memory mechanism in vLLM, so llama.cpp seems better for now.

I've submitted a PR that adds a Dockerfile for ppc64le CUDA builds, it uses NVIDIA's CUDA 12.4 UBI8 images to build PyTorch, Triton and all compatible dependencies. It skips DeepGEMM and DeepEP as their minimal CUDA architecture is way higher than the V100's sm_70.

https://github.com/vllm-project/vllm/pull/38397

