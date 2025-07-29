#!/bin/bash

# SoftwareHub - Deploy Simplificado para Debian 12
# Script otimizado para coexistir com outros containers no mesmo hospedeiro

set -e

echo "🚀 SoftwareHub - Deploy Simplificado (Debian 12)"
echo "📅 $(date)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Verificar se é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Execute como root: sudo $0"
        exit 1
    fi
}

# Verificar se é Debian 12
check_debian() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Sistema não suportado"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "debian" ]]; then
        log_warning "Sistema detectado: $ID (esperado: debian)"
        read -p "Continuar? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Sistema: $ID $VERSION"
}

# Instalar Docker se necessário
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "Instalando Docker..."
        
        # Atualizar sistema
        apt update && apt upgrade -y
        
        # Instalar dependências
        apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Adicionar repositório Docker
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Instalar Docker
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Iniciar e habilitar Docker
        systemctl start docker
        systemctl enable docker
        
        log_success "Docker instalado"
    else
        log_success "Docker já instalado"
    fi
}

# Criar diretório da aplicação
setup_app_dir() {
    log_info "Configurando diretório da aplicação..."
    
    mkdir -p /opt/softwarehub
    cd /opt/softwarehub
    
    log_success "Diretório: /opt/softwarehub"
}

# Criar arquivo de ambiente
create_env() {
    log_info "Criando arquivo de ambiente..."
    
    # Gerar senhas seguras
    DB_PASSWORD=$(openssl rand -base64 24)
    JWT_SECRET=$(openssl rand -base64 48)
    
    cat > .env << EOF
# Database
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5432
DB_NAME=softwarehub
DB_USER=softwarehub_user

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=24h

# Application
NODE_ENV=production
PORT=3001
CORS_ORIGIN=http://localhost:8087

# Security
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=1000
SESSION_TIMEOUT=3600000
EOF
    
    chmod 600 .env
    log_success "Arquivo .env criado"
    log_warning "Credenciais salvas em /opt/softwarehub/.env"
}

# Configurar rede Docker para coexistir com outros containers
setup_network() {
    log_info "Configurando rede Docker..."
    
    # Criar rede dedicada para o SoftwareHub
    docker network create softwarehub-network 2>/dev/null || true
    
    log_success "Rede softwarehub-network criada"
}

# Copiar arquivos da aplicação
copy_app_files() {
    log_info "Copiando arquivos da aplicação..."
    
    # Copiar todos os arquivos necessários
    cp -r * /opt/softwarehub/ 2>/dev/null || true
    
    # Garantir permissões corretas
    chmod +x /opt/softwarehub/scripts/*.sh
    
    log_success "Arquivos copiados"
}

# Fazer deploy da aplicação
deploy_app() {
    log_info "Fazendo deploy da aplicação..."
    
    cd /opt/softwarehub
    
    # Parar containers existentes
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # Construir e iniciar
    docker-compose -f docker-compose.prod.yml up -d --build
    
    log_success "Aplicação deployada"
}

# Aguardar serviços ficarem prontos
wait_services() {
    log_info "Aguardando serviços..."
    
    # Aguardar PostgreSQL
    log_info "Aguardando PostgreSQL..."
    timeout=60
    while ! docker-compose -f docker-compose.prod.yml exec -T db pg_isready -U softwarehub_user -d softwarehub &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout PostgreSQL"
            exit 1
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    log_success "PostgreSQL pronto"
    
    # Aguardar Backend
    log_info "Aguardando Backend..."
    timeout=60
    while ! curl -f http://localhost:3001/health &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout Backend"
            exit 1
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    log_success "Backend pronto"
    
    # Aguardar Frontend
    log_info "Aguardando Frontend..."
    timeout=30
    while ! curl -f http://localhost:8087 &> /dev/null; do
        if [[ $timeout -le 0 ]]; then
            log_error "Timeout Frontend"
            exit 1
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    log_success "Frontend pronto"
}

# Criar serviço systemd
create_service() {
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

# Configurar firewall básico
setup_firewall() {
    log_info "Configurando firewall..."
    
    # Instalar ufw se não estiver
    if ! command -v ufw &> /dev/null; then
        apt install -y ufw
    fi
    
    # Configurar firewall
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 8087/tcp
    ufw allow 3001/tcp
    
    log_success "Firewall configurado"
}

# Criar script de backup
create_backup() {
    log_info "Criando script de backup..."
    
    cat > /opt/softwarehub/backup.sh << 'EOF'
#!/bin/bash

# SoftwareHub Backup
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/softwarehub/backups"
mkdir -p $BACKUP_DIR

# Backup database
docker-compose -f /opt/softwarehub/docker-compose.prod.yml exec -T db pg_dump -U softwarehub_user softwarehub > $BACKUP_DIR/db_backup_$DATE.sql

# Backup application files
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz -C /opt/softwarehub .

# Manter apenas últimos 7 dias
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF
    
    chmod +x /opt/softwarehub/backup.sh
    
    # Adicionar ao crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/softwarehub/backup.sh") | crontab -
    
    log_success "Script de backup criado"
}

# Mostrar status final
show_status() {
    log_info "Status dos serviços:"
    docker-compose -f /opt/softwarehub/docker-compose.prod.yml ps
    
    echo ""
    log_success "🎉 SoftwareHub está rodando!"
    echo ""
    log_info "📋 Informações de Acesso:"
    echo "   • Frontend: http://localhost:8087"
    echo "   • API: http://localhost:3001"
    echo "   • Health Check: http://localhost:3001/health"
    echo ""
    log_info "🔐 Credenciais Padrão:"
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

# Função principal
main() {
    log_info "=== SoftwareHub - Deploy Simplificado (Debian 12) ==="
    
    check_root
    check_debian
    install_docker
    setup_app_dir
    create_env
    setup_network
    copy_app_files
    deploy_app
    wait_services
    create_service
    setup_firewall
    create_backup
    show_status
}

# Tratamento de erros
trap 'log_error "Deploy falhou! Verifique os logs acima."; exit 1' ERR

# Executar função principal
main "$@"