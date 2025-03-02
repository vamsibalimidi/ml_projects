#!/usr/bin/env bash

# Add logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Add environment check function
check_env() {
    conda env list | grep "^ml_env " >/dev/null 2>&1
}

# Add package check function
check_package() {
    conda list -n ml_env | grep "^$1 " >/dev/null 2>&1
}

# Modify validation function to be more robust
validate_installation() {
    log "🔍 Validating installation..."
    if ! check_env; then
        log "❌ ML environment not found"
        return 1
    fi
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

# Install and initialize Miniforge if not present
if ! command -v conda &> /dev/null; then
    log "Installing Miniforge..."
    curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-arm64.sh -o miniforge.sh
    bash miniforge.sh -b -p "$HOME/miniforge3"
    rm miniforge.sh
    
    # Initialize conda for the current shell
    eval "$("$HOME/miniforge3/bin/conda" "shell.bash" "hook")"
else
    log "✓ Miniforge already installed"
fi

# Ensure conda is properly initialized
if ! grep -q "conda initialize" ~/.bash_profile ~/.zshrc 2>/dev/null; then
    log "Initializing conda..."
    conda init "$(basename "$SHELL")"
    
    log "⚠️ Conda initialization required. The script will now restart itself."
    log "Please wait..."
    
    # Export the RUN_TESTS flag to persist it across the restart
    export INSTALL_ML_RESTART=1
    export RUN_TESTS=$RUN_TESTS
    
    # Re-execute the script with the same arguments
    exec "$SHELL" -i "$0" "$@"
    exit 0  # This line won't be reached due to exec
fi

# Check if this is a restart and show appropriate message
if [ "${INSTALL_ML_RESTART}" = "1" ]; then
    log "✅ Shell restarted successfully, continuing installation..."
    unset INSTALL_ML_RESTART
fi

# Verify conda is working
if ! command -v conda &>/dev/null; then
    log "❌ Conda is not accessible. Please check the installation."
    exit 1
fi

# Set up project directory
DEFAULT_DIR="$HOME/github/my_repos/ml_projects"
PROJECT_DIR="${1:-$DEFAULT_DIR}"

# Safely create project directory
if [ ! -d "$PROJECT_DIR" ]; then
    log "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
else
    log "✓ Project directory already exists"
fi

cd "$PROJECT_DIR"
log "🚀 Working in: $PROJECT_DIR"

# Create and activate Conda environment
if ! check_env; then
    log "🔨 Creating Conda environment..."
    conda create -n ml_env python=3.10 -y
else
    log "✓ ML environment already exists"
fi

# Ensure we can activate the environment
eval "$(conda shell.bash hook)"
conda activate ml_env || { log "❌ Failed to activate environment. Please restart your terminal and try again."; exit 1; }

# Package descriptions:
# numpy        - Essential package for scientific computing with Python. Provides support for large, multi-dimensional arrays and matrices
# pandas       - Powerful data manipulation library. Provides DataFrames for efficient data analysis and handling
# scikit-learn - Comprehensive machine learning library. Includes various classical ML algorithms and tools
# matplotlib   - Standard plotting library. Creates publication-quality figures and visualizations
# seaborn      - Statistical visualization library built on matplotlib. Provides enhanced styling and complex statistical plots
# jupyter      - Interactive computing environment. Enables creation and sharing of documents containing live code
# nltk         - Natural Language Toolkit. Comprehensive platform for building Python programs to work with human language data
# spacy        - Industrial-strength NLP library. Provides efficient tools for advanced natural language processing
# transformers - State-of-the-art NLP library by Hugging Face. Provides access to pretrained models like BERT, GPT
# pytest       - Testing framework. Makes it easy to write simple and scalable test cases
# black        - Uncompromising code formatter. Maintains consistent Python code style
# pylint       - Static code analyzer. Helps identify programming errors, coding standard violations

PACKAGES=(
    "numpy:Fundamental numerical computing library"
    "pandas:Data manipulation and analysis library"
    "scikit-learn:Machine learning algorithms and tools"
    "matplotlib:Comprehensive plotting and visualization"
    "seaborn:Statistical visualization library"
    "jupyter:Interactive computing and notebooks"
    "nltk:Natural Language Toolkit"
    "spacy:Industrial-strength NLP"
    "transformers:State-of-the-art NLP models"
    "pytest:Testing framework"
    "black:Code formatter"
    "pylint:Code analysis tool"
)

log "📚 Checking and installing ML packages..."
for package_info in "${PACKAGES[@]}"; do
    package=${package_info%%:*}
    description=${package_info#*:}
    if ! check_package "$package"; then
        log "Installing $package ($description)"
        conda install -y -c conda-forge "$package"
    else
        log "✓ $package already installed"
    fi
done

# Install PyTorch with MPS support if not present
if ! check_package "pytorch"; then
    log "🔥 Installing PyTorch with Metal support..."
    conda install -y -c pytorch pytorch torchvision
else
    log "✓ PyTorch already installed"
fi

# Install TensorFlow with Metal support if not present
if ! check_package "tensorflow-deps"; then
    log "📱 Installing TensorFlow with Metal support..."
    conda install -y -c apple tensorflow-deps
    pip install --upgrade tensorflow-macos tensorflow-metal
else
    log "✓ TensorFlow already installed"
fi

# Safely download ML resources
log "📥 Installing and downloading ML resources..."

# Ensure conda environment is activated
eval "$(conda shell.bash hook)"
conda activate ml_env

# Install NLTK and SpaCy using both conda and pip to ensure installation
log "Installing NLTK and SpaCy..."
conda install -y -c conda-forge nltk spacy || {
    log "Conda install failed, trying pip..."
    pip install nltk spacy
}

# Download resources with error handling
python3 -c '
try:
    import nltk
    print("Installing NLTK resources...")
    nltk.download("punkt")
    nltk.download("averaged_perceptron_tagger")
    print("NLTK resources installed successfully")
except Exception as e:
    print(f"Error installing NLTK resources: {e}")

try:
    import spacy
    print("Installing SpaCy resources...")
    import subprocess
    subprocess.run(["python", "-m", "spacy", "download", "en_core_web_sm"], check=True)
    print("SpaCy resources installed successfully")
except Exception as e:
    print(f"Error installing SpaCy resources: {e}")
' || log "⚠️ Warning: Some resources may not have been installed properly"

# Safely create project structure
log "📁 Ensuring project structure exists..."
for dir in data models notebooks src tests docs; do
    if [ ! -d "$PROJECT_DIR/$dir" ]; then
        mkdir -p "$PROJECT_DIR/$dir"
        touch "$PROJECT_DIR/$dir/.gitkeep"
    fi
done

for file in README.md requirements.txt .gitignore; do
    if [ ! -f "$PROJECT_DIR/$file" ]; then
        touch "$PROJECT_DIR/$file"
    fi
done

# Add basic .gitignore only if it's empty
if [ ! -s "$PROJECT_DIR/.gitignore" ]; then
    log "Adding .gitignore template..."
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
fi

# Generate environment file with timestamp
log "📝 Updating environment file..."
conda env export > "environment_$(date +%Y%m%d).yml"
if [ -f environment.yml ]; then
    mv "environment_$(date +%Y%m%d).yml" environment.yml
fi

# Safe cleanup
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