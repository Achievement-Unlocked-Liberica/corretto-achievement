# RabbitMQ Setup for Kubernetes

This directory contains scripts and configuration files for setting up RabbitMQ in a Kubernetes cluster using Helm and the Bitnami RabbitMQ chart with secure credential management.

## Prerequisites

Before running the setup script, ensure you have the following tools installed:

- **kubectl**: Kubernetes command-line tool
- **helm**: Helm package manager for Kubernetes
- **bash**: The script requires a bash shell environment
- **nginx ingress controller**: For ingress functionality

## Files

- `setup.sh`: Main setup script for RabbitMQ installation/upgrade
- `rabbitmq-values.yaml`: Helm values configuration file for RabbitMQ
- `rabbitmq-secret.yaml`: Kubernetes secret manifest for RabbitMQ password
- `rabbitmq-values-pathrewrite.yaml.bak`: Alternative configuration for subpath routing
- `initialize-queues.sh`: Script to initialize RabbitMQ queues from configuration file
- `setup-queues.txt`: List of queues to create (one per line)
- `README.md`: This documentation file

## Security Features

### Credential Management
- **Username**: Stored in `rabbitmq-values.yaml` as `rabbitmq-admin`
- **Password**: Securely stored in Kubernetes secret `rabbitmq-credentials`
- **No plaintext passwords** in configuration files
- **RBAC enabled** for enhanced security

## Usage

### Step 1: Create the Secret

First, create the Kubernetes secret containing the RabbitMQ password:

```bash
# Apply the secret manifest
kubectl apply -f rabbitmq-secret.yaml
```

### Step 2: Run the Setup Script

1. Make the script executable:
   ```bash
   chmod +x setup.sh
   ```

2. Run the script:
   ```bash
   ./setup.sh
   ```

### Input Parameters

The script will prompt you for the following information:

1. **Kubernetes Namespace**: The namespace where RabbitMQ will be deployed (e.g., `coffee-cluster-services`)
2. **Helm Release Name**: The name for the Helm release (e.g., `rabbitmq-coffee`)

### Pre-configured Values

The following values are pre-configured in the files:

- **Username**: `rabbitmq-admin` (in `rabbitmq-values.yaml`)
- **Password**: `pedro` (in `rabbitmq-secret.yaml`, base64 encoded)
- **Hostname**: `rabbitmq.aunlocked.com` (subdomain approach)
- **Ingress Path**: `/` (served from root)

## Features

### Installation/Upgrade Detection
- The script automatically detects if RabbitMQ is already installed
- If an existing installation is found, it asks if you want to upgrade it
- Supports both fresh installations and upgrades

### Configuration
The repository includes a pre-configured `rabbitmq-values.yaml` file with the current configurations:

#### Authentication (Secure)
- **Username**: `rabbitmq-admin` (stored in values file)
- **Password**: Loaded from Kubernetes secret `rabbitmq-credentials`
- **Secret Key**: `rabbitmq-password`
- **RBAC support**: Enabled

#### Persistence
- **Persistent volume claims**: Enabled
- **Storage size**: 10GB
- **Access mode**: ReadWriteOnce

#### High Availability
- **Clustering**: Enabled with 2 replicas
- **Peer discovery**: Kubernetes-based
- **Partition handling**: Auto-healing

#### Resources (Optimized)
- **CPU limits**: 500m, **requests**: 250m
- **Memory limits**: 500Mi, **requests**: 250Mi

#### Ingress (Subdomain Approach)
- **Hostname**: `rabbitmq.aunlocked.com`
- **Path**: `/` (root path)
- **Ingress Class**: nginx
- **SSL**: Disabled (can be enabled)
- **TLS**: False (can be enabled)

#### Security
- Non-root container execution
- Security contexts configured
- Read-only root filesystem options

#### Monitoring
- Metrics enabled
- Optional ServiceMonitor for Prometheus
- Optional PrometheusRule support

#### Plugins
- Management plugin enabled
- Kubernetes peer discovery plugin
- Support for community plugins

## Post-Installation

After successful installation, the script will display:

1. **Connection Information**:
   - Namespace and release name
   - Username (password hidden for security)
   - Management UI URL
   - AMQP connection URL

2. **Useful Commands**:
   - How to retrieve the RabbitMQ password from Kubernetes secret
   - How to connect to RabbitMQ from within the cluster

### Accessing RabbitMQ

#### Management UI
Access the management interface at: `http://rabbitmq.aunlocked.com`

**Login Credentials:**
- Username: `rabbitmq-admin`
- Password: `pedro`

#### AMQP Connection
Connect to RabbitMQ using: `amqp://rabbitmq-admin:pedro@rabbitmq.aunlocked.com:5672`

#### From Within Cluster
```bash
kubectl run rabbitmq-client --rm --tty -i --restart='Never' \
  --namespace coffee-cluster-services \
  --image docker.io/bitnami/rabbitmq:4.1.3-debian-12-r1 \
  --env RABBITMQ_PASSWORD=pedro \
  --command -- bash
```

## Queue Initialization

### Creating Queues from Configuration

After deploying RabbitMQ, you can initialize queues using the `initialize-queues.sh` script:

1. **Edit the queue list**:
   - Open `setup-queues.txt`
   - Add one queue name per line
   - Lines starting with `#` are treated as comments

   ```
   # Challenge-related queues
   challenge.comment.created.queue
   challenge.created.queue
   challenge.updated.queue
   ```

2. **Make the script executable**:
   ```bash
   chmod +x initialize-queues.sh
   ```

3. **Run the initialization script**:
   ```bash
   # Run with defaults (auto-detects password from Kubernetes secret)
   ./initialize-queues.sh
   
   # Or specify credentials manually
   ./initialize-queues.sh --username rabbitmq-admin --password pedro
   
   # Use custom queue file
   ./initialize-queues.sh --file my-custom-queues.txt
   
   # Display all options
   ./initialize-queues.sh --help
   ```

### Queue Configuration Options

The script creates queues with these default properties:
- **Durable**: `true` (queues survive broker restart)
- **Auto-delete**: `false` (queues are not deleted when unused)
- **Virtual Host**: `/` (default vhost)

You can customize these with command-line options:
```bash
./initialize-queues.sh --durable false --auto-delete true
```

### Verifying Queue Creation

After running the script, verify queues were created:

1. **Via Management UI**:
   - Go to `http://rabbitmq.aunlocked.com`
   - Navigate to the "Queues" tab

2. **Via API**:
   ```bash
   curl -u rabbitmq-admin:pedro http://rabbitmq.aunlocked.com:15672/api/queues
   ```

3. **Via kubectl**:
   ```bash
   kubectl exec -it rabbitmq-coffee-0 -n coffee-cluster-services -- \
     rabbitmqctl list_queues name durable auto_delete
   ```

## Secret Management

### Updating the Password

To change the RabbitMQ password:

1. **Update the secret**:
   ```bash
   # Method 1: Edit the secret directly
   kubectl edit secret rabbitmq-credentials -n coffee-cluster-services
   
   # Method 2: Update the YAML file and reapply
   # Edit rabbitmq-secret.yaml with new password
   kubectl apply -f rabbitmq-secret.yaml
   ```

2. **Restart RabbitMQ pods** (to pick up the new password):
   ```bash
   kubectl rollout restart statefulset rabbitmq-coffee -n coffee-cluster-services
   ```

### Viewing Secret Information

```bash
# View secret details
kubectl get secret rabbitmq-credentials -n coffee-cluster-services -o yaml

# Get password value (will be base64 encoded)
kubectl get secret rabbitmq-credentials -n coffee-cluster-services -o jsonpath='{.data.rabbitmq-password}' | base64 -d
```

## Customization

### Values File
The `rabbitmq-values.yaml` file can be customized before running the installation. Common modifications include:

- **Storage size**: Modify `persistence.size` (default: 10Gi)
- **Replica count**: Adjust `clustering.replicaCount` (default: 2)
- **Resources**: Change `resources.limits` and `resources.requests`
- **Ingress hostname**: Update `ingress.hostname`
- **SSL/TLS**: Enable `ingress.tls` and add certificates
- **Node affinity**: Configure `affinity`, `nodeSelector`, or `tolerations`

### Alternative: Subpath Configuration

For serving RabbitMQ under a subpath (e.g., `api.aunlocked.com/rabbitmq`), use the alternative configuration:

```bash
# Copy the subpath configuration
cp rabbitmq-values-pathrewrite.yaml.bak rabbitmq-values.yaml
# Then run the setup script
./setup.sh
```

**Note**: Subpath routing is more complex and may have limitations with RabbitMQ's management interface.

### Advanced Configuration
For advanced configurations:

1. **Direct Helm deployment**:
   ```bash
   helm install rabbitmq-coffee bitnami/rabbitmq \
     --namespace coffee-cluster-services \
     --values rabbitmq-values.yaml
   ```

2. **Custom secret management**:
   - Integrate with external secret managers (AWS Secrets Manager, Azure Key Vault)
   - Use tools like External Secrets Operator or Sealed Secrets

## Troubleshooting

### Common Issues

1. **Invalid credentials error**:
   ```bash
   # Check if secret exists and has correct key
   kubectl get secret rabbitmq-credentials -n coffee-cluster-services -o yaml
   
   # Verify password value
   kubectl get secret rabbitmq-credentials -n coffee-cluster-services -o jsonpath='{.data.rabbitmq-password}' | base64 -d
   
   # Ensure the secret key name matches the configuration
   # Should be 'rabbitmq-password' in both secret and values file
   ```

2. **Helm repository not found**:
   - The script automatically adds the Bitnami repository
   - Run `helm repo update` if you encounter issues

3. **Ingress not working**:
   - Ensure nginx ingress controller is installed in your cluster
   - Verify DNS configuration points `rabbitmq.aunlocked.com` to your ingress IP
   - Check ingress status: `kubectl get ingress -n coffee-cluster-services`

4. **Pods not starting**:
   - Check resource availability in your cluster
   - Verify persistent volume provisioning
   - Check pod events: `kubectl describe pod rabbitmq-coffee-0 -n coffee-cluster-services`

5. **Management UI not accessible**:
   - Verify ingress configuration and DNS
   - Check if RabbitMQ management plugin is enabled
   - Test with port-forward: `kubectl port-forward rabbitmq-coffee-0 15672:15672 -n coffee-cluster-services`

### Logs and Debugging

Check pod logs:
```bash
kubectl logs -n coffee-cluster-services rabbitmq-coffee-0
kubectl logs -n coffee-cluster-services rabbitmq-coffee-1
```

Check Helm release status:
```bash
helm status rabbitmq-coffee -n coffee-cluster-services
```

Monitor RabbitMQ cluster status:
```bash
# Port-forward and check cluster status
kubectl port-forward rabbitmq-coffee-0 15672:15672 -n coffee-cluster-services
# Then visit http://localhost:15672 and check cluster tab
```

## Security Considerations

### Current Security Features
- **No plaintext passwords** in configuration files
- **Kubernetes secrets** for sensitive data
- **RBAC enabled** for service account permissions
- **Non-root container execution** with security contexts
- **Network policies** enabled for traffic control

### Production Recommendations
- **Enable TLS/SSL** for both AMQP and management interface
- **Use strong passwords** and rotate them regularly
- **Implement network policies** to restrict traffic
- **Enable audit logging** in RabbitMQ
- **Use external secret management** (AWS Secrets Manager, etc.)
- **Set up monitoring and alerting** for cluster health

### Security Best Practices
```bash
# Enable TLS in rabbitmq-values.yaml
ingress:
  tls: true
  hostname: "rabbitmq.aunlocked.com"

# Use cert-manager for automatic certificate management
# Add annotations for cert-manager in ingress section
```

## Monitoring and Maintenance

### Health Checks
```bash
# Check RabbitMQ cluster health
kubectl exec rabbitmq-coffee-0 -n coffee-cluster-services -- rabbitmqctl cluster_status

# Check node status
kubectl exec rabbitmq-coffee-0 -n coffee-cluster-services -- rabbitmqctl node_health_check
```

### Backup and Recovery
```bash
# Export definitions (exchanges, queues, users, etc.)
kubectl exec rabbitmq-coffee-0 -n coffee-cluster-services -- rabbitmqctl export_definitions /tmp/definitions.json
```

## Support

For issues related to:
- **Bitnami RabbitMQ Chart**: Check the [official documentation](https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq)
- **RabbitMQ**: Refer to [RabbitMQ documentation](https://www.rabbitmq.com/documentation.html)
- **Kubernetes**: Consult [Kubernetes documentation](https://kubernetes.io/docs/)
