#!/usr/bin/env bash

# Add logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Ask for confirmation
confirm() {
    read -r -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Show help message
show_help() {
    echo """
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help      Show this help message
    -f, --force     Skip confirmation prompts
    
Examples:
    $(basename "$0")          # Interactive uninstall
    $(basename "$0") -f       # Force uninstall
    $(basename "$0") --help   # Show this help message
"""
    exit 0
}

# Parse command line arguments
FORCE=false

while [[ "$1" =~ ^- ]]; do
    case $1 in
        -h | --help ) show_help ;;
        -f | --force ) FORCE=true; shift ;;
        * ) echo "Unknown option: $1"; show_help ;;
    esac
done

log "🗑️  Starting uninstallation process..."

if ! $FORCE; then
    if ! confirm "⚠️  This will remove the ML environment, Miniforge, and clean up shell configurations. Continue?"; then
        log "Uninstallation cancelled."
        exit 0
    fi
fi

# Remove Conda environment if it exists
if conda env list | grep -q "^ml_env "; then
    log "Removing ML environment..."
    conda deactivate 2>/dev/null || true
    conda env remove -n ml_env -y
fi

# Clean up shell configuration files
log "Cleaning up shell configuration files..."

# Function to safely remove conda initialization block
cleanup_shell_config() {
    local file="$1"
    if [ -f "$file" ]; then
        log "Cleaning up $file..."
        # Create backup with timestamp
        cp "$file" "${file}.bak.$(date +%Y%m%d_%H%M%S)"
        
        # If original backup exists from before conda installation, restore it
        if [ -f "${file}.pre_conda.bak" ]; then
            log "Restoring pre-conda backup of $file"
            cp "${file}.pre_conda.bak" "$file"
        else
            # Remove conda initialization block
            sed -i.tmp '/# >>> conda initialize/,/# <<< conda initialize/d' "$file"
            rm -f "${file}.tmp"
            
            # Remove empty lines at end of file
            sed -i.tmp -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$file"
            rm -f "${file}.tmp"
            
            # If file is empty after cleanup, create minimal default configuration
            if [ ! -s "$file" ]; then
                case "$(basename "$file")" in
                    .bash_profile)
                        echo '# .bash_profile
export PATH="/usr/local/bin:$PATH"
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi' > "$file"
                        ;;
                    .zshrc)
                        echo '# .zshrc
export PATH="/usr/local/bin:$PATH"' > "$file"
                        ;;
                esac
            fi
        fi
    fi
}

# Clean up common shell config files
cleanup_shell_config "$HOME/.bash_profile"
cleanup_shell_config "$HOME/.bashrc"
cleanup_shell_config "$HOME/.zshrc"
cleanup_shell_config "$HOME/.profile"

# Remove Miniforge installation
if [ -d "$HOME/miniforge3" ]; then
    log "Removing Miniforge installation..."
    rm -rf "$HOME/miniforge3"
fi

# Clean up conda cache
rm -rf "$HOME/.conda"

log """
✅ Uninstallation complete!

The following actions were performed:
1. Removed ML environment
2. Cleaned up shell configuration files (backups created with .bak extension)
3. Removed Miniforge installation
4. Cleaned up conda cache

Please restart your terminal for all changes to take effect.
"""
