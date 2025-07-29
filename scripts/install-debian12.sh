#!/bin/bash

# SoftwareHub - Instalação Rápida para Debian 12
# Script completo para instalar e configurar o SoftwareHub

set -e

echo "🚀 SoftwareHub - Instalação Rápida (Debian 12)"
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

# Verificar sistema
check_system() {
    log_info "Verificando sistema..."
    
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

# Atualizar sistema
update_system() {
    log_info "Atualizando sistema..."
    apt update && apt upgrade -y
    log_success "Sistema atualizado"
}

# Instalar dependências
install_dependencies() {
    log_info "Instalando dependências..."
    
    apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        net-tools \
        ufw \
        openssl \
        cron \
        htop \
        tree
    
    log_success "Dependências instaladas"
}

# Instalar Docker
install_docker() {
    log_info "Instalando Docker..."
    
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
}

# Configurar Docker
setup_docker() {
    log_info "Configurando Docker..."
    
    # Criar arquivo de configuração
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    
    # Reiniciar Docker
    systemctl restart docker
    
    log_success "Docker configurado"
}

# Criar diretório da aplicação
setup_app_dir() {
    log_info "Configurando diretório da aplicação..."
    
    mkdir -p /opt/softwarehub
    mkdir -p /opt/softwarehub/data/postgres
    mkdir -p /opt/softwarehub/data/uploads
    mkdir -p /opt/softwarehub/logs
    mkdir -p /opt/softwarehub/backups
    
    cd /opt/softwarehub
    
    log_success "Diretório configurado: /opt/softwarehub"
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

# Configurar rede Docker
setup_network() {
    log_info "Configurando rede Docker..."
    
    # Criar rede dedicada
    docker network create --driver bridge --subnet=172.20.0.0/16 softwarehub-network 2>/dev/null || true
    
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

# Aguardar serviços
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

# Configurar firewall
setup_firewall() {
    log_info "Configurando firewall..."
    
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 8087/tcp
    ufw allow 3001/tcp
    
    log_success "Firewall configurado"
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

# Configurar monitoramento
setup_monitoring() {
    log_info "Configurando monitoramento..."
    
    # Criar script de monitoramento
    cat > /opt/softwarehub/monitor.sh << 'EOF'
#!/bin/bash

# SoftwareHub - Monitor de Recursos
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== SoftwareHub Monitor - $DATE ==="

# Status dos containers
echo "📊 Status dos Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep softwarehub || echo "Nenhum container SoftwareHub rodando"

# Uso de recursos
echo ""
echo "💾 Uso de Recursos:"
echo "Memória: $(free -h | awk 'NR==2{print $3"/"$2}')"
echo "Disco: $(df -h / | awk 'NR==2{print $3"/"$2}')"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"

# Logs recentes
echo ""
echo "📝 Logs Recentes (últimas 10 linhas):"
docker-compose -f /opt/softwarehub/docker-compose.prod.yml logs --tail=10 2>/dev/null || echo "Nenhum log disponível"

echo ""
echo "=================================="
EOF
    
    chmod +x /opt/softwarehub/monitor.sh
    
    # Adicionar ao crontab
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/softwarehub/monitor.sh >> /opt/softwarehub/logs/monitor.log 2>&1") | crontab -
    
    log_success "Monitoramento configurado"
}

# Configurar backup
setup_backup() {
    log_info "Configurando backup automático..."
    
    cat > /opt/softwarehub/backup.sh << 'EOF'
#!/bin/bash

# SoftwareHub - Backup Automático
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/softwarehub/backups"
LOG_FILE="/opt/softwarehub/logs/backup.log"

mkdir -p $BACKUP_DIR
mkdir -p $(dirname $LOG_FILE)

echo "$(date): Iniciando backup automático..." >> $LOG_FILE

# Backup do banco de dados
if docker-compose -f /opt/softwarehub/docker-compose.prod.yml exec -T db pg_isready -U softwarehub_user -d softwarehub &> /dev/null; then
    docker-compose -f /opt/softwarehub/docker-compose.prod.yml exec -T db pg_dump -U softwarehub_user softwarehub > $BACKUP_DIR/db_backup_$DATE.sql
    echo "$(date): Backup do banco concluído" >> $LOG_FILE
else
    echo "$(date): ERRO - Banco não está acessível" >> $LOG_FILE
fi

# Backup dos arquivos da aplicação
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz -C /opt/softwarehub . --exclude=backups --exclude=logs --exclude=node_modules 2>/dev/null
echo "$(date): Backup dos arquivos concluído" >> $LOG_FILE

# Limpar backups antigos (manter 7 dias)
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
echo "$(date): Limpeza de backups antigos concluída" >> $LOG_FILE

echo "$(date): Backup automático concluído" >> $LOG_FILE
EOF
    
    chmod +x /opt/softwarehub/backup.sh
    
    # Agendar backup diário
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/softwarehub/backup.sh") | crontab -
    
    log_success "Backup automático configurado"
}

# Mostrar status final
show_status() {
    log_info "Status dos serviços:"
    docker-compose -f /opt/softwarehub/docker-compose.prod.yml ps
    
    echo ""
    log_success "🎉 SoftwareHub instalado com sucesso!"
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
    echo "   • Monitor: /opt/softwarehub/monitor.sh"
    echo "   • Backup: /opt/softwarehub/backup.sh"
    echo ""
    log_warning "⚠️  IMPORTANTE: Altere a senha do admin após o primeiro login!"
    echo ""
    log_info "📊 Recursos do Sistema:"
    echo "   • CPU: $(nproc) cores"
    echo "   • Memória: $(free -h | awk 'NR==2{print $2}')"
    echo "   • Disco: $(df -h / | awk 'NR==2{print $2}')"
    echo ""
    log_success "✅ Sistema configurado para coexistência com outros containers"
}

# Função principal
main() {
    log_info "=== SoftwareHub - Instalação Rápida (Debian 12) ==="
    
    check_root
    check_system
    update_system
    install_dependencies
    install_docker
    setup_docker
    setup_app_dir
    create_env
    setup_network
    copy_app_files
    deploy_app
    wait_services
    setup_firewall
    create_service
    setup_monitoring
    setup_backup
    show_status
}

# Tratamento de erros
trap 'log_error "Instalação falhou! Verifique os logs acima."; exit 1' ERR

# Executar função principal
main "$@"