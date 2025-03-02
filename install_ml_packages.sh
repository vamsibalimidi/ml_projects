#!/usr/bin/env bash

# Add logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Add validation function
validate_installation() {
    log "🔍 Validating installation..."
    python3 -c "
import numpy as np
import torch
import tensorflow as tf
print('NumPy version:', np.__version__)
print('PyTorch version:', torch.__version__)
print('TensorFlow version:', tf.__version__)
print('MPS (Metal) available:', torch.backends.mps.is_available())
print('Metal plugin available:', tf.config.list_physical_devices('GPU'))
x = torch.rand(3, 3)
if torch.backends.mps.is_available():
    x = x.to('mps')
print('Test tensor device:', x.device)
"
}

# Show help message
show_help() {
    echo """
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

Options:
    -h, --help      Show this help message
    -t, --test      Run post-installation tests
    
Arguments:
    DIRECTORY       Optional: Installation directory (default: $HOME/github/my_repos/ml_projects)

Examples:
    $(basename "$0")                     # Install in default directory
    $(basename "$0") -t                  # Install and run tests
    $(basename "$0") --help              # Show this help message
"""
    exit 0
}

# Parse command line arguments
RUN_TESTS=false

while [[ "$1" =~ ^- ]]; do
    case $1 in
        -h | --help ) show_help ;;
        -t | --test ) RUN_TESTS=true; shift ;;
        * ) echo "Unknown option: $1"; show_help ;;
    esac
done

# Exit on error
set -e

log "🍎 Setting up ML environment for Apple Silicon Mac"

# Install Miniforge if not present
if ! command -v conda &> /dev/null; then
    log "Installing Miniforge..."
    curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-arm64.sh -o miniforge.sh
    bash miniforge.sh -b -p "$HOME/miniforge3"
    rm miniforge.sh
    source "$HOME/miniforge3/bin/activate"
    conda init bash
fi

# Set up project directory
DEFAULT_DIR="$HOME/github/my_repos/ml_projects"
PROJECT_DIR="${1:-$DEFAULT_DIR}"

# Validate and create project directory
if [ ! -d "$PROJECT_DIR" ]; then
    log "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"
log "🚀 Starting ML environment setup in: $PROJECT_DIR"

# Create and activate Conda environment
log "🔨 Creating Conda environment..."
conda create -n ml_env python=3.10 -y
conda activate ml_env

# Install ML packages optimized for Apple Silicon
log "📚 Installing ML packages..."
conda install -y -c conda-forge \
    # Fundamental numerical computing library for scientific computing
    numpy \
    # Data manipulation and analysis library
    pandas \
    # Machine learning algorithms and tools
    scikit-learn \
    # Comprehensive plotting and visualization library
    matplotlib \
    # Statistical data visualization built on matplotlib
    seaborn \
    # Interactive computing and notebook creation
    jupyter \
    # Natural Language Toolkit for text processing
    nltk \
    # Industrial-strength Natural Language Processing
    spacy \
    # State-of-the-art Natural Language Processing models
    transformers \
    # Testing framework for Python
    pytest \
    # Python code formatter
    black \
    # Python code analysis tool
    pylint

# Install PyTorch with MPS support
log "🔥 Installing PyTorch with Metal support..."
# Deep learning framework with Apple Metal support
conda install -y -c pytorch pytorch torchvision

# Install TensorFlow with Metal support
log "📱 Installing TensorFlow with Metal support..."
# TensorFlow dependencies optimized for Apple Silicon
conda install -y -c apple tensorflow-deps
# TensorFlow core with Metal support for GPU acceleration
pip install tensorflow-macos tensorflow-metal

# Download common ML resources
log "📥 Downloading additional resources..."
python3 -c "
import nltk
nltk.download('punkt')
nltk.download('averaged_perceptron_tagger')
import spacy
spacy.cli.download('en_core_web_sm')
"

# Create common project directories
log "📁 Creating project structure..."
mkdir -p "$PROJECT_DIR"/{data,models,notebooks,src,tests,docs}
touch "$PROJECT_DIR"/{README.md,requirements.txt,.gitignore}

# Add basic .gitignore
echo """
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
ml_env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Jupyter Notebook
.ipynb_checkpoints

# VS Code
.vscode/

# Environment
.env
.venv
venv/
ENV/

# Data
data/*
!data/.gitkeep

# Models
models/*
!models/.gitkeep
""" > "$PROJECT_DIR/.gitignore"

# Generate environment file
log "📝 Generating environment file..."
conda env export > environment.yml

# Cleanup
log "🧹 Cleaning up..."
conda clean --all -y

# Deactivate environment
conda deactivate

# Run post-installation tests if requested
if $RUN_TESTS; then
    log "🧪 Running post-installation tests..."
    validate_installation
fi

echo """
✅ Installation complete!

Project directory: $PROJECT_DIR

To activate the environment:
    conda activate ml_env

To recreate this environment elsewhere:
    conda env create -f environment.yml

📁 Project structure created:
    ./data/          - For datasets
    ./models/        - For saved models
    ./notebooks/     - For Jupyter notebooks
    ./src/          - For source code
    ./tests/        - For unit tests
    ./docs/         - For documentation

🛠️ Development tools installed:
    - pytest (testing)
    - black (code formatting)
    - pylint (code analysis)

📘 Common ML resources downloaded:
    - NLTK datasets
    - SpaCy English model

Happy coding! 🎉
"""