```yaml
#!/bin/bash

# SoftwareHub Production Deploy Script
# URL: softwarehub-xp.wake.tech:8087

set -e

echo "🚀 Starting SoftwareHub Production Deployment..."
echo "📅 $(date)"
echo "🌐 Target URL: http://softwarehub-xp.wake.tech:8087"
echo ""

# Configuration
NAMESPACE="softwarehub"
REGISTRY="your-registry"  # Update with your Docker registry
VERSION="${1:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check kubectl context
    CURRENT_CONTEXT=$(kubectl config current-context)
    log_info "Current kubectl context: $CURRENT_CONTEXT"
    
    # Verify cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Unable to connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."
    
    # Build backend
    log_info "Building backend image..."
    cd backend
    docker build -t ${REGISTRY}/softwarehub-backend:${VERSION} -f Dockerfile .
    cd ..
    
    # Build frontend
    log_info "Building frontend image..."
    cd frontend
    docker build -t ${REGISTRY}/softwarehub-frontend:${VERSION} -f Dockerfile .
    cd ..
    
    log_success "Docker images built successfully"
}

# Push images to registry
push_images() {
    log_info "Pushing images to registry..."
    
    docker push ${REGISTRY}/softwarehub-backend:${VERSION}
    docker push ${REGISTRY}/softwarehub-frontend:${VERSION}
    
    log_success "Images pushed to registry"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace..."
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace $NAMESPACE
        log_success "Namespace $NAMESPACE created"
    fi
}

# Apply secrets
apply_secrets() {
    log_info "Applying secrets..."
    
    # Check if secrets exist
    if kubectl get secret softwarehub-secrets -n $NAMESPACE &> /dev/null; then
        log_warning "Secrets already exist, skipping creation"
        echo "⚠️  Please ensure secrets are up to date manually"
    else
        log_error "Secrets not found! Please create secrets manually:"
        echo ""
        echo "kubectl create secret generic softwarehub-secrets -n $NAMESPACE \\"
        echo "  --from-literal=DB_PASSWORD='your-secure-db-password' \\"
        echo "  --from-literal=JWT_SECRET='your-super-secure-jwt-secret'"
        echo ""
        read -p "Press Enter to continue after creating secrets..."
    fi
    
    log_success "Secrets applied"
}

# Apply ConfigMaps
apply_configmaps() {
    log_info "Applying ConfigMaps..."
    
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/postgres-init-configmap.yaml
    
    log_success "ConfigMaps applied"
}

# Deploy PostgreSQL
deploy_postgres() {
    log_info "Deploying PostgreSQL..."
    
    kubectl apply -f k8s/postgres-deployment.yaml
    
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/postgres -n $NAMESPACE
    
    # Check PostgreSQL connectivity
    log_info "Verifying PostgreSQL connection..."
    kubectl exec -n $NAMESPACE deployment/postgres -- pg_isready -U softwarehub_user
    
    log_success "PostgreSQL deployed and ready"
}

# Deploy backend
deploy_backend() {
    log_info "Deploying backend..."
    
    # Update image version in deployment
    sed -i.bak "s|image: softwarehub-backend:.*|image: ${REGISTRY}/softwarehub-backend:${VERSION}|g" k8s/backend-deployment.yaml
    
    kubectl apply -f k8s/backend-deployment.yaml
    
    log_info "Waiting for backend to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/backend -n $NAMESPACE
    
    # Test backend health
    log_info "Testing backend health..."
    kubectl exec -n $NAMESPACE deployment/backend -- curl -f http://localhost:3001/health
    
    log_success "Backend deployed and healthy"
}

# Deploy frontend
deploy_frontend() {
    log_info "Deploying frontend..."
    
    # Update image version in deployment
    sed -i.bak "s|image: softwarehub-frontend:.*|image: ${REGISTRY}/softwarehub-frontend:${VERSION}|g" k8s/frontend-deployment.yaml
    
    kubectl apply -f k8s/frontend-deployment.yaml
    
    log_info "Waiting for frontend to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $NAMESPACE
    
    log_success "Frontend deployed successfully"
}

# Deploy Nginx
deploy_nginx() {
    log_info "Deploying Nginx reverse proxy..."
    
    kubectl apply -f k8s/nginx-deployment.yaml
    
    log_info "Waiting for Nginx to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/nginx -n $NAMESPACE
    
    log_success "Nginx deployed successfully"
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."
    
    # Run Prisma migrations
    kubectl exec -n $NAMESPACE deployment/backend -- npx prisma migrate deploy
    
    log_success "Database migrations completed"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check all pods are running
    log_info "Checking pod status..."
    kubectl get pods -n $NAMESPACE
    
    # Check services
    log_info "Checking services..."
    kubectl get services -n $NAMESPACE
    
    # Get external IP/URL
    log_info "Getting external access information..."
    EXTERNAL_IP=$(kubectl get service nginx-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$EXTERNAL_IP" ]; then
        EXTERNAL_IP=$(kubectl get service nginx-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    fi
    
    if [ -n "$EXTERNAL_IP" ]; then
        log_success "Application accessible at: http://$EXTERNAL_IP:8087"
    else
        log_warning "External IP not yet assigned. Check with: kubectl get service nginx-service -n $NAMESPACE"
    fi
    
    # Test health endpoints
    log_info "Testing application health..."
    kubectl exec -n $NAMESPACE deployment/backend -- curl -f http://localhost:3001/health
    
    log_success "Deployment verification completed"
}

# Setup monitoring (optional)
setup_monitoring() {
    log_info "Setting up basic monitoring..."
    
    # Create monitoring ConfigMap
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-config
  namespace: $NAMESPACE
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'softwarehub-backend'
        static_configs:
          - targets: ['backend-service:3001']
EOF

    log_success "Basic monitoring configured"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    find . -name "*.bak" -delete
    log_success "Cleanup completed"
}

# Main deployment flow
main() {
    log_info "=== SoftwareHub Production Deployment ==="
    
    # Confirmation prompt
    echo ""
    log_warning "You are about to deploy SoftwareHub to production!"
    log_warning "Target: $NAMESPACE namespace"
    log_warning "Version: $VERSION"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
    
    # Execute deployment steps
    check_prerequisites
    
    if [[ "${BUILD_IMAGES:-true}" == "true" ]]; then
        build_images
        push_images
    else
        log_warning "Skipping image build (BUILD_IMAGES=false)"
    fi
    
    create_namespace
    apply_secrets
    apply_configmaps
    deploy_postgres
    run_migrations
    deploy_backend
    deploy_frontend
    deploy_nginx
    verify_deployment
    
    if [[ "${SETUP_MONITORING:-false}" == "true" ]]; then
        setup_monitoring
    fi
    
    cleanup
    
    echo ""
    log_success "🎉 SoftwareHub deployment completed successfully!"
    echo ""
    log_info "📋 Deployment Summary:"
    echo "   • Namespace: $NAMESPACE"
    echo "   • Version: $VERSION"
    echo "   • Components: PostgreSQL, Backend API, Frontend, Nginx"
    echo "   • URL: http://softwarehub-xp.wake.tech:8087"
    echo ""
    log_info "📚 Next Steps:"
    echo "   1. Configure DNS to point softwarehub-xp.wake.tech to the LoadBalancer IP"
    echo "   2. Login with admin@softwarehub.com / admin123"
    echo "   3. Change default admin password immediately"
    echo "   4. Configure SSL/TLS certificates if needed"
    echo "   5. Set up backup strategy for PostgreSQL"
    echo ""
    log_info "🔍 Useful Commands:"
    echo "   • View pods: kubectl get pods -n $NAMESPACE"
    echo "   • View logs: kubectl logs -f deployment/backend -n $NAMESPACE"
    echo "   • Port forward: kubectl port-forward service/nginx-service 8087:80 -n $NAMESPACE"
    echo ""
}

# Error handling
trap 'log_error "Deployment failed! Check the logs above for details."; cleanup; exit 1' ERR

# Run main function
main "$@"
```
