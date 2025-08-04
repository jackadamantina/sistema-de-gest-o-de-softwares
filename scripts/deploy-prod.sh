#!/bin/bash

# SoftwareHub - Deploy Produção (Debian 12)
# Script para deploy em produção em ambiente Debian 12

set -e

echo "🚀 SoftwareHub - Deploy Produção (Debian 12)"
echo "📅 $(date)"
echo "🌐 Target URL: http://softwarehub-xp.wake.tech:8087"
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        log_info "Execute: sudo $0"
        exit 1
    fi
}

# Check if running on Debian
check_debian() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Não foi possível detectar o sistema operacional"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "debian" ]]; then
        log_warning "Este script foi projetado para Debian. Sistema detectado: $ID"
        read -p "Continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Sistema Debian detectado: $VERSION"
}

# Update system
update_system() {
    log_info "Atualizando sistema..."
    
    apt update
    apt upgrade -y
    
    log_success "Sistema atualizado"
}

# Install Docker and Docker Compose
install_docker() {
    log_info "Instalando Docker e Docker Compose..."
    
    # Install prerequisites
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker instalado com sucesso"
}

# Check Docker installation
check_docker() {
    log_info "Verificando instalação do Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado"
        log_info "Instalando Docker..."
        install_docker
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose não está instalado"
        exit 1
    fi
    
    log_success "Docker e Docker Compose verificados"
}

# Create application directory
create_app_dir() {
    log_info "Criando diretório da aplicação..."
    
    mkdir -p /opt/softwarehub
    cd /opt/softwarehub
    
    log_success "Diretório criado: /opt/softwarehub"
}

# Create production environment file
create_prod_env() {
    log_info "Criando arquivo de ambiente de produção..."
    
    # Generate secure passwords
    DB_PASSWORD=$(openssl rand -base64 32)
    JWT_SECRET=$(openssl rand -base64 64)
    
    cat > .env << EOF
# Database
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5435
DB_NAME=softwarehub
DB_USER=softwarehub_user

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=24h

# Application
NODE_ENV=production
PORT=3001
CORS_ORIGIN=http://softwarehub-xp.wake.tech:8087

# Security
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=1000
SESSION_TIMEOUT=3600000
EOF
    
    # Secure the env file
    chmod 600 .env
    
    log_success "Arquivo .env de produção criado"
    log_warning "Credenciais salvas em /opt/softwarehub/.env"
}

# Setup firewall
setup_firewall() {
    log_info "Configurando firewall..."
    
    # Install ufw if not present
    if ! command -v ufw &> /dev/null; then
        apt install -y ufw
    fi
    
    # Configure firewall
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 8087/tcp
    ufw allow 3001/tcp
    
    log_success "Firewall configurado"
}

# Create systemd service
create_systemd_service() {
    log_info "Criando serviço systemd..."
    
    cat > /etc/systemd/system/softwarehub.service << EOF
[Unit]
Description=SoftwareHub Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/softwarehub
ExecStart=/usr/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable softwarehub.service
    
    log_success "Serviço systemd criado"
}

# Deploy application
deploy_application() {
    log_info "Fazendo deploy da aplicação..."
    
    # Copy application files
    cp -r * /opt/softwarehub/
    cd /opt/softwarehub
    
    # Build and start services
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    docker-compose -f docker-compose.prod.yml up -d --build
    
    log_success "Aplicação deployada"
}

# Wait for services to be ready
wait_for_services() {
    log_info "Aguardando serviços ficarem prontos..."
    
    # Wait for database
    log_info "Aguardando PostgreSQL..."
    timeout=120
    while ! docker-compose -f docker-compose.prod.yml exec -T db pg_isready -U softwarehub_user -d softwarehub &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout aguardando PostgreSQL"
            exit 1
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    log_success "PostgreSQL pronto"
    
    # Wait for backend
    log_info "Aguardando Backend..."
    timeout=120
    while ! curl -f http://localhost:3001/health &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout aguardando Backend"
            exit 1
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    log_success "Backend pronto"
    
    # Wait for frontend
    log_info "Aguardando Frontend..."
    timeout=60
    while ! curl -f http://localhost:8087 &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout aguardando Frontend"
            exit 1
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    log_success "Frontend pronto"
}

# Create backup script
create_backup_script() {
    log_info "Criando script de backup..."
    
    cat > /opt/softwarehub/backup.sh << 'EOF'
#!/bin/bash

# SoftwareHub Backup Script
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/softwarehub/backups"
mkdir -p $BACKUP_DIR

# Backup database
docker-compose -f /opt/softwarehub/docker-compose.prod.yml exec -T db pg_dump -U softwarehub_user softwarehub > $BACKUP_DIR/db_backup_$DATE.sql

# Backup application files
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz -C /opt/softwarehub .

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF
    
    chmod +x /opt/softwarehub/backup.sh
    
    # Add to crontab for daily backup
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/softwarehub/backup.sh") | crontab -
    
    log_success "Script de backup criado"
}

# Show status
show_status() {
    log_info "Status dos serviços:"
    docker-compose -f /opt/softwarehub/docker-compose.prod.yml ps
    
    echo ""
    log_success "🎉 SoftwareHub está rodando em produção!"
    echo ""
    log_info "📋 Informações de Acesso:"
    echo "   • Frontend: http://softwarehub-xp.wake.tech:8087"
    echo "   • API: http://softwarehub-xp.wake.tech:8087/api"
    echo "   • Health Check: http://softwarehub-xp.wake.tech:8087/health"
    echo ""
    log_info "🔐 Credenciais:"
    echo "   • Email: admin@softwarehub.com"
    echo "   • Senha: admin123"
    echo ""
    log_info "🔧 Comandos Úteis:"
    echo "   • Ver logs: docker-compose -f /opt/softwarehub/docker-compose.prod.yml logs -f"
    echo "   • Parar: systemctl stop softwarehub"
    echo "   • Iniciar: systemctl start softwarehub"
    echo "   • Status: systemctl status softwarehub"
    echo "   • Backup: /opt/softwarehub/backup.sh"
    echo ""
    log_warning "⚠️  IMPORTANTE: Altere a senha do admin após o primeiro login!"
    echo ""
}

# Main deployment
main() {
    log_info "=== SoftwareHub - Deploy Produção (Debian 12) ==="
    
    check_root
    check_debian
    update_system
    check_docker
    create_app_dir
    create_prod_env
    setup_firewall
    create_systemd_service
    deploy_application
    wait_for_services
    create_backup_script
    show_status
}

# Error handling
trap 'log_error "Deploy falhou! Verifique os logs acima."; exit 1' ERR

# Run main function
main "$@" 