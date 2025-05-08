# Common variables and functions for deploy and upgrade scripts

bar_size=40
bar_char_done="#"
bar_char_todo="-"
bar_percentage_scale=2

show_progress() {
    current="$1"
    total="$2"
    message="${3:-World deployed}"  # Default message if not provided

    # calculate the progress in percentage using awk for floating point arithmetic with fixed precision
    percent=$(awk -v current="$current" -v total="$total" \
        'BEGIN {printf "%.2f", (100 * current / total)}')

    # Calculate the number of done and todo characters using awk
    done=$(awk -v percent="$percent" -v bar_size="$bar_size" 'BEGIN {printf "%d", int(bar_size * percent / 100)}')
    todo=$(awk -v done="$done" -v bar_size="$bar_size" 'BEGIN {printf "%d", int(bar_size - done)}')

    # Build the done and todo sub-bars
    done_sub_bar=$(printf "%${done}s" | tr " " "$bar_char_done")
    todo_sub_bar=$(printf "%${todo}s" | tr " " "$bar_char_todo")

    # Output the bar
    printf "\rProgress : [${done_sub_bar}${todo_sub_bar}] ${percent}%%"

    if [ "$total" -eq "$current" ]; then
        printf "\nSuccess: %s\n" "$message"
    fi
}

# Function to get chain ID from RPC URL
get_chain_id() {
    local rpc_url=$1
    # Perform the curl request and check if it was successful
    local response=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' -H "Content-Type: application/json" $rpc_url)
    local success=$?

    # Check if curl command was successful (exit code 0)
    if [ $success -ne 0 ]; then
        echo "Error: Failed to fetch chain ID from RPC URL: $rpc_url" | tee -a $LOG_FILE
        return 1
    fi

    # Extract the result and handle the case where no result is found
    local chain_id_hex=$(echo "$response" | jq -r '.result')
    if [ "$chain_id_hex" = "null" ] || [ -z "$chain_id_hex" ]; then
        echo "Error: No valid chain ID returned from the RPC URL: $rpc_url" | tee -a $LOG_FILE
        return 1
    fi

    # Remove the '0x' prefix if present and convert hex to decimal
    local chain_id_decimal=$(echo "$chain_id_hex" | sed 's/0x//')
    echo "$((16#$chain_id_decimal))"
}

# Function to validate Ethereum address format
validate_eth_address() {
    local address=$1
    if [ ! -z "$address" ]; then
        if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            echo "Error: Invalid Ethereum address format. Must be a valid Ethereum address (0x... with 40 hex characters)" | tee -a $LOG_FILE
            exit 1
        fi
    fi
}

# Default values
rpc_url=""
private_key=""
world_address=""

# Parse command-line arguments
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -p1|--rpc-url)
                rpc_url="$2"
                shift 2
                ;;
            -p2|--private-key)
                private_key="$2"
                shift 2
                ;;
            -wa|--world-address)
                world_address="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" | tee -a $LOG_FILE
                exit 1
                ;;
        esac
    done
} 
