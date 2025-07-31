#!/bin/bash

# --- Terminal Capability Detection ---
# Enhanced color functions with comprehensive fallbacks and error handling
detect_terminal_capabilities() {
    local caps_log=""
    
    # Check if output is going to a terminal
    if [ ! -t 1 ]; then
        caps_log="Output not to terminal, disabling colors"
        echo "$caps_log" >&2
        return 1
    fi
    
    # Check TERM variable
    if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
        caps_log="TERM is unset or 'dumb', disabling colors"
        echo "$caps_log" >&2
        return 1
    fi
    
    # Check if tput is available and working
    if ! command -v tput >/dev/null 2>&1; then
        caps_log="tput command not available, falling back to basic colors"
        echo "$caps_log" >&2
        return 2
    fi
    
    # Test tput functionality
    if ! tput sgr0 >/dev/null 2>&1; then
        caps_log="tput not functioning properly, falling back to basic colors"
        echo "$caps_log" >&2
        return 2
    fi
    
    return 0
}

# --- Color Support Check ---
# Check 256-color support
supports_256_colors() {
    local color_count
    
    # First check terminal capability detection
    detect_terminal_capabilities
    local term_status=$?
    
    if [ $term_status -eq 1 ]; then
        return 1  # No color support
    elif [ $term_status -eq 2 ]; then
        return 2  # Basic color support only
    fi
    
    # Get color count with error handling
    if color_count=$(tput colors 2>/dev/null); then
        if [ "$color_count" -ge 256 ]; then
            return 0  # 256-color support
        else
            return 2  # Basic color support
        fi
    else
        # Fallback: check common terminal types
        case "$TERM" in
            *256color*|*256col*|xterm-color|screen-256*|tmux-256*)
                return 0  # Assume 256-color support
                ;;
            xterm*|screen*|tmux*|rxvt*)
                return 2  # Basic color support
                ;;
            *)
                return 1  # No color support
                ;;
        esac
    fi
}

# --- Color Function Initialization ---
# Initialize color functions based on terminal capabilities
init_color_functions() {
    supports_256_colors
    local color_support=$?
    
    case $color_support in
        0)  # 256-color support
            color256_fg() { 
                printf "\033[38;5;%dm" "$1" 2>/dev/null || printf ""
            }
            color256_bg() { 
                printf "\033[48;5;%dm" "$1" 2>/dev/null || printf ""
            }
            ;;
        2)  # Basic 16-color support
            color256_fg() {
                local color_code=""
                case $1 in
                    # Red shades
                    196|160|124|88|52) color_code="31" ;;
                    # Orange/Yellow shades  
                    202|208|214|220|226|228) color_code="33" ;;
                    # Green shades
                    46|82|118|154|190|40|34|28) color_code="32" ;;
                    # Blue shades
                    21|27|33|39|45|51|57|63|69|75|81|87|93|99|105) color_code="34" ;;
                    # Purple/Magenta shades
                    90|91|92|93|129|135|141|147|171|177|183|189|201|207|213|219) color_code="35" ;;
                    # Cyan shades
                    14|23|30|37|44|51|80|87|116|123|158|159) color_code="36" ;;
                    # White/Gray shades
                    15|255|254|253|252|251|250|249|248|247|246|245|244|243|242|241|240|239|238|237|236|235|234|233|232) color_code="37" ;;
                    # Black shades
                    0|16|232|233|234|235|236|237|238|239|240|241|242|243|244|245|246|247|248|249|250|251|252|253|254) color_code="30" ;;
                    # Default to white for unknown codes
                    *) color_code="37" ;;
                esac
                printf "\033[%sm" "$color_code" 2>/dev/null || printf ""
            }
            color256_bg() {
                local color_code=""
                case $1 in
                    196|160|124|88|52) color_code="41" ;;  # red bg
                    202|208|214|220|226|228) color_code="43" ;;  # yellow bg
                    46|82|118|154|190|40|34|28) color_code="42" ;;  # green bg
                    21|27|33|39|45|51|57|63|69|75|81|87|93|99|105) color_code="44" ;;  # blue bg
                    90|91|92|93|129|135|141|147|171|177|183|189|201|207|213|219) color_code="45" ;;  # purple bg
                    14|23|30|37|44|51|80|87|116|123|158|159) color_code="46" ;;  # cyan bg
                    15|255|254|253|252|251|250|249|248|247|246|245|244|243|242|241|240|239|238|237|236|235|234|233|232) color_code="47" ;;  # white bg
                    *) color_code="40" ;;  # default black bg
                esac
                printf "\033[%sm" "$color_code" 2>/dev/null || printf ""
            }
            ;;
        *)
            color256_fg() { printf ""; }
            color256_bg() { printf ""; }
            ;;
    esac
}

# --- Core Color and Text Functions ---
# Safe color reset function
color_reset() {
    if command -v tput >/dev/null 2>&1 && tput sgr0 >/dev/null 2>&1; then
        tput sgr0 2>/dev/null || printf "\033[0m"
    else
        printf "\033[0m"
    fi
}

# Convenience functions for common colors
color_red() { color256_fg 196; }
color_green() { color256_fg 46; }
color_yellow() { color256_fg 226; }
color_blue() { color256_fg 21; }
color_purple() { color256_fg 93; }
color_cyan() { color256_fg 51; }
color_white() { color256_fg 255; }

# Text formatting functions with fallbacks
text_bold() {
    if command -v tput >/dev/null 2>&1 && tput bold >/dev/null 2>&1; then
        tput bold 2>/dev/null || printf "\033[1m"
    else
        printf "\033[1m"
    fi
}

text_dim() {
    if command -v tput >/dev/null 2>&1 && tput dim >/dev/null 2>&1; then
        tput dim 2>/dev/null || printf "\033[2m"
    else
        printf "\033[2m"
    fi
}

text_underline() {
    if command -v tput >/dev/null 2>&1 && tput smul >/dev/null 2>&1; then
        tput smul 2>/dev/null || printf "\033[4m"
    else
        printf "\033[4m"
    fi
}

# --- Initialization and Export ---
# Initialize color support only if output is to a terminal
if [ -t 1 ]; then
    init_color_functions
else
    # Define dummy functions if not a terminal to prevent errors
    color256_fg() { printf ""; }
    color256_bg() { printf ""; }
    color_reset() { printf ""; }
    color_red() { printf ""; }
    color_green() { printf ""; }
    color_yellow() { printf ""; }
    color_blue() { printf ""; }
    color_purple() { printf ""; }
    color_cyan() { printf ""; }
    color_white() { printf ""; }
    text_bold() { printf ""; }
    text_dim() { printf ""; }
    text_underline() { printf ""; }
    NC=""
fi

# Define NC (No Color) for easy reset
NC=$(color_reset)

# Export functions for use in other scripts
export -f color256_fg color256_bg color_reset
export -f color_red color_green color_yellow color_blue color_purple color_cyan color_white
export -f text_bold text_dim text_underline

# --- Self-Test Function ---
# Test function to verify color support
test_colors() {
    echo "Testing color support..."
    supports_256_colors
    local support_level=$?
    
    case $support_level in
        0) echo "256-color support detected" ;;
        2) echo "Basic 16-color support detected" ;;
        1) echo "No color support detected" ;;
    esac
    
    echo "Color test:"
    printf "%sRed%s " "$(color_red)" "$NC"
    printf "%sGreen%s " "$(color_green)" "$NC"
    printf "%sYellow%s " "$(color_yellow)" "$NC"
    printf "%sBlue%s " "$(color_blue)" "$NC"
    printf "%sPurple%s " "$(color_purple)" "$NC"
    printf "%sCyan%s " "$(color_cyan)" "$NC"
    printf "%sWhite%s\n" "$(color_white)" "$NC"
    
    printf "%sBold%s " "$(text_bold)" "$NC"
    printf "%sDim%s " "$(text_dim)" "$NC"
    printf "%sUnderline%s\n" "$(text_underline)" "$NC"
}

# --- Direct Execution Hook ---
# If script is run directly, run color test
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    test_colors
fi
