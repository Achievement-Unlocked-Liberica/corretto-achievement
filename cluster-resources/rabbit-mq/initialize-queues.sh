#!/bin/bash

# RabbitMQ Queue Initialization Script
# This script creates queues in RabbitMQ by reading from setup-queues.txt

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display help information
show_help() {
    cat << EOF
RabbitMQ Queue Initialization Script
====================================

DESCRIPTION:
    This script creates queues in RabbitMQ by reading queue names from setup-queues.txt.
    It uses the RabbitMQ Management HTTP API to create durable, non-auto-delete queues.

USAGE:
    ./initialize-queues.sh [OPTIONS]

OPTIONS:
    --help, --?, -h     Display this help message and exit
    --host HOST         RabbitMQ hostname (default: rabbitmq.aunlocked.com)
    --port PORT         RabbitMQ management port (default: 15672)
    --username USER     RabbitMQ admin username (default: rabbitmq-admin)
    --password PASS     RabbitMQ admin password (default: read from secret)
    --vhost VHOST       Virtual host (default: /)
    --file FILE         Queue list file (default: setup-queues.txt)
    --durable BOOL      Make queues durable (default: true)
    --auto-delete BOOL  Auto-delete queues (default: false)

QUEUE FILE FORMAT:
    The setup-queues.txt file should contain one queue name per line.
    Empty lines and lines starting with # are ignored.
    
    Example:
        # Comment line
        challenge.comment.created.queue
        challenge.created.queue
        challenge.updated.queue

PREREQUISITES:
    • RabbitMQ instance running with management plugin enabled
    • curl command available
    • Network access to RabbitMQ management API
    • Valid admin credentials

EXAMPLES:
    # Display help
    ./initialize-queues.sh --help
    
    # Run with defaults (reads from setup-queues.txt)
    ./initialize-queues.sh
    
    # Specify custom host and credentials
    ./initialize-queues.sh --host localhost --port 15672 --username admin --password secret
    
    # Use different queue file
    ./initialize-queues.sh --file my-queues.txt

POST-EXECUTION:
    After successful execution, you can verify queues in the management UI:
    • Management UI: http://rabbitmq.aunlocked.com
    • Navigate to Queues tab to see created queues

EOF
}

# Default values
RABBITMQ_HOST="rabbitmq.aunlocked.com"
RABBITMQ_PORT="15672"
RABBITMQ_USERNAME="rabbitmq-admin"
RABBITMQ_PASSWORD=""
VHOST="/"
QUEUE_FILE="setup-queues.txt"
DURABLE="true"
AUTO_DELETE="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|--\?|-h)
            show_help
            exit 0
            ;;
        --host)
            RABBITMQ_HOST="$2"
            shift 2
            ;;
        --port)
            RABBITMQ_PORT="$2"
            shift 2
            ;;
        --username)
            RABBITMQ_USERNAME="$2"
            shift 2
            ;;
        --password)
            RABBITMQ_PASSWORD="$2"
            shift 2
            ;;
        --vhost)
            VHOST="$2"
            shift 2
            ;;
        --file)
            QUEUE_FILE="$2"
            shift 2
            ;;
        --durable)
            DURABLE="$2"
            shift 2
            ;;
        --auto-delete)
            AUTO_DELETE="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to get password from Kubernetes secret
get_password_from_secret() {
    local namespace="$1"
    local secret_name="rabbitmq-credentials"
    
    print_status "Attempting to retrieve password from Kubernetes secret..."
    
    if command -v kubectl >/dev/null 2>&1; then
        local password=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.rabbitmq-password}' 2>/dev/null | base64 -d 2>/dev/null)
        
        if [[ -n "$password" ]]; then
            print_success "Password retrieved from Kubernetes secret"
            echo "$password"
            return 0
        fi
    fi
    
    return 1
}

# Function to check if RabbitMQ is accessible
check_rabbitmq_connection() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    
    print_status "Testing connection to RabbitMQ at $host:$port..."
    
    local response=$(curl -s -w "%{http_code}" -u "$username:$password" \
        "http://$host:$port/api/overview" \
        -o /dev/null)
    
    if [[ "$response" == "200" ]]; then
        print_success "Successfully connected to RabbitMQ"
        return 0
    elif [[ "$response" == "401" ]]; then
        print_error "Authentication failed - invalid credentials"
        return 1
    else
        print_error "Cannot connect to RabbitMQ (HTTP $response)"
        return 1
    fi
}

# Function to check if a queue exists
queue_exists() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local vhost="$5"
    local queue_name="$6"
    
    # URL encode the vhost
    local encoded_vhost=$(echo -n "$vhost" | jq -sRr @uri 2>/dev/null || python3 -c "import urllib.parse; print(urllib.parse.quote('$vhost'))" 2>/dev/null || echo "%2F")
    local encoded_queue=$(echo -n "$queue_name" | jq -sRr @uri 2>/dev/null || python3 -c "import urllib.parse; print(urllib.parse.quote('$queue_name'))" 2>/dev/null || echo "$queue_name")
    
    local response=$(curl -s -w "%{http_code}" -u "$username:$password" \
        "http://$host:$port/api/queues/$encoded_vhost/$encoded_queue" \
        -o /dev/null)
    
    [[ "$response" == "200" ]]
}

# Function to create a queue
create_queue() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local vhost="$5"
    local queue_name="$6"
    local durable="$7"
    local auto_delete="$8"
    
    # URL encode the vhost
    local encoded_vhost=$(echo -n "$vhost" | jq -sRr @uri 2>/dev/null || python3 -c "import urllib.parse; print(urllib.parse.quote('$vhost'))" 2>/dev/null || echo "%2F")
    local encoded_queue=$(echo -n "$queue_name" | jq -sRr @uri 2>/dev/null || python3 -c "import urllib.parse; print(urllib.parse.quote('$queue_name'))" 2>/dev/null || echo "$queue_name")
    
    local json_payload=$(cat <<EOF
{
  "durable": $durable,
  "auto_delete": $auto_delete,
  "arguments": {}
}
EOF
)
    
    local response=$(curl -s -w "%{http_code}" -u "$username:$password" \
        -X PUT \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "http://$host:$port/api/queues/$encoded_vhost/$encoded_queue" \
        -o /dev/null)
    
    if [[ "$response" == "201" ]] || [[ "$response" == "204" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to read and process queue file
process_queue_file() {
    local file="$1"
    local host="$2"
    local port="$3"
    local username="$4"
    local password="$5"
    local vhost="$6"
    local durable="$7"
    local auto_delete="$8"
    
    local total_count=0
    local created_count=0
    local skipped_count=0
    local failed_count=0
    
    print_status "Reading queues from: $file"
    echo
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Trim whitespace
        queue_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$queue_name" ]] && continue
        
        ((total_count++))
        
        print_status "Processing queue: $queue_name"
        
        # Check if queue already exists
        if queue_exists "$host" "$port" "$username" "$password" "$vhost" "$queue_name"; then
            print_warning "  Queue already exists, skipping..."
            ((skipped_count++))
        else
            # Create the queue
            if create_queue "$host" "$port" "$username" "$password" "$vhost" "$queue_name" "$durable" "$auto_delete"; then
                print_success "  Queue created successfully"
                ((created_count++))
            else
                print_error "  Failed to create queue"
                ((failed_count++))
            fi
        fi
        
        echo
    done < "$file"
    
    # Print summary
    echo
    print_status "==================================="
    print_status "Queue Creation Summary"
    print_status "==================================="
    echo "Total queues in file: $total_count"
    echo "Created: $created_count"
    echo "Already existed: $skipped_count"
    echo "Failed: $failed_count"
    echo
    
    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Main execution function
main() {
    print_status "RabbitMQ Queue Initialization Script"
    print_status "====================================="
    print_status "Use './initialize-queues.sh --help' for detailed information"
    echo
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
    echo
    
    # Check if queue file exists
    if [[ ! -f "$QUEUE_FILE" ]]; then
        print_error "Queue file not found: $QUEUE_FILE"
        print_status "Create a file with queue names (one per line) or specify --file option"
        exit 1
    fi
    
    # Get password if not provided
    if [[ -z "$RABBITMQ_PASSWORD" ]]; then
        print_status "No password provided, checking for Kubernetes secret..."
        
        # Try common namespaces
        for ns in coffee-cluster-services default; do
            RABBITMQ_PASSWORD=$(get_password_from_secret "$ns")
            if [[ -n "$RABBITMQ_PASSWORD" ]]; then
                break
            fi
        done
        
        if [[ -z "$RABBITMQ_PASSWORD" ]]; then
            print_warning "Could not retrieve password from Kubernetes secret"
            read -s -p "Enter RabbitMQ password: " RABBITMQ_PASSWORD
            echo
            
            if [[ -z "$RABBITMQ_PASSWORD" ]]; then
                print_error "Password is required"
                exit 1
            fi
        fi
    fi
    
    echo
    
    # Test connection
    if ! check_rabbitmq_connection "$RABBITMQ_HOST" "$RABBITMQ_PORT" "$RABBITMQ_USERNAME" "$RABBITMQ_PASSWORD"; then
        exit 1
    fi
    
    echo
    
    # Process queue file
    print_status "Configuration:"
    echo "  Host: $RABBITMQ_HOST:$RABBITMQ_PORT"
    echo "  Virtual Host: $VHOST"
    echo "  Username: $RABBITMQ_USERNAME"
    echo "  Queue File: $QUEUE_FILE"
    echo "  Durable: $DURABLE"
    echo "  Auto-delete: $AUTO_DELETE"
    echo
    
    if process_queue_file "$QUEUE_FILE" "$RABBITMQ_HOST" "$RABBITMQ_PORT" "$RABBITMQ_USERNAME" "$RABBITMQ_PASSWORD" "$VHOST" "$DURABLE" "$AUTO_DELETE"; then
        print_success "Queue initialization completed successfully!"
        echo
        print_status "You can view the queues in the management UI:"
        print_status "http://$RABBITMQ_HOST/queues"
    else
        print_error "Queue initialization completed with errors"
        exit 1
    fi
}

# Trap to handle script interruption
trap 'print_error "Script interrupted by user"; exit 1' SIGINT SIGTERM

# Execute main function
main "$@"
