#!/bin/bash

# Script de Deploy para Produção - Sistema de Gestão de Softwares
# Para Debian 12 com Docker já instalado
# Autor: Deploy Script
# Data: $(date)

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_message() {
    echo -e "${2}${1}${NC}"
}

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para verificar se uma porta está em uso
port_in_use() {
    lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1
}

print_message "=====================================" "$BLUE"
print_message "Sistema de Gestão de Softwares" "$BLUE"
print_message "Script de Deploy para Produção" "$BLUE"
print_message "=====================================" "$BLUE"
echo ""

# 1. Verificar pré-requisitos
print_message "1. Verificando pré-requisitos..." "$YELLOW"

if ! command_exists docker; then
    print_message "Erro: Docker não está instalado!" "$RED"
    exit 1
fi

if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    print_message "Erro: Docker Compose não está instalado!" "$RED"
    exit 1
fi

if ! command_exists git; then
    print_message "Erro: Git não está instalado!" "$RED"
    exit 1
fi

print_message "✓ Pré-requisitos verificados" "$GREEN"
echo ""

# 2. Configurações de produção
print_message "2. Configurando variáveis de ambiente..." "$YELLOW"

# Diretório de instalação
INSTALL_DIR="/opt/sistema-gestao-softwares"
BACKUP_DIR="/opt/backups/sistema-gestao-softwares"

# Portas padrão (podem ser alteradas se já estiverem em uso)
DEFAULT_WEB_PORT=80
DEFAULT_API_PORT=3002
DEFAULT_DB_PORT=5432

# Solicitar informações do usuário
echo ""
print_message "Por favor, forneça as seguintes informações:" "$BLUE"
echo ""

# Domínio
read -p "Digite o domínio ou IP do servidor (ex: sistema.empresa.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    DOMAIN=$(hostname -I | awk '{print $1}')
    print_message "Usando IP do servidor: $DOMAIN" "$YELLOW"
fi

# Verificar portas disponíveis
read -p "Digite a porta para o frontend (padrão 80): " WEB_PORT
WEB_PORT=${WEB_PORT:-$DEFAULT_WEB_PORT}

if port_in_use $WEB_PORT; then
    print_message "Porta $WEB_PORT já está em uso!" "$RED"
    read -p "Digite outra porta: " WEB_PORT
fi

read -p "Digite a porta para a API (padrão 3002): " API_PORT
API_PORT=${API_PORT:-$DEFAULT_API_PORT}

if port_in_use $API_PORT; then
    print_message "Porta $API_PORT já está em uso!" "$RED"
    read -p "Digite outra porta: " API_PORT
fi

read -p "Digite a porta para o PostgreSQL (padrão 5432): " DB_PORT
DB_PORT=${DB_PORT:-$DEFAULT_DB_PORT}

if port_in_use $DB_PORT; then
    print_message "Porta $DB_PORT já está em uso!" "$RED"
    read -p "Digite outra porta: " DB_PORT
fi

# Senhas
read -sp "Digite a senha para o banco de dados PostgreSQL: " DB_PASSWORD
echo ""
read -sp "Digite o JWT Secret (deixe em branco para gerar automaticamente): " JWT_SECRET
echo ""

if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 32)
    print_message "JWT Secret gerado automaticamente" "$GREEN"
fi

# Email do administrador
read -p "Digite o email do administrador (padrão: admin@$DOMAIN): " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@$DOMAIN"}

echo ""
print_message "✓ Configurações definidas" "$GREEN"
echo ""

# 3. Criar estrutura de diretórios
print_message "3. Criando estrutura de diretórios..." "$YELLOW"

sudo mkdir -p $INSTALL_DIR
sudo mkdir -p $BACKUP_DIR
sudo mkdir -p $INSTALL_DIR/data/postgres
sudo mkdir -p $INSTALL_DIR/logs

print_message "✓ Diretórios criados" "$GREEN"
echo ""

# 4. Clonar ou atualizar repositório
print_message "4. Obtendo código fonte..." "$YELLOW"

cd /tmp
if [ -d "sistema-gestao-softwares-temp" ]; then
    rm -rf sistema-gestao-softwares-temp
fi

# Como não temos um repositório Git, vamos copiar os arquivos locais
# Assumindo que o script está sendo executado no diretório do projeto
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    print_message "Erro: docker-compose.yml não encontrado no diretório atual!" "$RED"
    print_message "Execute este script no diretório raiz do projeto." "$YELLOW"
    exit 1
fi

# Copiar arquivos necessários
sudo cp -r "$SCRIPT_DIR"/* $INSTALL_DIR/
sudo cp -r "$SCRIPT_DIR"/.* $INSTALL_DIR/ 2>/dev/null || true

print_message "✓ Código fonte copiado" "$GREEN"
echo ""

# 5. Criar arquivo de configuração do Docker Compose para produção
print_message "5. Criando configuração Docker Compose para produção..." "$YELLOW"

cat > $INSTALL_DIR/docker-compose.production.yml << EOF
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_DB: softwarehub
      POSTGRES_USER: softwarehub_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "${DB_PORT}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U softwarehub_user -d softwarehub"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app-network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    restart: always
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub
      JWT_SECRET: ${JWT_SECRET}
      PORT: 3002
      CORS_ORIGIN: http://${DOMAIN}:${WEB_PORT}
    ports:
      - "${API_PORT}:3002"
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./logs:/app/logs
    networks:
      - app-network

  frontend:
    build:
      context: .
      dockerfile: frontend/Dockerfile
    restart: always
    ports:
      - "${WEB_PORT}:80"
    volumes:
      - ./frontend/nginx.production.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - backend
    networks:
      - app-network

volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${INSTALL_DIR}/data/postgres

networks:
  app-network:
    driver: bridge
EOF

print_message "✓ Arquivo docker-compose.production.yml criado" "$GREEN"
echo ""

# 6. Criar configuração Nginx para produção
print_message "6. Criando configuração Nginx para produção..." "$YELLOW"

cat > $INSTALL_DIR/frontend/nginx.production.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml;
    gzip_disable "MSIE [1-6]\.";

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://backend:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

print_message "✓ Configuração Nginx criada" "$GREEN"
echo ""

# 7. Criar arquivo .env para produção
print_message "7. Criando arquivo .env..." "$YELLOW"

cat > $INSTALL_DIR/.env << EOF
# Environment
NODE_ENV=production

# Database
DATABASE_URL=postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub

# JWT
JWT_SECRET=${JWT_SECRET}

# API
PORT=3002
CORS_ORIGIN=http://${DOMAIN}:${WEB_PORT}

# Admin
ADMIN_EMAIL=${ADMIN_EMAIL}
EOF

chmod 600 $INSTALL_DIR/.env
print_message "✓ Arquivo .env criado" "$GREEN"
echo ""

# 8. Criar script de backup
print_message "8. Criando script de backup..." "$YELLOW"

cat > $INSTALL_DIR/backup.sh << 'EOF'
#!/bin/bash

# Script de backup do Sistema de Gestão de Softwares

BACKUP_DIR="/opt/backups/sistema-gestao-softwares"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.tar.gz"
DB_BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql"

# Criar diretório de backup se não existir
mkdir -p $BACKUP_DIR

# Backup do banco de dados
echo "Fazendo backup do banco de dados..."
docker exec sistema-gestao-softwares-db-1 pg_dump -U softwarehub_user softwarehub > $DB_BACKUP_FILE

# Backup dos arquivos
echo "Fazendo backup dos arquivos..."
tar -czf $BACKUP_FILE /opt/sistema-gestao-softwares/data --exclude='*.log'

# Remover backups antigos (manter últimos 7 dias)
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete

echo "Backup concluído: $BACKUP_FILE"
echo "Backup do banco: $DB_BACKUP_FILE"
EOF

chmod +x $INSTALL_DIR/backup.sh
print_message "✓ Script de backup criado" "$GREEN"
echo ""

# 9. Configurar cron para backup automático
print_message "9. Configurando backup automático..." "$YELLOW"

(crontab -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/backup.sh > $INSTALL_DIR/logs/backup.log 2>&1") | crontab -

print_message "✓ Backup automático configurado (diariamente às 2h)" "$GREEN"
echo ""

# 10. Build e iniciar containers
print_message "10. Construindo e iniciando containers..." "$YELLOW"

cd $INSTALL_DIR

# Parar containers se existirem
docker-compose -f docker-compose.production.yml down 2>/dev/null || true

# Build das imagens
docker-compose -f docker-compose.production.yml build

# Iniciar containers
docker-compose -f docker-compose.production.yml up -d

print_message "✓ Containers iniciados" "$GREEN"
echo ""

# 11. Aguardar serviços iniciarem
print_message "11. Aguardando serviços iniciarem..." "$YELLOW"

sleep 10

# Verificar status dos containers
docker-compose -f docker-compose.production.yml ps

print_message "✓ Serviços prontos" "$GREEN"
echo ""

# 12. Criar script de gerenciamento
print_message "12. Criando script de gerenciamento..." "$YELLOW"

cat > /usr/local/bin/sistema-gestao << EOF
#!/bin/bash

# Script de gerenciamento do Sistema de Gestão de Softwares

INSTALL_DIR="/opt/sistema-gestao-softwares"

case "\$1" in
    start)
        echo "Iniciando Sistema de Gestão de Softwares..."
        cd \$INSTALL_DIR && docker-compose -f docker-compose.production.yml up -d
        ;;
    stop)
        echo "Parando Sistema de Gestão de Softwares..."
        cd \$INSTALL_DIR && docker-compose -f docker-compose.production.yml down
        ;;
    restart)
        echo "Reiniciando Sistema de Gestão de Softwares..."
        cd \$INSTALL_DIR && docker-compose -f docker-compose.production.yml restart
        ;;
    status)
        echo "Status do Sistema de Gestão de Softwares:"
        cd \$INSTALL_DIR && docker-compose -f docker-compose.production.yml ps
        ;;
    logs)
        cd \$INSTALL_DIR && docker-compose -f docker-compose.production.yml logs -f \$2
        ;;
    backup)
        \$INSTALL_DIR/backup.sh
        ;;
    update)
        echo "Atualizando Sistema de Gestão de Softwares..."
        cd \$INSTALL_DIR
        docker-compose -f docker-compose.production.yml pull
        docker-compose -f docker-compose.production.yml up -d
        ;;
    *)
        echo "Uso: sistema-gestao {start|stop|restart|status|logs|backup|update}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/sistema-gestao
print_message "✓ Script de gerenciamento criado" "$GREEN"
echo ""

# 13. Configurar firewall (se ufw estiver instalado)
if command_exists ufw; then
    print_message "13. Configurando firewall..." "$YELLOW"
    
    sudo ufw allow $WEB_PORT/tcp comment "Sistema Gestao Web"
    sudo ufw allow $API_PORT/tcp comment "Sistema Gestao API"
    
    print_message "✓ Regras de firewall configuradas" "$GREEN"
    echo ""
fi

# 14. Criar serviço systemd
print_message "14. Criando serviço systemd..." "$YELLOW"

cat > /etc/systemd/system/sistema-gestao.service << EOF
[Unit]
Description=Sistema de Gestão de Softwares
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sistema-gestao.service

print_message "✓ Serviço systemd criado e habilitado" "$GREEN"
echo ""

# 15. Informações finais
print_message "=====================================" "$GREEN"
print_message "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO!" "$GREEN"
print_message "=====================================" "$GREEN"
echo ""
print_message "Informações de acesso:" "$BLUE"
echo ""
echo "URL do Sistema: http://${DOMAIN}:${WEB_PORT}"
echo "Email do Admin: ${ADMIN_EMAIL}"
echo "Senha do Admin: admin123 (ALTERE NO PRIMEIRO ACESSO!)"
echo ""
print_message "Comandos úteis:" "$YELLOW"
echo ""
echo "Gerenciar o sistema: sistema-gestao {start|stop|restart|status|logs|backup|update}"
echo "Ver logs: sistema-gestao logs [container]"
echo "Fazer backup: sistema-gestao backup"
echo "Status: sistema-gestao status"
echo ""
print_message "Arquivos importantes:" "$YELLOW"
echo ""
echo "Instalação: $INSTALL_DIR"
echo "Backups: $BACKUP_DIR"
echo "Logs: $INSTALL_DIR/logs"
echo "Config: $INSTALL_DIR/.env"
echo ""
print_message "IMPORTANTE:" "$RED"
echo "1. Altere a senha do administrador no primeiro acesso!"
echo "2. Configure um certificado SSL para produção"
echo "3. Revise as configurações de segurança"
echo "4. Configure monitoramento dos serviços"
echo ""

# Salvar informações de instalação
cat > $INSTALL_DIR/install-info.txt << EOF
Sistema de Gestão de Softwares - Informações de Instalação
==========================================================
Data: $(date)
Domínio: ${DOMAIN}
Portas: Web=${WEB_PORT}, API=${API_PORT}, DB=${DB_PORT}
Admin: ${ADMIN_EMAIL}
Diretório: ${INSTALL_DIR}
EOF

print_message "Log de instalação salvo em: $INSTALL_DIR/install-info.txt" "$BLUE"