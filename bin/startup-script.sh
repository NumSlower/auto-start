#!/bin/bash

# --- Timer ---
start_time=$(date +%s)

# --- Initialization ---
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the main configuration file
source "$DIR/../conf/auto-start.conf"

# Set paths using variables from auto-start.conf
LOG_FILE="$DIR/../logs/$LOG_FILE_NAME"
STARTUP_SCRIPT_PATH="$DIR/startup-script.sh"
VENV_ACTIVATE_PATH="$FALLBACK_VENV_DIR_DEFAULT/bin/activate" # Using FALLBACK_VENV_DIR_DEFAULT as it's the one used for activation in the original script

source "$DIR/../lib/color-functions.sh"
source "$DIR/../lib/utils.sh"

# --- Color Definitions ---


# --- Pre-execution Setup ---
# Clear log file before run
: > "$LOG_FILE"

# --- Error Handling ---
handle_error() {
    local phase="$1"
    echo -e "$(color_red)[FAILED] $phase phase failed${NC}" >&2
    echo "[ERROR] $phase phase failed at $(date)" >> "$LOG_FILE"
    echo "[ERROR] Check $LOG_FILE for details" >> "$LOG_FILE"
    exit 1
}

# --- Test Execution ---
run_tests() {
    local test_log_prefix="[$(date '+%a %b %d %I:%M:%S %p %Z %Y')]"
    echo "$test_log_prefix [INFO] Testing Files" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    echo "$test_log_prefix [INFO] [PHASE 1] Verifying Test File Presence" >> "$LOG_FILE"

    local files_to_check=(
        "bin"
        "bin/startup-script.sh"
        "conf"
        "conf/auto-start.conf"
        "lib"
        "lib/color-functions.sh"
        "lib/python-setup.sh"
        "lib/system-setup.sh"
        "tests"
        "tests/test_color_functions.sh"
        "tests/test_python_setup.sh"
        "tests/test_system_setup.sh"
    )

    local all_files_found=true
    for file_path in "${files_to_check[@]}"; do
        if [ -e "$file_path" ]; then
            echo "$test_log_prefix [OK] Found: $file_path" >> "$LOG_FILE"
        else
            echo "$test_log_prefix [ERROR] Missing: $file_path" >> "$LOG_FILE"
            all_files_found=false
        fi
    done

    if ! $all_files_found; then
        echo "$test_log_prefix [ERROR] Some required files are missing. Aborting tests." >> "$LOG_FILE"
        return 1
    fi

    echo "" >> "$LOG_FILE"
    echo "$test_log_prefix [INFO] [PHASE 2] Executing Test Scripts" >> "$LOG_FILE"

    local test_scripts=(
        "tests/test_color_functions.sh"
        "tests/test_python_setup.sh"
        "tests/test_system_setup.sh"
    )

    local pids=()
    local failed_tests=()

    for script in "${test_scripts[@]}"; do
        ( 
            echo "$test_log_prefix [INFO] Running: $script" >> "$LOG_FILE"
            if bash "$script" >> "$LOG_FILE" 2>&1; then
                echo "$test_log_prefix [OK] Testing: $script" >> "$LOG_FILE"
            else
                echo "$test_log_prefix [ERROR] Testing: $script FAILED" >> "$LOG_FILE"
                # Record failed test
                echo "$script" > "$DIR/../logs/$(basename $script).failure"
            fi
        ) &
        pids+=($!)

        # Limit parallel processes
        # Wait for all processes to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    done

    # Wait for remaining processes
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    # Check for any failed tests
    for script in "${test_scripts[@]}"; do
        if [ -f "$DIR/../logs/$(basename $script).failure" ]; then
            failed_tests+=("$script")
            rm "$DIR/../logs/$(basename $script).failure"
        fi
    done

    if [ ${#failed_tests[@]} -eq 0 ]; then
        all_tests_passed=true
    else
        all_tests_passed=false
        echo "$test_log_prefix [ERROR] Failed tests: ${failed_tests[*]}" >> "$LOG_FILE"
    fi

    echo "" >> "$LOG_FILE"
    echo "$test_log_prefix [INFO] [PHASE 3] Checking Test Logs for Status" >> "$LOG_FILE"
    echo "$test_log_prefix [OK] Checking for: INFO, OK, SUCCESS, ERROR" >> "$LOG_FILE"

    if $all_tests_passed; then
        echo "$test_log_prefix [SUCCESS] Testing Files Completed" >> "$LOG_FILE"
        return 0
    else
        echo "$test_log_prefix [ERROR] Testing Files Failed" >> "$LOG_FILE"
        return 1
    fi
}

# --- Main Execution Flow ---
echo -e "$(color_yellow)▶ Running Script${NC}"

if run_tests; then
    echo -e "$(color_green)[OK] Testing files complected${NC}"
else
    handle_error "Testing Files"
fi

# --- Parallel Setup ---
( 
    echo "[INFO] Starting Python setup..." >> "$LOG_FILE"
    if PYTHON_OUTPUT=$(bash "$DIR/../lib/python-setup.sh" 2>&1); then
        echo "$PYTHON_OUTPUT" >> "$LOG_FILE"
        PYTHON_VERSION=$(echo "$PYTHON_OUTPUT" | grep "Python version:" | head -n 1 | awk '{print $5}')
        echo -e "$(color_green)[OK] Python $PYTHON_VERSION phase complected${NC}"
        echo "[SUCCESS] Python phase completed successfully at $(date)" >> "$LOG_FILE"
    else
        echo "$PYTHON_OUTPUT" >> "$LOG_FILE"
        handle_error "Python"
    fi
) & pid_python=$!

( 
    echo "[INFO] Starting system setup..." >> "$LOG_FILE"
    if bash "$DIR/../lib/system-setup.sh" >> "$LOG_FILE" 2>&1; then
        echo -e "$(color_green)[OK] System setup phase complected${NC}"
        echo "[SUCCESS] System phase completed successfully at $(date)" >> "$LOG_FILE"
    else
        handle_error "System"
    fi
) & pid_system=$!

wait $pid_python
wait $pid_system

echo -e "$(color_green)[OK] Checkin/adding log and bashrc complected${NC}"

# --- Shell Configuration ---
add_to_shellrc() {
    local shellrc="$1"
    local logfile="$2"
    local startup_path="$3"
    local venv_activate_path="$4"

    echo "[INFO] Processing shell config: $shellrc" >> "$logfile"

    if [ ! -f "$shellrc" ]; then
        echo "[INFO] Skipping missing $shellrc" >> "$logfile"
        return 0
    fi

    # Add startup script call
    if ! grep -Fq "$startup_path" "$shellrc" 2>/dev/null; then
        if {
            echo ""
            echo "# Added by auto-start script on $(date)"
            echo "bash \"$startup_path\"  # auto-start script"
        } >> "$shellrc" 2>>"$logfile"; then
            echo "[SUCCESS] Added startup script call to $shellrc" >> "$logfile"
        else
            echo "[ERROR] Failed to add startup script to $shellrc" >> "$logfile"
            return 1
        fi
    else
        echo "[INFO] Startup script call already in $shellrc" >> "$logfile"
    fi

    # Add venv activation
    if ! grep -Fq "source $venv_activate_path" "$shellrc" 2>/dev/null; then
        if echo "source $venv_activate_path  # auto activate venv" >> "$shellrc" 2>>"$logfile"; then
            echo "[SUCCESS] Added venv activation to $shellrc" >> "$logfile"
        else
            echo "[ERROR] Failed to add venv activation to $shellrc" >> "$logfile"
            return 1
        fi
    else
        echo "[INFO] Venv activation already in $shellrc" >> "$logfile"
    fi

    return 0
}

# Process shell configs
echo "[INFO] Adding to shell configurations at $(date)" >> "$LOG_FILE"
add_to_shellrc "$HOME/.bashrc" "$LOG_FILE" "$STARTUP_SCRIPT_PATH" "$VENV_ACTIVATE_PATH" || echo "[WARNING] Issues with .bashrc configuration" >> "$LOG_FILE"
add_to_shellrc "$HOME/.zshrc" "$LOG_FILE" "$STARTUP_SCRIPT_PATH" "$VENV_ACTIVATE_PATH" || echo "[WARNING] Issues with .zshrc configuration" >> "$LOG_FILE"

echo -e "$(color_green)Script complected${NC}"

# --- Finalization ---
end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo "[SUCCESS] Startup script completed successfully at $(date)" >> "$LOG_FILE"
echo "[INFO] Total execution time: ${execution_time} seconds" >> "$LOG_FILE"

echo -e "$(color_blue)Total execution time: ${execution_time} seconds${NC}"

exit 0
