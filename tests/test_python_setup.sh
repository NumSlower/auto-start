#!/bin/bash

# Test script for python-setup.sh

# Source the main configuration file
source conf/auto-start.conf

# Define a temporary directory for testing
TEST_DIR="$(mktemp -d)"

# Override VENV_DIR and FALLBACK_VENV_DIR for testing
export VENV_DIR="$TEST_DIR/.venv_test"
export FALLBACK_VENV_DIR="$TEST_DIR/myvenv_test"

# Override PYTHON_BIN for testing (ensure it's a valid python executable)
export PYTHON_BIN_DEFAULT="python3"

# Override REQUIRED_PYTHON_PKGS for testing to speed up
export REQUIRED_PYTHON_PKGS=("pip")

# Function to clean up temporary directory
cleanup() {
    echo "Cleaning up temporary directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# Run python-setup.sh in a subshell to isolate environment changes
( 
    echo "Running python-setup.sh test..."
    bash lib/python-setup.sh
) > "$TEST_DIR/python_setup_test.log" 2>&1

# Check if the virtual environment was created
if [ -d "$VENV_DIR" ] || [ -d "$FALLBACK_VENV_DIR" ]; then
    echo "Python virtual environment created successfully."
else
    echo "Error: Python virtual environment not created."
    cat "$TEST_DIR/python_setup_test.log"
    exit 1
fi

# Check if pip is installed in the venv
if [ -f "$VENV_DIR/bin/pip" ] || [ -f "$FALLBACK_VENV_DIR/bin/pip" ]; then
    echo "Pip found in virtual environment."
else
    echo "Error: Pip not found in virtual environment."
    cat "$TEST_DIR/python_setup_test.log"
    exit 1
fi

# Check if the required package (pip) is installed
if ( "$VENV_DIR/bin/pip" show pip &>/dev/null ) || ( "$FALLBACK_VENV_DIR/bin/pip" show pip &>/dev/null ); then
    echo "Required package 'pip' installed successfully."
else
    echo "Error: Required package 'pip' not installed."
    cat "$TEST_DIR/python_setup_test.log"
    exit 1
fi

echo "Python setup test complete. Check $TEST_DIR/python_setup_test.log for details."
