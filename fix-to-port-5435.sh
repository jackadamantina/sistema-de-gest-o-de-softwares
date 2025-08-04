#!/bin/bash

# Script para configurar o sistema para usar porta 5435

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Configurando Sistema para Porta 5435${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

INSTALL_DIR="/opt/sistema-gestao-softwares"
cd "$INSTALL_DIR"

echo -e "${BLUE}Diretório de trabalho: $(pwd)${NC}"
echo ""

# 1. Parar serviços atuais
echo -e "${YELLOW}1. Parando serviços atuais...${NC}"
docker-compose -f docker-compose.production.yml down

# 2. Fazer backup do docker-compose
echo -e "${YELLOW}2. Fazendo backup do docker-compose...${NC}"
cp docker-compose.production.yml docker-compose.production.yml.backup-$(date +%Y%m%d_%H%M%S)

# 3. Atualizar docker-compose para usar porta 5435
echo -e "${YELLOW}3. Atualizando docker-compose para porta 5435...${NC}"

# Criar nova versão do docker-compose com porta 5435
cat > docker-compose.production.yml << 'EOF'
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: softwarehub
      POSTGRES_USER: softwarehub_user
      POSTGRES_PASSWORD: ${DB_PASSWORD:-softwarehub123}
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

  backend:
    build: 
      context: ./backend
      dockerfile: Dockerfile
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql://softwarehub_user:${DB_PASSWORD:-softwarehub123}@db:5432/softwarehub
      JWT_SECRET: ${JWT_SECRET:-seu_jwt_secret_super_secreto_32_chars_min}
      NODE_ENV: production
    ports:
      - "3002:3002"
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./uploads:/app/uploads
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
    ports:
      - "8089:80"
    depends_on:
      - backend
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro

volumes:
  postgres_data:
EOF

echo -e "${GREEN}✓ Docker-compose atualizado para porta 5435${NC}"

# 4. Criar/Atualizar .env
echo -e "${YELLOW}4. Atualizando arquivo .env...${NC}"

# Verificar se .env existe e fazer backup
if [ -f .env ]; then
    cp .env .env.backup-$(date +%Y%m%d_%H%M%S)
fi

# Criar novo .env
cat > .env << 'EOF'
# Database Configuration
# IMPORTANTE: O banco interno usa porta 5432, mas externamente está mapeado para 5435
DATABASE_URL=postgresql://softwarehub_user:softwarehub123@db:5432/softwarehub
POSTGRES_USER=softwarehub_user
POSTGRES_PASSWORD=softwarehub123
POSTGRES_DB=softwarehub
DB_PASSWORD=softwarehub123

# JWT
JWT_SECRET=seu_jwt_secret_super_secreto_32_chars_min

# Environment
NODE_ENV=production

# Backend
BACKEND_PORT=3002

# Database External Port (para referência)
DB_EXTERNAL_PORT=5435
EOF

chmod 600 .env
echo -e "${GREEN}✓ Arquivo .env atualizado${NC}"

# 5. Verificar se a porta 5435 está livre
echo -e "${YELLOW}5. Verificando se a porta 5435 está livre...${NC}"
if lsof -i :5435 >/dev/null 2>&1; then
    echo -e "${RED}ATENÇÃO: Porta 5435 já está em uso!${NC}"
    echo "Processos usando a porta:"
    sudo lsof -i :5435
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${RED}Operação cancelada.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Porta 5435 está livre${NC}"
fi

# 6. Limpar volumes antigos (opcional)
echo ""
read -p "Deseja limpar os dados antigos do banco? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Removendo volumes antigos...${NC}"
    docker volume rm sistema-gestao-softwares_postgres_data 2>/dev/null || true
    echo -e "${GREEN}✓ Volumes removidos${NC}"
fi

# 7. Iniciar serviços
echo ""
echo -e "${YELLOW}6. Iniciando serviços com nova configuração...${NC}"
docker-compose -f docker-compose.production.yml up -d

# 8. Aguardar inicialização
echo -e "${YELLOW}7. Aguardando serviços iniciarem...${NC}"
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# 9. Verificar status
echo ""
echo -e "${YELLOW}8. Verificando status dos serviços...${NC}"
docker-compose -f docker-compose.production.yml ps

# 10. Testar conexão
echo ""
echo -e "${YELLOW}9. Testando conexão com o banco...${NC}"
echo -e "${BLUE}Teste interno (container para container):${NC}"
docker exec sistema-gestao-softwares-backend-1 env | grep DATABASE_URL || echo "Backend não está rodando ainda"

echo ""
echo -e "${BLUE}Teste externo (host para container na porta 5435):${NC}"
PGPASSWORD=softwarehub123 psql -h localhost -p 5435 -U softwarehub_user -d softwarehub -c "SELECT version();" 2>/dev/null || echo "Conexão externa ainda não disponível"

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Sistema Configurado para Porta 5435!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Informações importantes:${NC}"
echo "- Porta PostgreSQL Externa: 5435"
echo "- Porta PostgreSQL Interna: 5432 (não mude isso)"
echo "- Porta Backend: 3002"
echo "- Porta Frontend: 8089"
echo ""
echo -e "${BLUE}URLs de acesso:${NC}"
echo "Sistema: http://soft-inventario-xp.wake.tech:8089"
echo "Backend API: http://soft-inventario-xp.wake.tech:3002"
echo ""
echo -e "${BLUE}Credenciais padrão:${NC}"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"
echo ""
echo -e "${YELLOW}Para conectar ao banco externamente:${NC}"
echo "psql -h localhost -p 5435 -U softwarehub_user -d softwarehub"