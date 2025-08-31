#!/bin/bash

# RabbitMQ Setup Script for Kubernetes using Helm and Bitnami Chart
# This script installs or updates RabbitMQ in a Kubernetes cluster

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
RabbitMQ Kubernetes Setup Script
================================

DESCRIPTION:
    This script automates the installation and upgrade of RabbitMQ in a Kubernetes cluster 
    using Helm and the Bitnami RabbitMQ chart. It provides an interactive setup process 
    that configures RabbitMQ with clustering, persistence, ingress, and security settings.

USAGE:
    ./setup.sh [OPTIONS]

OPTIONS:
    --help, --?, -h     Display this help message and exit

FEATURES:
    • Automatic detection of existing RabbitMQ installations
    • Interactive prompts for configuration parameters
    • Backup creation before updating configuration files
    • Helm repository management (Bitnami)
    • Kubernetes namespace creation
    • SSL-enabled nginx ingress configuration
    • High availability clustering setup
    • Persistent storage configuration
    • Security context and RBAC setup

PREREQUISITES:
    • kubectl - Kubernetes command-line tool
    • helm - Helm package manager for Kubernetes
    • Access to a Kubernetes cluster
    • nginx ingress controller (for ingress functionality)

REQUIRED PARAMETERS (Interactive Prompts):
    • Kubernetes Namespace    - Target namespace for RabbitMQ deployment
    • Helm Release Name      - Unique name for the Helm release

CONFIGURATION VALUES (From rabbitmq-values.yaml):
    • RabbitMQ Username     - Admin username (read from values file)
    • RabbitMQ Password     - Admin password (read from values file)
    • Ingress Hostname      - Domain name for RabbitMQ management UI access
                              (read from values file)

CONFIGURATION FILE:
    • rabbitmq-values.yaml  - Helm values file containing all configuration
                              including username, password, and hostname

WHAT THE SCRIPT DOES:
    1. Validates prerequisites (kubectl, helm)
    2. Collects user input for namespace and release name
    3. Reads configuration values from rabbitmq-values.yaml
    4. Checks for existing RabbitMQ installations
    5. Sets up Bitnami Helm repository
    6. Creates Kubernetes namespace if needed
    7. Installs or upgrades RabbitMQ using Helm
    8. Displays connection information and usage instructions

POST-INSTALLATION:
    After successful installation, you can access:
    • Management UI: https://[your-hostname]/
    • AMQP Connection: amqp://[username]:[password]@[hostname]:5672

EXAMPLES:
    # Display help
    ./setup.sh --help
    
    # Run interactive setup
    ./setup.sh

SUPPORT:
    For issues, check the README.md file or refer to:
    • Bitnami RabbitMQ Chart: https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq
    • RabbitMQ Documentation: https://www.rabbitmq.com/documentation.html

EOF
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate input is not empty
validate_input() {
    local input="$1"
    local field_name="$2"
    
    if [[ -z "$input" ]]; then
        print_error "$field_name cannot be empty!"
        exit 1
    fi
}

# Function to check if Helm release exists
check_release_exists() {
    local namespace="$1"
    local release_name="$2"
    
    helm list -n "$namespace" | grep -q "^$release_name[[:space:]]" 2>/dev/null
}

# Function to get user input with validation
get_user_input() {
    # Get namespace
    read -p "Enter Kubernetes namespace for RabbitMQ: " NAMESPACE
    validate_input "$NAMESPACE" "Namespace"
    
    # Get release name
    read -p "Enter Helm release name for RabbitMQ: " RELEASE_NAME
    validate_input "$RELEASE_NAME" "Release name"
}

# Function to read values from the YAML file
read_values_from_file() {
    local values_file="rabbitmq-values.yaml"
    
    print_status "Reading configuration from: $values_file"
    
    # Check if values file exists
    if [[ ! -f "$values_file" ]]; then
        print_error "Values file '$values_file' not found!"
        exit 1
    fi
    
    # Extract username from the values file
    RABBITMQ_USERNAME=$(grep -E "^\s*username:" "$values_file" | sed 's/.*username:\s*"\([^"]*\)".*/\1/')
    if [[ -z "$RABBITMQ_USERNAME" ]]; then
        print_error "Could not read username from $values_file"
        exit 1
    fi
    
    # Extract password from the values file
    # RABBITMQ_PASSWORD=$(grep -E "^\s*password:" "$values_file" | sed 's/.*password:\s*"\([^"]*\)".*/\1/')
    # if [[ -z "$RABBITMQ_PASSWORD" ]]; then
    #     print_error "Could not read password from $values_file"
    #     exit 1
    # fi
    
    # Extract hostname from the values file
    INGRESS_HOSTNAME=$(grep -E "^\s*hostname:" "$values_file" | sed 's/.*hostname:\s*"\([^"]*\)".*/\1/')
    if [[ -z "$INGRESS_HOSTNAME" ]]; then
        print_error "Could not read hostname from $values_file"
        exit 1
    fi
    
    print_success "Configuration loaded from values file"
    print_status "Username: $RABBITMQ_USERNAME"
    print_status "Hostname: $INGRESS_HOSTNAME"
    print_status "Password: [LOADED FROM FILE]"
    return 0
}

# Function to setup Helm repository
setup_helm_repo() {
    print_status "Setting up Bitnami Helm repository..."
    
    # Add Bitnami repo
    if ! helm repo list | grep -q "bitnami"; then
        helm repo add bitnami https://charts.bitnami.com/bitnami
        print_success "Bitnami repository added"
    else
        print_status "Bitnami repository already exists"
    fi
    
    # Update repositories
    helm repo update
    print_success "Helm repositories updated"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    local namespace="$1"
    
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        print_status "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
        print_success "Namespace '$namespace' created"
    else
        print_status "Namespace '$namespace' already exists"
    fi
}

# Function to install RabbitMQ
install_rabbitmq() {
    local namespace="$1"
    local release_name="$2"
    
    print_status "Installing RabbitMQ using Helm..."
    
    helm install "$release_name" bitnami/rabbitmq \
        --namespace "$namespace" \
        --values rabbitmq-values.yaml \
        --wait \
        --timeout 10m
        
    print_success "RabbitMQ installed successfully!"
}

# Function to upgrade RabbitMQ
upgrade_rabbitmq() {
    local namespace="$1"
    local release_name="$2"
    
    print_status "Upgrading RabbitMQ using Helm..."
    
    helm upgrade "$release_name" bitnami/rabbitmq \
        --namespace "$namespace" \
        --values rabbitmq-values.yaml \
        --wait \
        --timeout 10m
        
    print_success "RabbitMQ upgraded successfully!"
}

# Function to display connection information
display_connection_info() {
    local namespace="$1"
    local release_name="$2"
    
    echo
    print_success "RabbitMQ Setup Complete!"
    echo
    echo "Connection Information:"
    echo "======================="
    echo "Namespace: $namespace"
    echo "Release Name: $release_name"
    echo "Username: $RABBITMQ_USERNAME"
    echo "Password: [HIDDEN]"
    echo "Management UI: https://$INGRESS_HOSTNAME"
    echo "AMQP URL: amqp://$RABBITMQ_USERNAME:[password]@$INGRESS_HOSTNAME:5672"
    echo
    echo "To get the RabbitMQ password:"
    echo "kubectl get secret --namespace $namespace $release_name-rabbitmq -o jsonpath='{.data.rabbitmq-password}' | base64 -d"
    echo
    echo "To connect to RabbitMQ from within the cluster:"
    echo "kubectl run $release_name-client --rm --tty -i --restart='Never' --namespace $namespace --image docker.io/bitnami/rabbitmq:3.12-debian-11 --env RABBITMQ_PASSWORD=\$RABBITMQ_PASSWORD --command -- bash"
    echo
}

# Main execution function
main() {
    # Check for help arguments
    for arg in "$@"; do
        case $arg in
            --help|--\?|-h)
                show_help
                exit 0
                ;;
        esac
    done
    
    print_status "RabbitMQ Kubernetes Setup Script"
    print_status "================================="
    print_status "Use './setup.sh --help' for detailed information"
    echo
    
    # Check prerequisites
    if ! command_exists kubectl; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
    echo
    
    # Get user input
    get_user_input
    echo
    
    # Read configuration values from file
    read_values_from_file
    echo
    
    # Check if release already exists
    if check_release_exists "$NAMESPACE" "$RELEASE_NAME"; then
        print_warning "RabbitMQ release '$RELEASE_NAME' already exists in namespace '$NAMESPACE'"
        echo
        read -p "Do you want to upgrade it? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Proceeding with upgrade..."
            OPERATION="upgrade"
        else
            print_status "Operation cancelled by user"
            exit 0
        fi
    else
        print_status "New installation will be performed"
        OPERATION="install"
    fi
    
    echo
    
    # Setup Helm repository
    setup_helm_repo
    echo
    
    # Create namespace if needed
    create_namespace "$NAMESPACE"
    echo
    
    # Install or upgrade RabbitMQ
    if [[ "$OPERATION" == "upgrade" ]]; then
        upgrade_rabbitmq "$NAMESPACE" "$RELEASE_NAME"
    else
        install_rabbitmq "$NAMESPACE" "$RELEASE_NAME"
    fi
    
    # Display connection information
    display_connection_info "$NAMESPACE" "$RELEASE_NAME"
}

# Trap to handle script interruption
trap 'print_error "Script interrupted by user"; exit 1' SIGINT SIGTERM

# Execute main function
main "$@"
