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
echo ""

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

# Sempre criar docker-compose.production.yml novo com porta 5435
echo -e "${YELLOW}Criando docker-compose.production.yml com porta 5435...${NC}"
cat > "$INSTALL_DIR/docker-compose.production.yml" << 'EOFDOCKER'
services:
  db:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_DB: softwarehub
      POSTGRES_USER: softwarehub_user
      POSTGRES_PASSWORD: ${DB_PASSWORD:-SoftwareHub@2024Secure}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5435:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U softwarehub_user -d softwarehub"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  backend:
    build: 
      context: ./backend
      dockerfile: Dockerfile
    restart: always
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql://softwarehub_user:${DB_PASSWORD:-SoftwareHub@2024Secure}@db:5432/softwarehub
      JWT_SECRET: ${JWT_SECRET:-DefaultJWTSecretChangeInProduction2024}
      NODE_ENV: production
      PORT: 3002
    ports:
      - "${BACKEND_PORT:-3002}:3002"
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./uploads:/app/uploads
    networks:
      - app-network
    command: >
      sh -c "
        echo 'Aguardando banco de dados...' &&
        sleep 5 &&
        echo 'Gerando Prisma Client...' &&
        npx prisma generate &&
        echo 'Aplicando migrações...' &&
        npx prisma migrate deploy &&
        echo 'Iniciando servidor...' &&
        node dist/server.js
      "

  frontend:
    build: 
      context: ./frontend
      dockerfile: Dockerfile
    restart: always
    ports:
      - "${FRONTEND_PORT:-8089}:80"
    depends_on:
      - backend
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
      - ./frontend/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - app-network

volumes:
  postgres_data:
    driver: local

networks:
  app-network:
    driver: bridge
EOFDOCKER

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