#!/bin/bash

# Source the main configuration file
source "$(dirname "$0")/../conf/auto-start.conf"
source "$(dirname "$0")/utils.sh"

# --- Configuration and Setup ---
VENV_DIR="${VENV_DIR:-$VENV_DIR_DEFAULT}"
FALLBACK_VENV_DIR="${FALLBACK_VENV_DIR:-$FALLBACK_VENV_DIR_DEFAULT}"
PYTHON_BIN="${PYTHON_BIN:-$PYTHON_BIN_DEFAULT}"
REQUIRED_PKGS=("${REQUIRED_PYTHON_PKGS[@]}")

# --- Logging and Error Handling ---


# Error handling with cleanup
cleanup_on_error() {
    local error_msg="$1"
    fail "$error_msg"
    fail "Python setup failed - check logs for details"
    exit 1
}

# --- Python and Virtual Environment Functions ---
# Find Python executable with fallbacks
find_python() {
    local python_candidates=("python3" "python3.11" "python3.10" "python3.9" "python")
    
    for candidate in "${python_candidates[@]}"; do
        if command -v "$candidate" &>/dev/null; then
            log "Found Python executable: $candidate" >&2
            echo "$candidate"
            return 0
        fi
    done
    
    return 1
}



# Test virtual environment functionality
test_venv() {
    local python_bin="$1"
    local test_dir="/tmp/venv_test_$"
    
    log "Testing virtual environment creation with $python_bin" >&2
    
    if "$python_bin" -m venv "$test_dir" &>/dev/null; then
        rm -rf "$test_dir" &>/dev/null
        return 0
    else
        warn "venv test failed with $python_bin" >&2
        rm -rf "$test_dir" &>/dev/null
        return 1
    fi
}

# --- Main Execution Block ---
{
    log "Starting Python environment setup"
    
    # --- Python Executable Discovery ---
    log "Searching for Python executable"
    PYTHON_BIN=$(find_python)
    if [ $? -ne 0 ] || [ -z "$PYTHON_BIN" ]; then
        cleanup_on_error "No suitable Python executable found"
    fi
    ok "Using Python executable: $PYTHON_BIN"

    # --- Virtual Environment Setup ---
    log "Testing venv module support"
    if ! test_venv "$PYTHON_BIN"; then
        cleanup_on_error "Python venv module not supported or not working"
    fi
    ok "Virtual environment support confirmed"

    # Determine venv directory (with fallback)
    if [ -d "$VENV_DIR" ]; then
        ACTIVE_VENV_DIR="$VENV_DIR"
        log "Using existing virtual environment at $VENV_DIR"
    elif [ -d "$FALLBACK_VENV_DIR" ]; then
        ACTIVE_VENV_DIR="$FALLBACK_VENV_DIR"
        log "Using existing virtual environment at $FALLBACK_VENV_DIR"
    else
        ACTIVE_VENV_DIR="$VENV_DIR"
        log "Creating new virtual environment at $ACTIVE_VENV_DIR"
        
        if ! "$PYTHON_BIN" -m venv "$ACTIVE_VENV_DIR"; then
            warn "Failed to create venv at $ACTIVE_VENV_DIR, trying fallback location"
            ACTIVE_VENV_DIR="$FALLBACK_VENV_DIR"
            
            if ! "$PYTHON_BIN" -m venv "$ACTIVE_VENV_DIR"; then
                cleanup_on_error "Failed to create virtual environment at both locations"
            fi
        fi
        ok "Created virtual environment at $ACTIVE_VENV_DIR"
    fi

    # Verify venv structure
    if [ ! -f "$ACTIVE_VENV_DIR/bin/python" ] || [ ! -f "$ACTIVE_VENV_DIR/bin/pip" ]; then
        warn "Virtual environment appears corrupted, recreating"
        rm -rf "$ACTIVE_VENV_DIR"
        
        if ! "$PYTHON_BIN" -m venv "$ACTIVE_VENV_DIR"; then
            cleanup_on_error "Failed to recreate virtual environment"
        fi
        ok "Recreated virtual environment"
    fi

    # --- Package Management ---
    # Upgrade pip with retries
    log "Upgrading pip"
    for attempt in 1 2 3; do
        if "$ACTIVE_VENV_DIR/bin/pip" install --upgrade pip --quiet --disable-pip-version-check; then
            ok "Pip upgraded successfully"
            break
        else
            warn "Pip upgrade attempt $attempt failed"
            if [ $attempt -eq 3 ]; then
                cleanup_on_error "Failed to upgrade pip after 3 attempts"
            fi
            sleep 2
        fi
    done

    # Install or verify uv
    log "Checking for uv package manager"
    if ! "$ACTIVE_VENV_DIR/bin/pip" show uv &>/dev/null; then
        log "Installing uv package manager"
        for attempt in 1 2 3; do
            if "$ACTIVE_VENV_DIR/bin/pip" install uv --quiet --disable-pip-version-check; then
                ok "Installed uv successfully"
                break
            else
                warn "uv installation attempt $attempt failed"
                if [ $attempt -eq 3 ]; then
                    warn "Failed to install uv, will use pip as fallback"
                    break
                fi
                sleep 2
            fi
        done
    else
        ok "uv package manager already installed"
    fi

    # Choose installer (uv preferred, pip fallback)
    if command -v "$ACTIVE_VENV_DIR/bin/uv" &>/dev/null; then
        INSTALLER="$ACTIVE_VENV_DIR/bin/uv"
        INSTALL_CMD="pip install"
        log "Using uv as package installer"
    else
        INSTALLER="$ACTIVE_VENV_DIR/bin/pip"
        INSTALL_CMD="install --quiet --disable-pip-version-check"
        log "Using pip as package installer"
    fi

    # Check for missing packages in parallel
    missing=()
    log "Checking required packages: ${REQUIRED_PKGS[*]}"
    pids=()
    for pkg in "${REQUIRED_PKGS[@]}"; do
        ( 
            if ! "$ACTIVE_VENV_DIR/bin/pip" show "$pkg" &>/dev/null; then
                echo "$pkg"
            fi
        ) > "/tmp/pkg_check_$ &"
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid"
        if [ -s "/tmp/pkg_check_$pid" ]; then
            missing+=("$(cat "/tmp/pkg_check_$pid")")
        fi
        rm "/tmp/pkg_check_$pid"
    done

    # Install missing packages
    if [ ${#missing[@]} -gt 0 ]; then
        log "Installing missing packages: ${missing[*]}"
        for attempt in 1 2 3; do
            if $INSTALLER $INSTALL_CMD "${missing[@]}"; then
                ok "Successfully installed missing packages: ${missing[*]}"
                break
            else
                warn "Package installation attempt $attempt failed"
                if [ $attempt -eq 3 ]; then
                    cleanup_on_error "Failed to install packages after 3 attempts: ${missing[*]}"
                fi
                sleep 2
            fi
        done
    else
        ok "All required packages are installed"
    fi

    # --- Final Verification and Logging ---
    log "Performing final verification"
    failed_packages=()
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! "$ACTIVE_VENV_DIR/bin/pip" show "$pkg" &>/dev/null; then
            failed_packages+=("$pkg")
        fi
    done

    if [ ${#failed_packages[@]} -gt 0 ]; then
        cleanup_on_error "Final verification failed for packages: ${failed_packages[*]}"
    fi

    ok "Python environment setup completed successfully"
    log "Virtual environment location: $ACTIVE_VENV_DIR"
    log "Python version: $($ACTIVE_VENV_DIR/bin/python --version)"
    log "Pip version: $($ACTIVE_VENV_DIR/bin/pip --version)"
    
    # Log installed packages for reference
    log "Installed packages:"
    "$ACTIVE_VENV_DIR/bin/pip" list --format=columns 2>/dev/null | while read -r line; do
        log "  $line"
    done

} 2>&1
