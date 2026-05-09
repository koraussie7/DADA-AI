#!/bin/bash
# OpenMythos Model Quantization Script
# Phase 0-6: Convert OpenMythos to GGUF for LocalAI

set -e

MODEL_DIR="localai/models"
OPENMYTHOS_DIR="$MODEL_DIR/openmythos"

echo "============================================"
echo "  OpenMythos Quantization"
echo "============================================"

# Step 1: Install llama.cpp
if ! command -v llama-quantize &> /dev/null; then
    echo "[1/4] Building llama.cpp..."
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp
    cd /tmp/llama.cpp
    make -j$(nproc) LLAMA_CUDA=1
    cd -
fi

# Step 2: Download OpenMythos
echo "[2/4] Downloading OpenMythos-770M-RDT..."
mkdir -p "$OPENMYTHOS_DIR"

if [ ! -f "$OPENMYTHOS_DIR/model.safetensors" ]; then
    huggingface-cli download kyegomez/OpenMythos \
        --local-dir "$OPENMYTHOS_DIR" \
        --local-dir-use-symlinks False
fi

# Step 3: Convert to GGUF
echo "[3/4] Converting to GGUF Q4_K_M..."
python /tmp/llama.cpp/convert_hf_to_gguf.py \
    "$OPENMYTHOS_DIR" \
    --outfile "$MODEL_DIR/openmythos-770M-RDT-Q4_K_M.gguf" \
    --outtype q4_k_m

# Step 4: Create LocalAI config
echo "[4/4] Creating LocalAI config..."
cat > "$MODEL_DIR/../config/openmythos.yaml" << YAML
name: openmythos-770M-RDT
backend: llama
parameters:
  model: /models/openmythos-770M-RDT-Q4_K_M.gguf
  temperature: 0.65
  recurrent_depth: 4
  context_size: 2048
  threads: 4
YAML

echo ""
echo "OpenMythos quantization complete!"
echo "Model: $MODEL_DIR/openmythos-770M-RDT-Q4_K_M.gguf"
