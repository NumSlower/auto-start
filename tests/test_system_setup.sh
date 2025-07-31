#!/bin/bash

# Test script for system-setup.sh

# Define a temporary directory for testing
TEST_DIR="$(mktemp -d)"

# Function to clean up temporary directory
cleanup() {
    echo "Cleaning up temporary directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# Test 1: Detect apt and simulate package already installed
( 
    echo "Test 1: Detect apt and simulate package already installed"
    export REQUIRED_SYSTEM_PKGS="curl"

    # Mock functions directly in the subshell
    command() {
        if [ "$1" = "-v" ] && [ "$2" = "curl" ]; then
            echo "/usr/bin/curl"
            return 0
        fi
        /usr/bin/command "$@"
    }
    test() {
        if [ "$1" = "-x" ] && [ "$2" = "/usr/bin/curl" ]; then
            return 0
        fi
        /usr/bin/test "$@"
    }
    export -f command test

    bash lib/system-setup.sh
) > "$TEST_DIR/system_setup_test1.log" 2>&1

if grep -q "All system packages are already installed" "$TEST_DIR/system_setup_test1.log"; then
    echo "Test 1 (apt, package installed) passed."
else
    echo "Test 1 (apt, package installed) failed. Log:"
    cat "$TEST_DIR/system_setup_test1.log"
    exit 1
fi

# Test 2: Detect apt and simulate package missing (no actual install)
( 
    echo "Test 2: Detect apt and simulate package missing"
    export REQUIRED_SYSTEM_PKGS="curl"

    # Mock functions directly in the subshell
    command() {
        if [ "$1" = "-v" ] && [ "$2" = "curl" ]; then
            echo "/usr/bin/curl"
            return 0
        fi
        /usr/bin/command "$@"
    }
    test() {
        if [ "$1" = "-x" ] && [ "$2" = "/usr/bin/curl" ]; then
            return 1
        fi
        /usr/bin/test "$@"
    }
    export -f command test

    bash lib/system-setup.sh
) > "$TEST_DIR/system_setup_test2.log" 2>&1

if grep -q "Missing packages: curl" "$TEST_DIR/system_setup_test2.log"; then
    echo "Test 2 (apt, package missing) passed."
else
    echo "Test 2 (apt, package missing) failed. Log:"
    cat "$TEST_DIR/system_setup_test2.log"
    exit 1
fi

echo "System setup test complete. Check $TEST_DIR/system_setup_test*.log for details."
