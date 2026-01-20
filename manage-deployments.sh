#!/bin/bash
#
# Manage MLX model deployments
#
# Usage:
#   ./manage-deployments.sh <command> [deployment-name]
#
# Commands:
#   list                      List all deployments
#   install <name> [--start]  Install a deployment as a service
#   uninstall <name>          Uninstall a deployment service
#   start <name>              Start a deployment service
#   stop <name>               Stop a deployment service
#   restart <name>            Restart a deployment service
#   status <name>             Show status of a deployment
#   logs <name> [lines]       Show logs for a deployment
#   watch <name>              Watch download/startup progress in real-time
#   install-all               Install all deployments
#   uninstall-all             Uninstall all deployments
#   start-all                 Start all deployments
#   stop-all                  Stop all deployments
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$SCRIPT_DIR/deploy"

show_help() {
    cat << EOF
Manage MLX model deployments

Usage: $0 <command> [deployment-name]

Commands:
  list                      List all deployments
  install <name> [--start]  Install a deployment as a service
  uninstall <name>          Uninstall a deployment service
  start <name>              Start a deployment service
  stop <name>               Stop a deployment service
  restart <name>            Restart a deployment service
  status <name>             Show status of a deployment
  logs <name> [lines]       Show logs for a deployment (default: 50 lines)
  watch <name>              Watch download/startup progress in real-time
  install-all               Install all deployments
  uninstall-all             Uninstall all deployments
  start-all                 Start all deployments
  stop-all                  Stop all deployments

Examples:
  $0 list
  $0 install example-model
  $0 install example-model --start
  $0 start example-model
  $0 logs example-model 100
  $0 watch example-model
EOF
}

list_deployments() {
    echo "Available deployments:"
    echo ""
    if [ ! -d "$DEPLOY_DIR" ]; then
        echo "  No deployments found (deploy directory not found)"
        return
    fi

    for dir in "$DEPLOY_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/config.json" ]; then
            name=$(python3 -c "import json; c=json.load(open('$dir/config.json')); print(c.get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            display_name=$(python3 -c "import json; c=json.load(open('$dir/config.json')); print(c.get('display_name', name))" 2>/dev/null || echo "unknown")
            port=$(python3 -c "import json; c=json.load(open('$dir/config.json')); print(c.get('port', '?'))" 2>/dev/null || echo "?")

            service_name="com.local.mlx-$name"
            running=$(launchctl list 2>/dev/null | grep "$service_name" || echo "")

            status="[not installed]"
            if [ -n "$running" ]; then
                status="[running]"
            elif [ -f "$HOME/Library/LaunchAgents/$service_name.plist" ]; then
                status="[installed]"
            fi

            printf "  %-20s %-30s %-5s %s\n" "$name" "$display_name" ":$port" "$status"
        fi
    done
    echo ""
}

get_deployment_path() {
    local name="$1"
    local deploy_path="$DEPLOY_DIR/$name"

    if [ ! -d "$deploy_path" ]; then
        echo ""
        return 1
    fi

    if [ ! -f "$deploy_path/config.json" ]; then
        echo ""
        return 1
    fi

    echo "$deploy_path"
}

get_service_name() {
    local name="$1"
    echo "com.local.mlx-$name"
}

check_deployment_exists() {
    local name="$1"
    local deploy_path
    deploy_path=$(get_deployment_path "$name")

    if [ -z "$deploy_path" ]; then
        echo "Error: Deployment '$name' not found"
        echo ""
        echo "Available deployments:"
        list_deployments | tail -n +3
        exit 1
    fi
}

cmd_install() {
    local name="$1"
    local start_after=""

    if [ "$2" == "--start" ]; then
        start_after="--start"
    fi

    check_deployment_exists "$name"

    local deploy_path
    deploy_path=$(get_deployment_path "$name")

    echo "Installing deployment: $name"
    "$deploy_path/install.sh" $start_after
}

cmd_uninstall() {
    local name="$1"
    check_deployment_exists "$name"

    local deploy_path
    deploy_path=$(get_deployment_path "$name")

    echo "Uninstalling deployment: $name"
    "$deploy_path/uninstall.sh"
}

cmd_start() {
    local name="$1"
    check_deployment_exists "$name"

    local service_name
    service_name=$(get_service_name "$name")

    echo "Starting service: $service_name"
    launchctl start "$service_name"
}

cmd_stop() {
    local name="$1"
    check_deployment_exists "$name"

    local service_name
    service_name=$(get_service_name "$name")

    echo "Stopping service: $service_name"
    launchctl stop "$service_name"
}

cmd_restart() {
    local name="$1"
    check_deployment_exists "$name"

    local service_name
    service_name=$(get_service_name "$name")

    echo "Restarting service: $service_name"
    launchctl stop "$service_name" 2>/dev/null || true
    sleep 2
    launchctl start "$service_name"
    echo "Service restarted"
}

cmd_status() {
    local name="$1"
    check_deployment_exists "$name"

    local service_name
    service_name=$(get_service_name "$name")

    echo "Deployment: $name"
    echo "Service: $service_name"
    echo ""

    if launchctl list | grep -q "$service_name"; then
        echo "Status: RUNNING"
        launchctl list | grep "$service_name"
    else
        echo "Status: NOT RUNNING"
        if [ -f "$HOME/Library/LaunchAgents/$service_name.plist" ]; then
            echo "Service file exists but is not running"
        else
            echo "Service is not installed"
        fi
    fi
}

cmd_logs() {
    local name="$1"
    local lines="${2:-50}"
    check_deployment_exists "$name"

    local deploy_path
    deploy_path=$(get_deployment_path "$name")

    if [ -f "$deploy_path/logs/stdout.log" ]; then
        echo "=== STDOUT (last $lines lines) ==="
        tail -n "$lines" "$deploy_path/logs/stdout.log"
        echo ""
        echo "=== STDERR (last $lines lines) ==="
        tail -n "$lines" "$deploy_path/logs/stderr.log" 2>/dev/null || echo "(no stderr log)"
    else
        echo "No logs found for deployment: $name"
    fi
}

cmd_watch() {
    local name="$1"
    check_deployment_exists "$name"

    local deploy_path
    deploy_path=$(get_deployment_path "$name")

    local config_name
    config_name=$(python3 -c "import json; c=json.load(open('$deploy_path/config.json')); print(c.get('name', 'unknown'))")
    local display_name
    display_name=$(python3 -c "import json; c=json.load(open('$deploy_path/config.json')); print(c.get('display_name', c.get('name', 'unknown')))")
    local model_path
    model_path=$(python3 -c "import json; c=json.load(open('$deploy_path/config.json')); print(c.get('model_path', ''))")
    local port
    port=$(python3 -c "import json; c=json.load(open('$deploy_path/config.json')); print(c.get('server', {}).get('port', 8000))")

    local service_name="com.local.mlx-$config_name"
    local stderr_log="$deploy_path/logs/stderr.log"
    local stdout_log="$deploy_path/logs/stdout.log"

    echo "=================================================="
    echo "  Watching: $display_name"
    echo "=================================================="
    echo ""
    echo "Model:   $model_path"
    echo "Port:    $port"
    echo "Service: $service_name"
    echo ""

    # Check if service is running
    if ! launchctl list 2>/dev/null | grep -q "$service_name"; then
        echo "Service is not running."
        echo "Start with: ./manage-deployments.sh start $name"
        return 1
    fi

    echo "Status: RUNNING"
    echo ""
    echo "Watching for download progress and server startup..."
    echo "Press Ctrl+C to stop watching"
    echo ""
    echo "--------------------------------------------------"

    # Create logs directory if missing
    mkdir -p "$deploy_path/logs"

    # Wait for log file to exist
    local wait_count=0
    while [ ! -f "$stderr_log" ] && [ $wait_count -lt 30 ]; do
        echo "Waiting for log file..."
        sleep 1
        wait_count=$((wait_count + 1))
    done

    if [ ! -f "$stderr_log" ]; then
        echo "Log file not found after 30 seconds"
        return 1
    fi

    # Poll the log file for progress updates
    # tqdm uses \r for progress which ends up on the last line
    local last_progress=""
    local server_ready=0

    while [ $server_ready -eq 0 ]; do
        # Check if service is still running
        if ! launchctl list 2>/dev/null | grep -q "$service_name"; then
            echo ""
            echo "Service stopped unexpectedly!"
            echo "Check logs: ./manage-deployments.sh logs $name"
            return 1
        fi

        # Get the last line of stderr (where tqdm progress appears)
        local current_line
        current_line=$(tail -1 "$stderr_log" 2>/dev/null || echo "")

        # Check for download progress (Fetching X files)
        if echo "$current_line" | grep -q "Fetching.*files:"; then
            local progress
            progress=$(echo "$current_line" | grep -oE "Fetching [0-9]+ files:.*" | sed 's/\x1b\[[0-9;]*m//g')
            if [ -n "$progress" ] && [ "$progress" != "$last_progress" ]; then
                printf "\r\033[K%s" "$progress"
                last_progress="$progress"
            fi
        fi

        # Check stdout for server startup
        if [ -f "$stdout_log" ]; then
            if grep -q "Uvicorn running\|Started server\|Application startup complete" "$stdout_log" 2>/dev/null; then
                echo ""
                echo ""
                echo "=================================================="
                echo "  Server is ready!"
                echo "  http://localhost:$port"
                echo "=================================================="
                server_ready=1
            fi
        fi

        # Check for errors in stderr
        if echo "$current_line" | grep -qi "error.*\|exception.*\|traceback"; then
            if [ "$current_line" != "$last_progress" ]; then
                echo ""
                echo "ERROR: $current_line"
            fi
        fi

        # Check for 100% download completion
        if echo "$current_line" | grep -q "100%"; then
            if [ "$last_progress" != "download_complete" ]; then
                echo ""
                echo "Download complete! Loading model..."
                last_progress="download_complete"
            fi
        fi

        sleep 1
    done
}

cmd_install_all() {
    echo "Installing all deployments..."
    echo ""

    if [ ! -d "$DEPLOY_DIR" ]; then
        echo "No deployments found"
        return
    fi

    for dir in "$DEPLOY_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/config.json" ]; then
            name=$(python3 -c "import json; c=json.load(open('$dir/config.json')); print(c.get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            echo "=========================================="
            echo "Installing: $name"
            echo "=========================================="
            "$dir/install.sh"
            echo ""
        fi
    done
}

cmd_uninstall_all() {
    echo "Uninstalling all deployments..."
    echo ""

    if [ ! -d "$DEPLOY_DIR" ]; then
        echo "No deployments found"
        return
    fi

    for dir in "$DEPLOY_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/config.json" ]; then
            name=$(python3 -c "import json; c=json.load(open('$dir/config.json')); print(c.get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            service_name="com.local.mlx-$name"

            if [ -f "$HOME/Library/LaunchAgents/$service_name.plist" ]; then
                echo "Uninstalling: $name"
                "$dir/uninstall.sh"
                echo ""
            fi
        fi
    done
}

cmd_start_all() {
    echo "Starting all deployments..."

    if [ ! -d "$DEPLOY_DIR" ]; then
        echo "No deployments found"
        return
    fi

    for dir in "$DEPLOY_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/config.json" ]; then
            name=$(python3 -c "import json; c=json.load(open('$dir/config.json')); print(c.get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            service_name="com.local.mlx-$name"

            if launchctl list | grep -q "$service_name"; then
                echo "Starting: $name"
                launchctl start "$service_name"
            fi
        fi
    done
}

cmd_stop_all() {
    echo "Stopping all deployments..."

    if [ ! -d "$DEPLOY_DIR" ]; then
        echo "No deployments found"
        return
    fi

    for dir in "$DEPLOY_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/config.json" ]; then
            name=$(python3 -c "import json; c=json.load(open('$dir/config.json')); print(c.get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            service_name="com.local.mlx-$name"

            if launchctl list | grep -q "$service_name"; then
                echo "Stopping: $name"
                launchctl stop "$service_name"
            fi
        fi
    done
}

# Main
case "${1:-}" in
    list)
        list_deployments
        ;;
    install)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_install "$2" "${3:-}"
        ;;
    uninstall)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_uninstall "$2"
        ;;
    start)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_start "$2"
        ;;
    stop)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_stop "$2"
        ;;
    restart)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_restart "$2"
        ;;
    status)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_status "$2"
        ;;
    logs)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_logs "$2" "${3:-}"
        ;;
    watch)
        if [ -z "${2:-}" ]; then
            echo "Error: Deployment name required"
            echo ""
            show_help
            exit 1
        fi
        cmd_watch "$2"
        ;;
    install-all)
        cmd_install_all
        ;;
    uninstall-all)
        cmd_uninstall_all
        ;;
    start-all)
        cmd_start_all
        ;;
    stop-all)
        cmd_stop_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Error: Unknown command: ${1:-}"
        echo ""
        show_help
        exit 1
        ;;
esac
