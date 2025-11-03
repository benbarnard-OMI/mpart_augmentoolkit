#!/bin/bash
# Entrypoint script for Augmentoolkit container

set -e

echo "=========================================="
echo "Augmentoolkit Container for UIUC ICC"
echo "=========================================="

# Start Redis server in background if not already running
if ! pgrep -x "redis-server" > /dev/null; then
    echo "Starting Redis server..."
    redis-server --daemonize yes
    sleep 2
fi

# Check if Redis is running
if redis-cli ping > /dev/null 2>&1; then
    echo "Redis server is running"
else
    echo "Warning: Redis server may not be running properly"
fi

# Set default configuration if not provided
CONFIG_FILE="${CONFIG_FILE:-/augmentoolkit/container_config.yaml}"

# Handle different run modes
if [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
    # Interactive shell mode
    echo "Starting interactive shell..."
    exec "$@"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    # Help mode
    echo "Usage: docker run [OPTIONS] augmentoolkit [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  --config FILE    Run augmentoolkit with specified config file"
    echo "  --node NODE      Run specific pipeline node"
    echo "  --help           Show this help message"
    echo "  bash/sh          Start interactive shell"
    echo ""
    echo "Environment Variables:"
    echo "  CONFIG_FILE      Path to configuration file (default: /augmentoolkit/container_config.yaml)"
    echo "  INPUT_DIR        Path to input directory (default: /data/inputs)"
    echo "  OUTPUT_DIR       Path to output directory (default: /data/outputs)"
    echo "  API_KEY          API key for LLM provider"
    echo "  BASE_URL         Base URL for LLM API"
    echo ""
    echo "Volume Mounts (recommended):"
    echo "  /data/inputs     Mount directory containing input documents"
    echo "  /data/outputs    Mount directory for output datasets"
    echo "  /data/configs    Mount directory for custom configurations"
    echo "  /data/models     Mount directory for model cache"
    echo "  /data/cache      Mount directory for general cache"
    exit 0
elif [ "$1" = "--config" ]; then
    # Config file mode
    CONFIG_FILE="$2"
    echo "Using configuration file: $CONFIG_FILE"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Copy config to super_config.yaml if needed
    if [ "$CONFIG_FILE" != "/augmentoolkit/super_config.yaml" ]; then
        echo "Copying configuration to super_config.yaml..."
        cp "$CONFIG_FILE" /augmentoolkit/super_config.yaml
    fi
    
    echo "Starting Augmentoolkit..."
    cd /augmentoolkit
    python run_augmentoolkit.py
elif [ "$1" = "--node" ]; then
    # Node-specific mode
    shift
    echo "Running specific pipeline node: $@"
    cd /augmentoolkit
    python run_augmentoolkit.py "$@"
else
    # Default: run augmentoolkit with default config
    echo "Using default configuration: $CONFIG_FILE"
    
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" /augmentoolkit/super_config.yaml
        echo "Starting Augmentoolkit with default configuration..."
        cd /augmentoolkit
        python run_augmentoolkit.py
    else
        echo "Error: Default configuration file not found: $CONFIG_FILE"
        echo "Run with --help for usage information"
        exit 1
    fi
fi
