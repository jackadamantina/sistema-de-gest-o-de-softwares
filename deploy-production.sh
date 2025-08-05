#!/bin/bash

# Script simplificado de deploy para produção
# Todas as configurações já vêm pré-definidas

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Sistema de Gestão de Softwares - Deploy     ${NC}"
echo -e "${CYAN}================================================${NC}"

# Mostrar versão atual
CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
echo -e "${BLUE}Versão atual: ${YELLOW}v${CURRENT_VERSION}${NC}"
echo ""

# Verificar se há uma versão rodando
echo -e "${BLUE}🔍 Verificando versão em execução...${NC}"
if [ -f "scripts/check-version.sh" ]; then
    ./scripts/check-version.sh
    echo ""
fi

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, execute como root (sudo)${NC}"
    exit 1
fi

# Valores padrão pré-configurados
DEFAULT_INSTALL_DIR="/opt/sistema-gestao-softwares"
DEFAULT_FRONTEND_PORT="8089"
DEFAULT_BACKEND_PORT="3002"
DB_PORT="5435"  # Porta fixa do PostgreSQL
DB_PASSWORD="SoftwareHub@2024Secure"  # Senha padrão do banco
JWT_SECRET="DefaultJWTSecretChangeInProduction2024"  # JWT padrão

# Verificar se deve incrementar versão
echo -e "${YELLOW}=== Controle de Versão ===${NC}"
read -p "Incrementar versão antes do deploy? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    if [ -f "scripts/bump-version.sh" ]; then
        echo "Escolha o tipo de incremento:"
        echo "1) Patch (1.0.0 → 1.0.1) - Correções"
        echo "2) Minor (1.0.0 → 1.1.0) - Novos recursos"
        echo "3) Major (1.0.0 → 2.0.0) - Mudanças grandes"
        read -p "Opção (1-3): " VERSION_TYPE
        
        case $VERSION_TYPE in
            1) ./scripts/bump-version.sh patch ;;
            2) ./scripts/bump-version.sh minor ;;
            3) ./scripts/bump-version.sh major ;;
            *) ./scripts/bump-version.sh patch ;;
        esac
        
        # Atualizar versão
        CURRENT_VERSION=$(cat VERSION)
        echo -e "${GREEN}Nova versão: v${CURRENT_VERSION}${NC}"
    fi
fi

echo ""
# Solicitar apenas informações essenciais
echo -e "${YELLOW}=== Configuração do Deploy ===${NC}"
echo ""
echo -e "${BLUE}Configurações pré-definidas:${NC}"
echo "- Porta PostgreSQL: 5435"
echo "- Senha do banco: [Configurada automaticamente]"
echo "- JWT Secret: [Configurado automaticamente]"
echo ""

# Diretório de instalação
read -p "Diretório de instalação (padrão: $DEFAULT_INSTALL_DIR): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}

# Porta do Frontend
read -p "Porta do Frontend (padrão: $DEFAULT_FRONTEND_PORT): " FRONTEND_PORT
FRONTEND_PORT=${FRONTEND_PORT:-$DEFAULT_FRONTEND_PORT}

# Porta do Backend
read -p "Porta do Backend API (padrão: $DEFAULT_BACKEND_PORT): " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-$DEFAULT_BACKEND_PORT}

# URL do sistema
read -p "URL do sistema (ex: sistema.empresa.com): " APP_DOMAIN
if [ -z "$APP_DOMAIN" ]; then
    APP_URL="http://localhost:${FRONTEND_PORT}"
    API_URL="http://localhost:${BACKEND_PORT}"
else
    APP_URL="http://${APP_DOMAIN}:${FRONTEND_PORT}"
    API_URL="http://${APP_DOMAIN}:${BACKEND_PORT}"
fi

# Resumo da configuração
echo ""
echo -e "${YELLOW}=== Resumo da Configuração ===${NC}"
echo -e "${BLUE}Diretório:${NC} $INSTALL_DIR"
echo -e "${BLUE}Frontend:${NC} $APP_URL"
echo -e "${BLUE}Backend API:${NC} $API_URL"
echo -e "${BLUE}PostgreSQL:${NC} localhost:$DB_PORT"
echo ""
read -p "Confirma as configurações? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}Deploy cancelado${NC}"
    exit 1
fi

# Criar diretório
echo ""
echo -e "${YELLOW}1. Criando diretório de instalação...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Copiar arquivos do projeto
echo -e "${YELLOW}2. Copiando arquivos do projeto...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Copiar estrutura mantendo permissões
cp -r "$PROJECT_DIR"/{backend,frontend,scripts,*.yml,*.html,*.md} "$INSTALL_DIR/" 2>/dev/null || true

# Verificar se docker-compose.production.yml existe
if [ ! -f "$INSTALL_DIR/docker-compose.production.yml" ]; then
    echo -e "${RED}Erro: docker-compose.production.yml não encontrado!${NC}"
    exit 1
fi

# Criar arquivo .env
echo -e "${YELLOW}3. Criando arquivo de configuração...${NC}"
cat > .env << EOF
# ===================================
# Configurações de Produção
# ===================================

# Database
DB_PASSWORD=${DB_PASSWORD}
DATABASE_URL=postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub

# Security
JWT_SECRET=${JWT_SECRET}

# Environment
NODE_ENV=production

# Ports
FRONTEND_PORT=${FRONTEND_PORT}
BACKEND_PORT=${BACKEND_PORT}

# URLs
APP_URL=${APP_URL}
API_URL=${API_URL}
EOF

chmod 600 .env
echo -e "${GREEN}✓ Arquivo .env criado${NC}"

# Verificar Docker
echo -e "${YELLOW}4. Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker não encontrado!${NC}"
    echo "Instale o Docker primeiro: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose não encontrado!${NC}"
    echo "Instalando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Verificar portas
echo -e "${YELLOW}5. Verificando disponibilidade das portas...${NC}"
for port in $FRONTEND_PORT $BACKEND_PORT $DB_PORT; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}Porta $port já está em uso!${NC}"
        echo "Processos usando a porta:"
        lsof -i :$port
        exit 1
    fi
done
echo -e "${GREEN}✓ Todas as portas estão livres${NC}"

# Build e deploy
echo -e "${YELLOW}6. Construindo e iniciando containers...${NC}"

# Copiar arquivo VERSION para o diretório backend antes do build
if [ -f "VERSION" ]; then
    echo -e "${BLUE}📋 Copiando arquivo VERSION para o backend...${NC}"
    cp VERSION backend/VERSION
    echo -e "${BLUE}   Versão: $(cat VERSION)${NC}"
else
    echo -e "${YELLOW}⚠️  Arquivo VERSION não encontrado${NC}"
fi

docker-compose -f docker-compose.production.yml build
docker-compose -f docker-compose.production.yml up -d

# Aguardar inicialização
echo -e "${YELLOW}7. Aguardando serviços iniciarem...${NC}"
sleep 15

# Verificar status
echo -e "${YELLOW}8. Verificando status dos serviços...${NC}"
docker-compose -f docker-compose.production.yml ps

# Criar serviço systemd
echo -e "${YELLOW}9. Configurando serviço do sistema...${NC}"
cat > /etc/systemd/system/softwarehub.service << EOF
[Unit]
Description=Sistema de Gestão de Softwares
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
ExecReload=/usr/local/bin/docker-compose -f docker-compose.production.yml restart

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable softwarehub.service
echo -e "${GREEN}✓ Serviço configurado${NC}"

# Configurar backup
echo -e "${YELLOW}10. Configurando backup automático...${NC}"
BACKUP_SCRIPT="/usr/local/bin/softwarehub-backup.sh"
cat > "$BACKUP_SCRIPT" << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/softwarehub"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Backup do banco de dados
docker exec sistema-gestao-softwares-db-1 pg_dump -U softwarehub_user softwarehub | gzip > "$BACKUP_DIR/db_backup_$DATE.sql.gz"

# Manter apenas os últimos 7 backups
find "$BACKUP_DIR" -name "db_backup_*.sql.gz" -mtime +7 -delete

echo "Backup concluído: $BACKUP_DIR/db_backup_$DATE.sql.gz"
EOF

chmod +x "$BACKUP_SCRIPT"

# Adicionar ao crontab
(crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_SCRIPT > /var/log/softwarehub-backup.log 2>&1") | crontab -
echo -e "${GREEN}✓ Backup automático configurado${NC}"

# Informações finais
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✓ Deploy Concluído com Sucesso!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}URLs de Acesso:${NC}"
echo "Sistema Web: $APP_URL"
echo "API Backend: $API_URL"
echo ""
echo -e "${BLUE}Credenciais Padrão:${NC}"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"
echo ""
echo -e "${BLUE}Comandos Úteis:${NC}"
echo "Ver status: docker-compose -f docker-compose.production.yml ps"
echo "Ver logs: docker-compose -f docker-compose.production.yml logs -f"
echo "Parar sistema: systemctl stop softwarehub"
echo "Iniciar sistema: systemctl start softwarehub"
echo "Backup manual: $BACKUP_SCRIPT"
echo ""
echo -e "${YELLOW}IMPORTANTE:${NC}"
echo "1. Altere a senha padrão do admin após o primeiro login"
echo "2. Configure um certificado SSL para produção"
echo "3. Ajuste as configurações de firewall conforme necessário"