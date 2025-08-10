NAMESPACE="coffee-cluster-services"
CERT_MANAGER_NAMESPACE="cert-manager"

# Install NGINX Ingress Controller using Helm
echo "Installing NGINX Ingress Controller..."

echo "Adding ingress-nginx Helm repo..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

echo "Updating Helm repos..."
helm repo update

# Create the namespace for NGINX Ingress if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace '$NAMESPACE' does not exist. Creating it..."
  kubectl create namespace "$NAMESPACE"
else
  echo "Namespace '$NAMESPACE' already exists."
fi

echo "Checking if 'nginx-ingress' Helm release exists in namespace $NAMESPACE..."
if ! helm status nginx-ingress -n $NAMESPACE >/dev/null 2>&1; then
    echo "Installing nginx-ingress in namespace $NAMESPACE..."
    helm install nginx-ingress ingress-nginx/ingress-nginx -n $NAMESPACE --set controller.publishService.enabled=true

    echo "Getting nginx-ingress controller service in namespace $NAMESPACE..."
    kubectl --namespace coffee-cluster-services get services -o wide

    echo "Waiting for nginx-ingress controller service to be ready..."
    kubectl wait --namespace $NAMESPACE --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx --timeout=120s
else
    echo "'nginx-ingress' Helm release already exists in namespace $NAMESPACE."
fi

# Install Cert-Manager and JetStack using Helm
echo "Installing cert-manager..."

echo "Creating $CERT_MANAGER_NAMESPACE namespace..."
kubectl create namespace $CERT_MANAGER_NAMESPACE

echo "Adding jetstack Helm repo..."
helm repo add jetstack https://charts.jetstack.io

echo "Installing cert-manager in namespace $CERT_MANAGER_NAMESPACE..."
helm install cert-manager jetstack/cert-manager --namespace $CERT_MANAGER_NAMESPACE --version v1.17.1 --set installCRDs=true

# echo "Applying production issuer configuration..."
# # Assuming production-issuer.yaml is in the current directory
# if [ -f production-issuer.yaml ]; then
#     echo "Applying production issuer configuration from production-issuer.yaml..."

#     if kubectl get secret letsencrypt-prod-private-key -n $NAMESPACE >/dev/null 2>&1; then
#         read -p "Secret 'letsencrypt-prod-private-key' already exists in namespace '$NAMESPACE'. Override it? (y/N): " override
#         if [[ "$override" =~ ^[Yy]$ ]]; then
#             kubectl apply -f production-issuer.yaml -n $NAMESPACE
#         else
#             echo "Skipping issuer configuration as per user request."
#         fi
#     else
#         kubectl apply -f production-issuer.yaml -n $NAMESPACE
#     fi

# else
#     echo "production-issuer.yaml not found. Skipping issuer configuration."
# fi


# Applying espresso-service-cert-dev ClusterIssuer configuration
echo "Applying espresso-service-cert-dev ClusterIssuer configuration..."

if [ -f espresso-service-cert-dev.yaml ]; then
    echo "Applying espresso-service-cert-dev ClusterIssuer configuration from espresso-service-cert-dev.yaml..."

    if kubectl get clusterissuer espresso-service-cert-dev -n $NAMESPACE >/dev/null 2>&1; then
        read -p "ClusterIssuer 'espresso-service-cert-dev' already exists. Override it? (y/N): " override
        if [[ "$override" =~ ^[Yy]$ ]]; then
            kubectl apply -f espresso-service-cert-dev.yaml -n $NAMESPACE
        else
            echo "Skipping ClusterIssuer configuration as per user request."
        fi
    else
        kubectl apply -f espresso-service-cert-dev.yaml -n $NAMESPACE
    fi

else
    echo "espresso-service-cert-dev.yaml not found. Skipping ClusterIssuer configuration."
fi

