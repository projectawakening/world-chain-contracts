#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize logging
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/test_$TIMESTAMP.log"
touch "$LOG_FILE"  # Create log file immediately

# Print with color and log
print_and_log() {
    local color=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}${message}${NC}"
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Function to start and manage Anvil
start_anvil() {
    print_and_log "$YELLOW" "Starting Anvil node with saved smart object framework snapshot..."
    anvil --gas-limit 120000000 --load-state ../sof-state.json > /dev/null 2>&1 &
    ANVIL_PID=$!

    # Wait for anvil to initialize
    print_and_log "$YELLOW" "Waiting for Anvil to initialize..."
    sleep 2

    # Check if Anvil is running properly
    if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:8545 > /dev/null; then
        print_and_log "$RED" "ERROR: Anvil node failed to start properly."
        kill $ANVIL_PID 2>/dev/null || true
        exit 1
    fi

    # Print latest block for debugging
    LATEST_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:8545 | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    print_and_log "$GREEN" "Latest block: $LATEST_BLOCK"
}

# Function to set environment variables
setup_environment() {
    print_and_log "$YELLOW" "Setting up environment variables..."
    export WORLD_ADDRESS="0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
    export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    export RPC_URL=http://127.0.0.1:8545
    export ERC20_TOKEN_NAME="TEST TOKEN"
    export ERC20_TOKEN_SYMBOL=TEST
    export ERC20_INITIAL_SUPPLY=10000000000
    export EVE_TOKEN_NAMESPACE=test
    export EVE_TOKEN_ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    export TENANT=TEST
    export CHARACTER_TYPE_ID=1
    export CHARACTER_VOLUME=0
    export SSU_TYPE_ID=2
    export SSU_VOLUME=1000
    export DEPLOYABLE_TYPE_ID=3
    export DEPLOYABLE_VOLUME=0
    export TURRET_TYPE_ID=4
    export TURRET_VOLUME=1000
    export GATE_TYPE_ID=5
    export GATE_VOLUME=10000
}

# Function to run deployments
run_deployments() {
    print_and_log "$YELLOW" "Running world-v2 upgrade..."
    pnpm nx run @eveworld/world-v2:upgrade >> "$LOG_FILE" 2>&1 || { print_and_log "$RED" "Upgrade failed"; cleanup; exit 1; }

    print_and_log "$YELLOW" "Running post-deploy..."
    pnpm nx run @eveworld/world-v2:post-deploy >> "$LOG_FILE" 2>&1 || { print_and_log "$RED" "Post-deploy failed"; cleanup; exit 1; }

    print_and_log "$YELLOW" "Running config..."
    pnpm nx run @eveworld/world-v2:config >> "$LOG_FILE" 2>&1 || { print_and_log "$RED" "Config failed"; cleanup; exit 1; }
}

# Function to run a forge script and log its output
run_forge_script() {
    local script_name=$1
    local start_time=$(date +%s)
    
    print_and_log "$YELLOW" "Running $script_name..."
    
    # Run the forge script and append to the log file
    forge script "script/$script_name.s.sol:$script_name" \
        --fork-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --broadcast \
        --sig "run(address)" "$WORLD_ADDRESS" \
        -vvv >> "$LOG_FILE" 2>&1
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        print_and_log "$GREEN" "✅ $script_name completed successfully (took ${duration}s)"
    else
        print_and_log "$RED" "❌ $script_name failed after ${duration}s. Check $LOG_FILE for details"
        print_and_log "$YELLOW" "Last 10 lines of log:"
        tail -n 10 "$LOG_FILE" | while read line; do
            print_and_log "$YELLOW" "$line"
        done
        cleanup
        exit 1
    fi
}

# Function to clean up old log files
cleanup_old_logs() {
    local keep_days=7
    if [ -d "logs" ]; then
        find logs -type f -mtime +$keep_days -exec rm -f {} \;
        print_and_log "$GREEN" "Cleaned up logs older than $keep_days days"
    fi
}

# Function to clean up resources
cleanup() {
    print_and_log "$YELLOW" "Cleaning up resources..."
    if [ -n "$ANVIL_PID" ]; then
        kill $ANVIL_PID 2>/dev/null || true
    fi
}

# Main execution
print_and_log "$YELLOW" "Starting test suite..."

# Clean up old logs
cleanup_old_logs

# Start Anvil
start_anvil

# Setup environment
setup_environment

# Run deployments
run_deployments

# Run all scripts in sequence
scripts=(
    "CreateSmartCharacter"
    "CreateMintERC20"
    "AnchorSSU"
    "DepositFuel"
    "BringOnline"
    "DepositToInventory"
    "DepositToEphemeral"
    "WithdrawFromInventory"
    "WithdrawFromEphemeral"
    "TransferItems"
    "AnchorSmartTurret"
    "ConfigureSmartTurret"
    "AnchorSmartGate"
    "ConfigureSmartGate"
)

print_and_log "$YELLOW" "Starting test suite with ${#scripts[@]} scripts..."
print_and_log "$YELLOW" "Log file: $LOG_FILE"
echo ""

# Run all scripts
for script in "${scripts[@]}"; do
    run_forge_script "$script"
done

# Cleanup and exit
cleanup
print_and_log "$GREEN" "\nAll tests completed successfully! 🎉"
print_and_log "$YELLOW" "Full log available in $LOG_FILE" 