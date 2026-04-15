#!/bin/bash
# patch-volta-cuda-graphs.sh
# Patches llama.cpp to enable CUDA graph capture on Volta (V100, CC 7.0).
#
# By default, CUDA graphs are gated to Ampere+ (CC >= 800).
# CUDA graphs API works on all GPUs from Pascal (CC 6.0) onwards.
# This patch lowers the threshold to Volta (CC >= 700).
#
# Usage:
#   cd /path/to/llama.cpp
#   bash patch-volta-cuda-graphs.sh

set -euo pipefail

FILE="ggml/src/ggml-cuda/ggml-cuda.cu"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found. Run this script from the llama.cpp root directory."
    exit 1
fi

# Check that the line we're patching exists
if ! grep -q 'GGML_CUDA_CC_AMPERE' "$FILE"; then
    echo "ERROR: GGML_CUDA_CC_AMPERE not found in $FILE — already patched or source has changed."
    exit 1
fi

COUNT=$(grep -c 'devices\[cuda_ctx->device\]\.cc < GGML_CUDA_CC_AMPERE' "$FILE")
if [ "$COUNT" -ne 1 ]; then
    echo "ERROR: Expected exactly 1 occurrence of the CC gate, found $COUNT."
    exit 1
fi

sed -i 's/devices\[cuda_ctx->device\]\.cc < GGML_CUDA_CC_AMPERE/devices[cuda_ctx->device].cc < GGML_CUDA_CC_VOLTA/' "$FILE"

echo "Patched $FILE: CUDA graph CC threshold lowered from Ampere (800) to Volta (700)."
