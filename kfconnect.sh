#!/bin/bash

set -e

PORT=""
BASE_URL=""

request() {
    local path=$1
    shift 1
    curl -Ls -H 'Content-Type: application/json' "$BASE_URL/$path" "$@"
}

usage() {
    echo "Usage: ./kfconnect.sh COMMAND"
    echo
    echo "Where COMMAND is one of:"
    echo "  port_forward        Forward a port."
    echo "  list                List all connectors."
    echo "  get_connector       Get a connector's configuration."
    echo "  create              Create a new connector."
    echo "  delete              Delete a connector."
    echo "  get_error           Get the first task's trace error of a connector."
    echo "  status              Check connector status."
    echo "  validate             Validate a connector's configuration."
    echo
}

commands_usage() {
    minimum_commands="$1"
    usage_message="$2"
    if [ $# -lt "$minimum_commands" ]; then
        echo "$usage_message"
        exit 1
    fi
}

port_forward() {
    if [ $# -lt 2 ]; then
        echo "Usage: ./kfconnect.sh create_port_forward NAMESPACE SERVICE_NAME [CURL_OPTIONS...]"
        exit 1
    fi
    local namespace=$1
    local svc_name=$2
    kubectl port-forward "-n$namespace" "svc/$svc_name" $PORT
}

list() {
    request "connectors" "$@"
}

pause(){
    if [ $# -lt 1 ]; then
        echo "Usage: ./kfconnect.sh pause CONNECTOR_NAME [CURL_OPTIONS...]"
        exit 1
    fi
    local connector_name=$1
    shift 1
    request "connectors/$connector_name/pause" "-X" "PUT" "$@"
}

status() {
    if [ $# -lt 1 ]; then
        echo "Usage: ./kfconnect.sh status CONNECTOR_NAME [CURL_OPTIONS...]"
        exit 1
    fi
    local connector_name=$1
    shift 1
    request "connectors/$connector_name/status" "-X" "GET" "$@"
}

delete() {
    if [ $# -lt 1 ]; then
        echo "Usage: ./kfconnect.sh delete CONNECTOR_NAME [CURL_OPTIONS...]"
        exit 1
    fi
    local connector_name=$1
    shift 1
    request "connectors/$connector_name" "-X" "DELETE" "$@"
}

create() {
    if [ $# -lt 1 ]; then
        echo "Usage: ./kfconnect.sh create CONFIG_PATH [CURL_OPTIONS...]"
        exit 1
    fi
    local config_path=$1
    shift 1
    request "connectors" "-X" "POST" -d "@$config_path" "$@"
}

restart() {
    if [ $# -lt 1 ]; then
        echo "Usage: ./kfconnect.sh restart CONNECTOR_NAME [CURL_OPTIONS...]"
        exit 1
    fi
    local connector_name=$1
    shift 1
    request "connectors/$connector_name/restart?includeTasks=true" "-X" "POST" "$@"
}

get_connector() {
    if [ $# -lt 1 ]; then
        echo "Usage: ./kfconnect.sh get_connector CONNECTOR_NAME [CURL_OPTIONS...]"
        exit 1
    fi
    local connector_name=$1
    shift 1
    request "connectors/$connector_name" "$@"    
}

get_error() {
    if [ $# -lt 1 ]; then
        echo "Usage: ./kfconnect.sh get_error CONNECTOR_NAME [CURL_OPTIONS...]"
        exit 1
    fi
    local connector_name=$1
    shift 1
    request "connectors/$connector_name/status" "$@" | jq -r '.tasks[0].trace'
}

validate() {
    commands_usage 1 "Usage: ./kfconnect.sh validate_connect_config CONFIG_PATH [CURL_OPTIONS...]"
    local config_path="$1"
    local connector_class
    local config
    shift 1

    isFull=$(jq -r '.name' "$config_path")
    if [[ -z $isFull ]]; then
        # Not the full form, that means the config is directly
        connector_class=$(jq -r '."connector.class"' "$config_path")
        config=$(jq -r '.' "$config_path")
    else 
        # Extracting config from json that has name as well as config side by side
        connector_class=$(jq -r '.config."connector.class"' "$config_path")
        config=$(jq -r '.config' "$config_path")
    fi

    connector_type=$(rev <<<"$connector_class" | cut -d'.' -f1 | rev)
    request "connector-plugins/$connector_type/config/validate" -X PUT -d "$config" "$@"

}

main() {
    
    local port="28082"
    while (( "$#"  )); do
        case "$1" in
            # Handle non positional arguments first (the ones that start with --)
            --port)
                if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                    port="$2"
                    shift 2
                else
                    echo "Error: Argument for $1 is missing" >&2
                    exit 1
                fi
                ;;
            --)
                shift
                break
                ;;
            # Handle positional arguments
            *)
                PARAMS="$PARAMS $1"
                shift
                ;;
        esac
    done
    eval set -- "$PARAMS" # Setting all parameters back except the non positional ones

    local command="$1"
    if [ -z "$command" ]; then
        usage
        exit 1
    fi

    PORT="$port"
    BASE_URL="localhost:${PORT:-28082}"
    shift 1 # Move to the next positional parameters, that is the command arguments
    "$command" "$@"
}

main "$@"
