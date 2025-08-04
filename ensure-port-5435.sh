#!/bin/bash

# Script para garantir que a porta 5435 seja usada no servidor

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Garantindo Porta 5435 no PostgreSQL${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

# Determinar diretório
INSTALL_DIR="/opt/sistema-gestao-softwares"
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Erro: Diretório $INSTALL_DIR não encontrado${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

# 1. Parar containers se estiverem rodando
echo -e "${YELLOW}1. Parando containers existentes...${NC}"
docker-compose -f docker-compose.production.yml down 2>/dev/null || true

# 2. Verificar o que está usando a porta 5432
echo -e "${YELLOW}2. Verificando porta 5432...${NC}"
if lsof -i :5432 >/dev/null 2>&1; then
    echo -e "${RED}Porta 5432 está em uso por:${NC}"
    lsof -i :5432
    docker ps | grep 5432 || true
fi

# 3. Criar docker-compose.production.yml correto
echo -e "${YELLOW}3. Criando docker-compose.production.yml com porta 5435...${NC}"

cat > docker-compose.production.yml << 'EOF'
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
EOF

echo -e "${GREEN}✓ docker-compose.production.yml criado com porta 5435${NC}"

# 4. Verificar se .env existe
if [ ! -f .env ]; then
    echo -e "${YELLOW}4. Criando arquivo .env...${NC}"
    cat > .env << 'EOF'
# Database
DB_PASSWORD=SoftwareHub@2024Secure
DATABASE_URL=postgresql://softwarehub_user:SoftwareHub@2024Secure@db:5432/softwarehub

# Security
JWT_SECRET=DefaultJWTSecretChangeInProduction2024

# Environment
NODE_ENV=production

# Ports
FRONTEND_PORT=8089
BACKEND_PORT=3002
EOF
    chmod 600 .env
    echo -e "${GREEN}✓ Arquivo .env criado${NC}"
else
    echo -e "${GREEN}✓ Arquivo .env já existe${NC}"
fi

# 5. Verificar o conteúdo atual
echo ""
echo -e "${YELLOW}5. Verificando configuração de porta no arquivo:${NC}"
grep -A2 -B2 "ports:" docker-compose.production.yml | grep -E "db:|ports:|543" || echo "Não encontrado"

# 6. Iniciar containers
echo ""
echo -e "${YELLOW}6. Iniciando containers com porta 5435...${NC}"
docker-compose -f docker-compose.production.yml up -d

# 7. Aguardar e verificar
echo -e "${YELLOW}7. Aguardando inicialização...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}8. Status dos serviços:${NC}"
docker-compose -f docker-compose.production.yml ps

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Configuração Aplicada!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "PostgreSQL deve estar rodando na porta 5435"
echo ""
echo "Para verificar:"
echo "docker ps | grep 5435"