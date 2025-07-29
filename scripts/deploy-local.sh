#!/bin/bash

# SoftwareHub - Deploy Local (Ubuntu 24)
# Script para deploy local em ambiente Ubuntu 24

set -e

echo "🚀 SoftwareHub - Deploy Local (Ubuntu 24)"
echo "📅 $(date)"
echo ""

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

# Check if running on Ubuntu
check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Não foi possível detectar o sistema operacional"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "Este script foi projetado para Ubuntu. Sistema detectado: $ID"
        read -p "Continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Sistema Ubuntu detectado: $VERSION"
}

# Install Docker and Docker Compose
install_docker() {
    log_info "Instalando Docker e Docker Compose..."
    
    # Update package list
    sudo apt update
    
    # Install prerequisites
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker instalado com sucesso"
}

# Check Docker installation
check_docker() {
    log_info "Verificando instalação do Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado"
        log_info "Instalando Docker..."
        install_docker
        log_warning "Por favor, faça logout e login novamente para aplicar as permissões do Docker"
        log_info "Ou execute: newgrp docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose não está instalado"
        exit 1
    fi
    
    log_success "Docker e Docker Compose verificados"
}

# Create environment file
create_env() {
    log_info "Criando arquivo de ambiente..."
    
    if [[ ! -f .env ]]; then
        cat > .env << EOF
# Database
DB_PASSWORD=softwarehub123
DB_HOST=localhost
DB_PORT=5432
DB_NAME=softwarehub
DB_USER=softwarehub_user

# JWT
JWT_SECRET=dev_jwt_secret_key_123
JWT_EXPIRES_IN=24h

# Application
NODE_ENV=development
PORT=3001
CORS_ORIGIN=http://localhost:8087

# Security
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=1000
SESSION_TIMEOUT=3600000
EOF
        log_success "Arquivo .env criado"
    else
        log_warning "Arquivo .env já existe"
    fi
}

# Build and start services
deploy_services() {
    log_info "Construindo e iniciando serviços..."
    
    # Stop existing containers
    docker-compose -f docker-compose.dev.yml down 2>/dev/null || true
    
    # Build and start services
    docker-compose -f docker-compose.dev.yml up -d --build
    
    log_success "Serviços iniciados"
}

# Wait for services to be ready
wait_for_services() {
    log_info "Aguardando serviços ficarem prontos..."
    
    # Wait for database
    log_info "Aguardando PostgreSQL..."
    timeout=60
    while ! docker-compose -f docker-compose.dev.yml exec -T db pg_isready -U softwarehub_user -d softwarehub &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout aguardando PostgreSQL"
            exit 1
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    log_success "PostgreSQL pronto"
    
    # Wait for backend
    log_info "Aguardando Backend..."
    timeout=60
    while ! curl -f http://localhost:3001/health &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout aguardando Backend"
            exit 1
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    log_success "Backend pronto"
    
    # Wait for frontend
    log_info "Aguardando Frontend..."
    timeout=30
    while ! curl -f http://localhost:8087 &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout aguardando Frontend"
            exit 1
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    log_success "Frontend pronto"
}

# Show status
show_status() {
    log_info "Status dos serviços:"
    docker-compose -f docker-compose.dev.yml ps
    
    echo ""
    log_success "🎉 SoftwareHub está rodando!"
    echo ""
    log_info "📋 Informações de Acesso:"
    echo "   • Frontend: http://localhost:8087"
    echo "   • API: http://localhost:3001/api"
    echo "   • Health Check: http://localhost:3001/health"
    echo ""
    log_info "🔐 Credenciais:"
    echo "   • Email: admin@softwarehub.com"
    echo "   • Senha: admin123"
    echo ""
    log_info "🔧 Comandos Úteis:"
    echo "   • Ver logs: docker-compose -f docker-compose.dev.yml logs -f"
    echo "   • Parar: docker-compose -f docker-compose.dev.yml down"
    echo "   • Reiniciar: docker-compose -f docker-compose.dev.yml restart"
    echo ""
}

# Main deployment
main() {
    log_info "=== SoftwareHub - Deploy Local (Ubuntu 24) ==="
    
    check_ubuntu
    check_docker
    create_env
    deploy_services
    wait_for_services
    show_status
}

# Error handling
trap 'log_error "Deploy falhou! Verifique os logs acima."; exit 1' ERR

# Run main function
main "$@" 