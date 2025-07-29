#!/bin/bash

# SoftwareHub - Gerenciador de Containers
# Script para gerenciar coexistência com outros containers no Debian 12

set -e

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

# Verificar portas em uso
check_ports() {
    log_info "Verificando portas em uso..."
    
    local ports=("3001" "5432" "8087")
    local conflicts=()
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            conflicts+=("$port")
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_warning "Portas em conflito detectadas: ${conflicts[*]}"
        echo ""
        log_info "Containers que podem estar usando estas portas:"
        docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "($(IFS='|'; echo "${conflicts[*]}"))" || true
        echo ""
        read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "Nenhum conflito de porta detectado"
    fi
}

# Verificar recursos do sistema
check_resources() {
    log_info "Verificando recursos do sistema..."
    
    # Memória disponível
    local mem_available=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [[ $mem_available -lt 1024 ]]; then
        log_warning "Memória disponível baixa: ${mem_available}MB (recomendado: 1GB+)"
    else
        log_success "Memória disponível: ${mem_available}MB"
    fi
    
    # Espaço em disco
    local disk_available=$(df -BG / | awk 'NR==2{printf "%.0f", $4}' | sed 's/G//')
    if [[ $disk_available -lt 10 ]]; then
        log_warning "Espaço em disco baixo: ${disk_available}GB (recomendado: 10GB+)"
    else
        log_success "Espaço em disco: ${disk_available}GB"
    fi
    
    # Containers rodando
    local containers_running=$(docker ps -q | wc -l)
    log_info "Containers Docker rodando: $containers_running"
}

# Configurar limites de recursos
setup_resource_limits() {
    log_info "Configurando limites de recursos..."
    
    # Criar arquivo de configuração do Docker
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
    
    # Reiniciar Docker se necessário
    if systemctl is-active --quiet docker; then
        systemctl restart docker
        log_success "Docker reiniciado com novos limites"
    fi
}

# Configurar rede isolada
setup_isolated_network() {
    log_info "Configurando rede isolada..."
    
    # Criar rede dedicada para SoftwareHub
    docker network create --driver bridge --subnet=172.20.0.0/16 softwarehub-network 2>/dev/null || true
    
    # Verificar redes existentes
    log_info "Redes Docker existentes:"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    
    log_success "Rede softwarehub-network configurada"
}

# Configurar volumes isolados
setup_isolated_volumes() {
    log_info "Configurando volumes isolados..."
    
    # Criar diretórios para volumes
    mkdir -p /opt/softwarehub/data/postgres
    mkdir -p /opt/softwarehub/data/uploads
    mkdir -p /opt/softwarehub/logs
    
    # Definir permissões
    chown -R 999:999 /opt/softwarehub/data/postgres 2>/dev/null || true
    chmod -R 755 /opt/softwarehub/data
    
    log_success "Volumes isolados configurados"
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
    
    # Adicionar ao crontab para monitoramento a cada 5 minutos
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/softwarehub/monitor.sh >> /opt/softwarehub/logs/monitor.log 2>&1") | crontab -
    
    log_success "Monitoramento configurado"
}

# Configurar backup automático
setup_auto_backup() {
    log_info "Configurando backup automático..."
    
    # Criar script de backup melhorado
    cat > /opt/softwarehub/auto_backup.sh << 'EOF'
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
    
    chmod +x /opt/softwarehub/auto_backup.sh
    
    # Agendar backup diário às 2h da manhã
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/softwarehub/auto_backup.sh") | crontab -
    
    log_success "Backup automático configurado"
}

# Mostrar informações do sistema
show_system_info() {
    log_info "=== Informações do Sistema ==="
    
    echo ""
    log_info "📊 Recursos do Sistema:"
    echo "   • CPU: $(nproc) cores"
    echo "   • Memória: $(free -h | awk 'NR==2{print $2}')"
    echo "   • Disco: $(df -h / | awk 'NR==2{print $2}')"
    
    echo ""
    log_info "🐳 Containers Docker:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "Nenhum container rodando"
    
    echo ""
    log_info "🌐 Redes Docker:"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    
    echo ""
    log_info "💾 Volumes Docker:"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}"
    
    echo ""
    log_info "📁 Diretórios SoftwareHub:"
    ls -la /opt/softwarehub/ 2>/dev/null || echo "Diretório /opt/softwarehub não existe"
    
    echo ""
    log_success "✅ Sistema configurado para coexistência com outros containers"
}

# Função principal
main() {
    log_info "=== SoftwareHub - Gerenciador de Containers ==="
    
    check_ports
    check_resources
    setup_resource_limits
    setup_isolated_network
    setup_isolated_volumes
    setup_monitoring
    setup_auto_backup
    show_system_info
}

# Executar função principal
main "$@"