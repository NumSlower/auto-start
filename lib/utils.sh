#!/bin/bash

# --- Logging Functions ---
log() { echo "[INFO] $1 at $(date)"; }
warn() { echo "[WARNING] $1 at $(date)"; }
fail() { echo "[ERROR] $1 at $(date)"; }
ok() { echo "[SUCCESS] $1 at $(date)"; }
