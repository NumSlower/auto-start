#!/bin/bash

source "$(dirname "$0")/../conf/auto-start.conf"
source "$(dirname "$0")/utils.sh"

# --- Configuration and Setup ---

# Determine REQUIRED_PKGS: prioritize environment variable for testing, else use default from config
if [ -n "$REQUIRED_SYSTEM_PKGS" ]; then
    # Read the space-separated string into an array
    read -r -a REQUIRED_PKGS <<< "$REQUIRED_SYSTEM_PKGS"
    TEST_MODE=true
else
    # Source the main configuration file to get default REQUIRED_SYSTEM_PKGS_DEFAULT and PACKAGE_ALTERNATIVES
    REQUIRED_PKGS=("${REQUIRED_SYSTEM_PKGS_DEFAULT[@]}")
    TEST_MODE=false
fi

# PACKAGE_ALTERNATIVES is sourced from auto-start.conf above

# --- DEBUGGING ---
log "DEBUG: REQUIRED_SYSTEM_PKGS (env): ${REQUIRED_SYSTEM_PKGS[*]}"
log "DEBUG: REQUIRED_SYSTEM_PKGS_DEFAULT (from conf): ${REQUIRED_SYSTEM_PKGS_DEFAULT[*]}"
log "DEBUG: REQUIRED_PKGS (final): ${REQUIRED_PKGS[*]}"
log "DEBUG: TEST_MODE: $TEST_MODE"
# --- END DEBUGGING ---

# --- Logging and Error Handling ---


# Error handling
cleanup_on_error() {
    local error_msg="$1"
    fail "$error_msg"
    fail "System setup failed - check logs for details"
    exit 1
}

# --- System and Package Manager Functions ---
# Detect package manager with comprehensive fallbacks
detect_package_manager() {
    local managers=("apt:debian" "dnf:fedora" "yum:rhel" "pacman:arch" "zypper:opensuse" "apk:alpine")
    
    for manager_info in "${managers[@]}"; do
        local manager="${manager_info%%:*}"
        local distro="${manager_info##*:}"
        
        if command -v "$manager" &>/dev/null; then
            log "Detected package manager: $manager ($distro-based)"
            echo "$manager"
            return 0
        fi
    done
    
    return 1
}

# Check if running with sufficient privileges
check_privileges() {
    local manager="$1"
    
    # Test if we can run the package manager with sudo
    case "$manager" in
        apt|dnf|yum|zypper)
            if ! sudo -n true 2>/dev/null; then
                log "Checking sudo access for $manager"
                if ! sudo true; then
                    return 1
                fi
            fi
            ;;
        pacman)
            if ! sudo -n true 2>/dev/null; then
                log "Checking sudo access for pacman"
                if ! sudo true; then
                    return 1
                fi
            fi
            ;;
        apk)
            if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
                if ! sudo true; then
                    return 1
                fi
            fi
            ;;
    esac
    return 0
}

# Get package alternatives for specific package managers
get_package_alternatives() {
    local pkg="$1"
    local manager="$2"
    
    for alt_info in "${PACKAGE_ALTERNATIVES[@]}"; do
        if [[ "$alt_info" == "$pkg:"* ]]; then
            local alternatives="${alt_info#*:}"
            case "$manager" in
                apt) echo "${alternatives%%,*}" ;;
                dnf|yum) echo "$(echo "$alternatives" | cut -d',' -f2)" ;;
                pacman) echo "$(echo "$alternatives" | cut -d',' -f3)" ;;
                *) echo "$pkg" ;;
            esac
            return 0
        fi
    done
    echo "$pkg"
}

# Update package lists
update_package_lists() {
    local manager="$1"
    
    log "Updating package lists for $manager"
    
    case "$manager" in
        apt)
            if sudo apt update; then
                ok "Package lists updated successfully"
                return 0
            else
                warn "Failed to update apt package lists"
                return 1
            fi
            ;;
        dnf)
            if sudo dnf check-update; then
                ok "Package lists updated successfully"
                return 0
            else
                # dnf check-update returns 100 when updates are available, which is normal
                if [ $? -eq 100 ]; then
                    ok "Package lists updated successfully (updates available)"
                    return 0
                else
                    warn "Failed to update dnf package lists"
                    return 1
                fi
            fi
            ;;
        yum)
            if sudo yum check-update; then
                ok "Package lists updated successfully"
                return 0
            else
                if [ $? -eq 100 ]; then
                    ok "Package lists updated successfully (updates available)"
                    return 0
                else
                    warn "Failed to update yum package lists"
                    return 1
                fi
            fi
            ;;
        pacman)
            if sudo pacman -Sy; then
                ok "Package lists updated successfully"
                return 0
            else
                warn "Failed to update pacman package lists"
                return 1
            fi
            ;;
        zypper)
            if sudo zypper refresh; then
                ok "Package lists updated successfully"
                return 0
            else
                warn "Failed to update zypper package lists"
                return 1
            fi
            ;;
        apk)
            if sudo apk update; then
                ok "Package lists updated successfully"
                return 0
            else
                warn "Failed to update apk package lists"
                return 1
            fi
            ;;
    esac
    
    return 1
}

# Install packages with retries
install_packages() {
    local manager="$1"
    shift
    local packages=("$@")
    
    log "Installing packages with $manager: ${packages[*]}"
    
    for attempt in 1 2 3; do
        log "Installation attempt $attempt"
        
        case "$manager" in
            apt)
                if sudo apt -o Acquire::Queue-Mode=host -o Acquire::Parallel=THREADS install -y "${packages[@]}"; then
                    ok "Packages installed successfully"
                    return 0
                fi
                ;;
            dnf)
                if sudo dnf install -y --max-parallel-downloads=$THREADS "${packages[@]}"; then
                    ok "Packages installed successfully"
                    return 0
                fi
                ;;
            yum)
                if sudo yum install -y "${packages[@]}"; then
                    ok "Packages installed successfully"
                    return 0
                fi
                ;;
            pacman)
                if sudo pacman -S --noconfirm "${packages[@]}"; then
                    ok "Packages installed successfully"
                    return 0
                fi
                ;;
            zypper)
                if sudo zypper install -y "${packages[@]}"; then
                    ok "Packages installed successfully"
                    return 0
                fi
                ;;
            apk)
                if sudo apk add "${packages[@]}"; then
                    ok "Packages installed successfully"
                    return 0
                fi
                ;;
        esac
        
        warn "Installation attempt $attempt failed"
        if [ $attempt -lt 3 ]; then
            log "Waiting before retry..."
            sleep 3
        fi
    done
    
    return 1
}

# --- Main Execution Block ---
{
    log "Starting system package setup"
    
    # Check what packages are missing
    missing=()
    log "Checking required packages: ${REQUIRED_PKGS[*]}"
    
    for pkg in "${REQUIRED_PKGS[@]}"; do
        # Check if the command exists and is executable
        pkg_path=$(command -v "$pkg")
        if [ -n "$pkg_path" ] && test -x "$pkg_path"; then
            log "Package $pkg is already installed"
        else
            missing+=("$pkg")
            log "Package $pkg is missing"
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        ok "All system packages are already installed"
        exit 0
    fi

    log "Missing packages: ${missing[*]}"

    # --- Package Manager and Privilege Check ---
    log "Detecting package manager"
    if ! MANAGER=$(detect_package_manager); then
        cleanup_on_error "No supported package manager found (tried: apt, dnf, yum, pacman, zypper, apk)"
    fi

    log "Checking system privileges"
    if ! check_privileges "$MANAGER"; then
        cleanup_on_error "Insufficient privileges to install packages with $MANAGER"
    fi
    ok "System privileges confirmed"

    # --- Package Installation ---
    if ! update_package_lists "$MANAGER"; then
        warn "Failed to update package lists, proceeding anyway"
    fi

    packages_to_install=()
    for pkg in "${missing[@]}"; do
        pkg_name=$(get_package_alternatives "$pkg" "$MANAGER")
        packages_to_install+=("$pkg_name")
        log "Mapping $pkg -> $pkg_name for $MANAGER"
    done

    if ! install_packages "$MANAGER" "${packages_to_install[@]}"; then
        cleanup_on_error "Failed to install packages: ${packages_to_install[*]}"
    fi

    # --- Final Verification and Logging ---
    log "Performing final verification"
    still_missing=()
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            still_missing+=("$pkg")
        fi
    done

    if [ ${#still_missing[@]} -gt 0 ]; then
        warn "Some packages may not be available or have different names: ${still_missing[*]}"
        log "You may need to install these manually or they might be provided by other packages"
    fi

    log "System information:"
    log "  OS: $(uname -s)"
    log "  Architecture: $(uname -m)"
    log "  Kernel: $(uname -r)"
    if command -v lsb_release &>/dev/null; then
        log "  Distribution: $(lsb_release -d -s 2>/dev/null || echo 'Unknown')"
    fi
    log "  Package manager: $MANAGER"

    ok "System package setup completed successfully"

} 2>&1
