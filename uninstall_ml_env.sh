#!/usr/bin/env bash

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Help message
show_help() {
    echo """
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help      Show this help message
    -a, --all       Remove everything (conda, ML resources)
    -f, --force     Don't ask for confirmation

Examples:
    $(basename "$0")              # Basic cleanup (ML environment only)
    $(basename "$0") --all       # Remove everything except project directory
    $(basename "$0") --all -f    # Remove everything without confirmation
"""
    exit 0
}

# Confirmation function
confirm() {
    if [ "$FORCE" = false ]; then
        read -p "$1 [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
        return $?
    fi
    return 0
}

# Complete conda removal function
cleanup_conda() {
    log "Removing Conda installation..."
    
    # Deactivate and remove environments
    conda deactivate 2>/dev/null || true
    for env in $(conda env list | grep -v '^#' | cut -d' ' -f1); do
        [ ! -z "$env" ] && conda env remove -n "$env" -y 2>/dev/null || true
    done

    # Remove all conda installations
    sudo rm -rf \
        "$HOME/miniforge3" \
        "$HOME/anaconda3" \
        "$HOME/miniconda3" \
        "$HOME/.conda" \
        "$HOME/.condarc" \
        "$HOME/opt/anaconda3" \
        "$HOME/opt/miniconda3" \
        "$HOME/opt/miniforge3" \
        "$HOME/.anaconda" \
        "$HOME/.continuum" \
        "/opt/anaconda3" \
        "/opt/miniconda3" \
        "/opt/miniforge3" \
        "$HOME/Library/Jupyter" \
        "$HOME/Library/Logs/Conda" \
        "$HOME/Library/Application Support/conda"

    # Clean shell configs
    for rcfile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.zprofile" "$HOME/.profile"; do
        if [ -f "$rcfile" ]; then
            log "Cleaning $rcfile"
            sed -i.bak '/conda/d' "$rcfile"
            sed -i.bak '/miniforge/d' "$rcfile"
            sed -i.bak '/# >>> conda initialize/,/# <<< conda initialize/d' "$rcfile"
            rm -f "${rcfile}.bak"
        fi
    done

    # Clean conda from PATH
    export PATH=$(echo $PATH | tr ':' '\n' | grep -v "conda\|miniforge\|anaconda" | tr '\n' ':' | sed 's/:$//')
}

# Parse arguments
REMOVE_ALL=false
FORCE=false

while [[ "$1" =~ ^- ]]; do
    case $1 in
        -h | --help ) show_help ;;
        -a | --all ) REMOVE_ALL=true; shift ;;
        -f | --force ) FORCE=true; shift ;;
        * ) echo "Unknown option: $1"; show_help ;;
    esac
done

# Start uninstallation
log "🗑️ Starting uninstallation process..."

# Get project directory
DEFAULT_DIR="$HOME/github/my_repos/ml_projects"
PROJECT_DIR="${1:-$DEFAULT_DIR}"

# Clean up project structure
if [ -d "$PROJECT_DIR" ] && confirm "Remove project structure (data, models, etc)?"; then
    log "Removing project structure..."
    # Remove directories
    for dir in data models notebooks src tests docs; do
        rm -rf "$PROJECT_DIR/$dir"
    done
    
    # Remove specific files
    for file in README.md requirements.txt .gitignore environment.yml; do
        rm -f "$PROJECT_DIR/$file"
    done
    
    # Remove any environment files with timestamps
    rm -f "$PROJECT_DIR/environment_*.yml"
fi

# Check if conda exists
if command -v conda &> /dev/null; then
    if [ "$REMOVE_ALL" = true ]; then
        if confirm "Remove complete conda installation?"; then
            cleanup_conda
        fi
    else
        if conda env list | grep -q "^ml_env "; then
            if confirm "Remove ML environment?"; then
                conda deactivate 2>/dev/null || true
                conda env remove -n ml_env -y
            fi
        fi
    fi
fi

# Clean ML resources
if [ -d "$HOME/nltk_data" ] && confirm "Remove NLTK data?"; then
    log "Removing NLTK data..."
    rm -rf "$HOME/nltk_data"
fi

if python3 -c "import spacy" &>/dev/null 2>&1; then
    if confirm "Remove spaCy models?"; then
        log "Removing spaCy models..."
        python3 -m spacy validate 2>/dev/null | grep "^✓" | cut -d" " -f2 | xargs -I {} python3 -m spacy uninstall {} -y
    fi
fi

log """
✅ Uninstallation complete!

Removed items:
$([ "$REMOVE_ALL" = true ] && echo "- Complete conda installation")
$([ "$REMOVE_ALL" = false ] && echo "- ML environment (if existed)")
- Project structure (if confirmed)
- NLTK data (if existed)
- spaCy models (if existed)

Project directory location: $PROJECT_DIR

⚠️  Please restart your terminal for all changes to take effect
"""
