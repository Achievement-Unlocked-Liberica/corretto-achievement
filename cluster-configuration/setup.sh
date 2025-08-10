#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <cluster-name> <namespace>"
    exit 1
fi

# Assign parameters to variables
CLUSTER_NAME="$1"
NAMESPACE="$2"

# Output the values (optional, for debugging purposes)
echo "Cluster Name: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"

# Request a GitHub Username from the user
read -p "Please enter your GitHub Username: " GITHUB_USERNAME

# Request a GitHub Token from the user
read -sp "Please enter your GitHub Token used by the K8s Cluster to access the GitHub Repository: " GITHUB_TOKEN
echo

# Output the GitHub Username (optional, for debugging purposes)
echo "GitHub Username provided: $GITHUB_USERNAME"
echo "GitHub Token provided: $GITHUB_TOKEN"


# NAMESPACE CREATION --------------------------------------------------------------------

# Check if the namespace exists; if not, create it
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace '$NAMESPACE' does not exist. Creating it..."
  kubectl create namespace "$NAMESPACE"
else
  echo "Namespace '$NAMESPACE' already exists."
fi

# GH REPO SECRETS CREATION --------------------------------------------------------------

# Check if the secret 'github-container-registry' exists in the namespace
echo "Checking for existing GitHub Container Registry secret in namespace '$NAMESPACE'..."
SKIP_GHREPO_SECRET_APPLY=false
if kubectl get secret github-container-registry -n "$NAMESPACE" >/dev/null 2>&1; then
  read -p "Secret 'github-container-registry' already exists in namespace '$NAMESPACE'. Overwrite it? (y/N): " OVERWRITE_GITHUB_SECRET
  if [[ "$OVERWRITE_GITHUB_SECRET" =~ ^[Yy]$ ]]; then  
    kubectl delete secret github-container-registry -n "$NAMESPACE"  
    SKIP_GHREPO_SECRET_APPLY=false
  else
    SKIP_GHREPO_SECRET_APPLY=true
  fi
else
  SKIP_GHREPO_SECRET_APPLY=fasle
fi

# Create or update the secret for GitHub Container Registry
echo "Creating or updating GitHub Container Registry secret in namespace '$NAMESPACE'..."
if [ "$SKIP_GHREPO_SECRET_APPLY" != "true" ]; then    
    kubectl create secret docker-registry github-container-registry \
      --docker-server=ghcr.io \
      --docker-username="$GITHUB_USERNAME" \
      --docker-password="$GITHUB_TOKEN" \
      -n "$NAMESPACE" \
      --v=0
fi

# COFFEE APPLICATION SECRETS CREATION----------------------------------------------------

# Check if the secret 'coffee-service-application-secrets' exists in the namespace
echo "Checking for existing coffee service application secrets in namespace '$NAMESPACE'..."
SKIP_SECRET_APPLY=false
if kubectl get secret coffee-service-application-secrets -n "$NAMESPACE" >/dev/null 2>&1; then  
  read -p "Secret 'coffee-service-application-secrets' already exists in namespace '$NAMESPACE'. Overwrite it? (y/N): " OVERWRITE_SECRET
  if [[ ! "$OVERWRITE_SECRET" =~ ^[Yy]$ ]]; then
    kubectl delete secret coffee-service-application-secrets -n "$NAMESPACE"
    SKIP_SECRET_APPLY=false
  else
    SKIP_SECRET_APPLY=true
  fi
else
  SKIP_SECRET_APPLY=false
fi

# Create or update the secret for coffee service application
echo "Creating or updating coffee service application secrets in namespace '$NAMESPACE'..."
if [ "$SKIP_SECRET_APPLY" != "true" ]; then
  # Apply the coffee-service-application-secrets.yaml file to the specified namespace
  kubectl apply -f private/coffee-service-application-secrets.yaml -n $NAMESPACE
fi
