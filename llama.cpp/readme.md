# Dependencies

```sh
dnf install -y openssl3-devel
```

# Build

```sh
cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_CUDA_FA_ALL_QUANTS=ON \
    -DGGML_CUDA_PEER_MAX_BATCH_SIZE=256 \
    -DGGML_CUDA_NCCL=ON \
    -DGGML_CUDA_GRAPHS=ON \
    -DGGML_CUDA_FA=ON \
    -DGGML_CUDA_COMPRESSION_MODE=none \
    -DGGML_LTO=ON \
    -DLLAMA_LLGUIDANCE=ON \
    -DGGML_SCHED_MAX_COPIES=4 \
    -DCMAKE_CUDA_ARCHITECTURES=70 \
    -DCMAKE_EXE_LINKER_FLAGS="-ldl" \
    -DLLAMA_OPENSSL=ON \
    -DOPENSSL_ROOT_DIR=/usr/include/openssl3 \
    -DOPENSSL_SSL_LIBRARY=/usr/lib64/openssl3/libssl.so \
    -DOPENSSL_CRYPTO_LIBRARY=/usr/lib64/openssl3/libcrypto.so

cmake --build build --config Release -j$(nproc)

```

# Running?

Gemma 4 31B - Unsloth Q4_K_XL

```bash
GGML_CUDA_P2P=1 \
GGML_CUDA_REGISTER_HOST=1 \
GGML_OP_OFFLOAD_MIN_BATCH=1 \
GGML_CUDA_GRAPH_OPT=1 \
CUDA_SCALE_LAUNCH_QUEUES=16x \
GGML_CUDA_FORCE_CUBLAS_COMPUTE_16F=1 \
GGML_CUDA_ENABLE_UNIFIED_MEMORY=1 \
./bin/llama-server --host 0.0.0.0 --port 8081 \
    --ssl-key-file /root/.llama-server/key.pem --ssl-cert-file /root/.llama-server/cert.pem \
    --api-key <Redacted> \
    -m /mnt/data/models/gemma-4-31B-it-UD-Q4_K_XL.gguf --mmproj /mnt/data/models/gemma-4-mmproj-F16.gguf \
    -ngl 99 --keep -1 --ctx-size 800000 --flash-attn on --numa distribute --parallel 4 \
    -ts 11,11,11,11 --jinja --no-mmap  \
    --poll 0 -t 8 -tb 32 \
    --alias model
```

# Performance Boost?

I discovered the libvirt networking slowness issue that I solved using:

```bash
for i in /sys/devices/system/cpu/cpu*/cpuidle/state[2-9]/disable; do echo 1 > $i; done
```

Is getting me 10tk/s more in Gemma 4 31B. That's insane!
