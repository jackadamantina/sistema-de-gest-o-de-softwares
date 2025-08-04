#!/bin/bash

# SoftwareHub - Start Local
# Script para iniciar o sistema localmente evitando conflitos de portas

set -e

echo "🚀 SoftwareHub - Start Local"
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

# Check Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado"
        log_info "Instale o Docker primeiro: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose não está instalado"
        log_info "Instale o Docker Compose primeiro"
        exit 1
    fi
    
    log_success "Docker e Docker Compose verificados"
}

# Check port conflicts
check_ports() {
    log_info "Verificando conflitos de portas..."
    
    # Check if ports are in use
    if lsof -Pi :3002 -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Porta 3002 já está em uso"
        log_info "Parando containers conflitantes..."
        docker-compose -f docker-compose.local.yml down 2>/dev/null || true
    fi
    
    if lsof -Pi :5435 -sTCP:LISTEN -t >/dev/null 2>&1; then
    log_error "Porta 5435 já está em uso"
        log_info "Parando containers conflitantes..."
        docker-compose -f docker-compose.local.yml down 2>/dev/null || true
    fi
    
    if lsof -Pi :8088 -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Porta 8088 já está em uso"
        log_info "Parando containers conflitantes..."
        docker-compose -f docker-compose.local.yml down 2>/dev/null || true
    fi
    
    log_success "Portas verificadas"
}

# Create environment file
create_env() {
    log_info "Criando arquivo de ambiente..."
    
    if [[ ! -f .env ]]; then
        cat > .env << EOF
# Database
DB_PASSWORD=softwarehub123
DB_HOST=localhost
DB_PORT=5435
DB_NAME=softwarehub
DB_USER=softwarehub_user

# JWT
JWT_SECRET=dev_jwt_secret_key_123
JWT_EXPIRES_IN=24h

# Application
NODE_ENV=development
PORT=3002
CORS_ORIGIN=http://localhost:8088

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

# Start services
start_services() {
    log_info "Iniciando serviços..."
    
    # Stop existing containers
    docker-compose -f docker-compose.local.yml down 2>/dev/null || true
    
    # Start services
    docker-compose -f docker-compose.local.yml up -d --build
    
    log_success "Serviços iniciados"
}

# Wait for services
wait_for_services() {
    log_info "Aguardando serviços ficarem prontos..."
    
    # Wait for database
    log_info "Aguardando PostgreSQL..."
    timeout=60
    while ! docker-compose -f docker-compose.local.yml exec -T db pg_isready -U softwarehub_user -d softwarehub &> /dev/null; do
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
    while ! curl -f http://localhost:3002/health &> /dev/null; do
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
    while ! curl -f http://localhost:8088 &> /dev/null; do
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
    docker-compose -f docker-compose.local.yml ps
    
    echo ""
    log_success "🎉 SoftwareHub está rodando!"
    echo ""
    log_info "📋 Informações de Acesso:"
    echo "   • Frontend: http://localhost:8088"
    echo "   • API: http://localhost:3002/api"
    echo "   • Health Check: http://localhost:3002/health"
    echo ""
    log_info "🔐 Credenciais:"
    echo "   • Email: admin@softwarehub.com"
    echo "   • Senha: admin123"
    echo ""
    log_info "🔧 Comandos Úteis:"
    echo "   • Ver logs: docker-compose -f docker-compose.local.yml logs -f"
    echo "   • Parar: docker-compose -f docker-compose.local.yml down"
    echo "   • Reiniciar: docker-compose -f docker-compose.local.yml restart"
    echo ""
    log_info "🌐 Abrindo no navegador..."
    
    # Try to open browser
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:8088
    elif command -v open &> /dev/null; then
        open http://localhost:8088
    elif command -v start &> /dev/null; then
        start http://localhost:8088
    else
        log_info "Abra manualmente: http://localhost:8088"
    fi
}

# Main function
main() {
    log_info "=== SoftwareHub - Start Local ==="
    
    check_docker
    check_ports
    create_env
    start_services
    wait_for_services
    show_status
}

# Error handling
trap 'log_error "Start local falhou! Verifique os logs acima."; exit 1' ERR

# Run main function
main "$@" 