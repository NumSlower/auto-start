# Auto-Start

This project provides a set of shell scripts to automate the setup of a development environment. It is designed to be run on a fresh system to install and configure everything needed to start working.

## Features

-   **System Package Installation:** Automatically installs required system packages using the appropriate package manager (`apt`, `yum`, `dnf`, `pacman`, `brew`).
-   **Python Virtual Environment:** Creates a Python virtual environment to isolate project dependencies.
-   **Python Package Installation:** Installs required Python packages from a `requirements.txt` file or a list in the configuration file.
-   **Colored Output:** Provides easy-to-read colored output for better user experience.
-   **Logging:** Logs all actions to a log file for debugging purposes.

## Usage

1.  **Configure:** Edit `conf/auto-start.conf` to specify the required system and Python packages.
2.  **Run:** Execute the main startup script:

    ```bash
    bash bin/startup-script.sh
    ```

## Configuration

The main configuration file is `conf/auto-start.conf`. The following variables can be configured:

-   `REQUIRED_SYSTEM_PKGS`: A space-separated list of system packages to install.
-   `PYTHON_BIN_DEFAULT`: The default Python binary to use if `python` is not in the `PATH`.
-   `VENV_DIR`: The primary directory for the Python virtual environment.
-   `FALLBACK_VENV_DIR`: The fallback directory for the Python virtual environment if the primary one cannot be created.
-   `REQUIRED_PYTHON_PKGS`: A space-separated list of Python packages to install.

## Scripts

-   `bin/startup-script.sh`: The main entry point of the project.
-   `lib/system-setup.sh`: Handles system package installation.
-   `lib/python-setup.sh`: Handles Python virtual environment and package installation.
-   `lib/color-functions.sh`: Provides functions for colored output.
-   `lib/utils.sh`: Provides utility functions.
-   `tests/`: Contains test scripts for the library functions.
