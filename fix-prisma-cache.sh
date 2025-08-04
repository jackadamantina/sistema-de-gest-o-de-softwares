#!/bin/bash

# Script para corrigir cache do Prisma e configurações

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Correção de Cache Prisma e Config${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

INSTALL_DIR="/opt/sistema-gestao-softwares"
cd "$INSTALL_DIR"

echo -e "${BLUE}Diretório de trabalho: $(pwd)${NC}"
echo ""

# 1. Parar backend
echo -e "${YELLOW}1. Parando backend para correção...${NC}"
docker-compose -f docker-compose.production.yml stop backend

# 2. Criar .env correto
echo -e "${YELLOW}2. Criando arquivo .env correto...${NC}"
cat > .env << 'EOF'
# Database Configuration
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
EOF

chmod 600 .env
echo -e "${GREEN}✓ Arquivo .env criado${NC}"

# 3. Verificar docker-compose
echo -e "${YELLOW}3. Verificando docker-compose.production.yml...${NC}"

# Fazer backup
cp docker-compose.production.yml docker-compose.production.yml.bak

# Criar versão corrigida
cat > docker-compose-fixed.yml << 'EOF'
version: '3.8'

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

echo -e "${GREEN}✓ Docker-compose corrigido criado${NC}"

# 4. Limpar cache do Prisma no backend
echo -e "${YELLOW}4. Limpando cache do Prisma...${NC}"

# Criar script de limpeza
cat > clean-prisma.sh << 'EOF'
#!/bin/sh
echo "Limpando cache do Prisma..."
rm -rf node_modules/.prisma
rm -rf /app/node_modules/.prisma
echo "Regenerando Prisma Client..."
npx prisma generate
echo "Prisma limpo e regenerado!"
EOF

# Copiar e executar no container
docker cp clean-prisma.sh sistema-gestao-softwares-backend-1:/app/clean-prisma.sh 2>/dev/null || true
docker exec sistema-gestao-softwares-backend-1 sh /app/clean-prisma.sh 2>/dev/null || echo "Backend não estava rodando, será limpo na próxima inicialização"

# 5. Remover e recriar backend
echo -e "${YELLOW}5. Recriando backend com configuração limpa...${NC}"
docker-compose -f docker-compose.production.yml rm -f backend
docker rmi sistema-gestao-softwares-backend 2>/dev/null || true

# 6. Usar o docker-compose corrigido
echo -e "${YELLOW}6. Aplicando configuração corrigida...${NC}"
mv docker-compose-fixed.yml docker-compose.production.yml

# 7. Reconstruir backend
echo -e "${YELLOW}7. Reconstruindo backend...${NC}"
docker-compose -f docker-compose.production.yml build --no-cache backend

# 8. Iniciar serviços
echo -e "${YELLOW}8. Iniciando serviços...${NC}"
docker-compose -f docker-compose.production.yml up -d

# 9. Aguardar inicialização
echo -e "${YELLOW}9. Aguardando inicialização completa...${NC}"
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# 10. Verificar configuração
echo -e "${YELLOW}10. Verificando configuração final...${NC}"
echo -e "${BLUE}Variáveis no backend:${NC}"
docker exec sistema-gestao-softwares-backend-1 env | grep -E "DATABASE|USER" | sort

echo ""
echo -e "${BLUE}Teste de conexão:${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub -c "SELECT current_user;" || echo "Erro na conexão"

echo ""
echo -e "${BLUE}Logs do backend:${NC}"
docker logs sistema-gestao-softwares-backend-1 --tail 20

# Limpar arquivos temporários
rm -f clean-prisma.sh

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Correção Aplicada!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Teste o sistema:${NC}"
echo "URL: http://soft-inventario-xp.wake.tech:8089"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"
echo ""
echo -e "${YELLOW}Se o erro persistir, verifique:${NC}"
echo "1. docker logs sistema-gestao-softwares-backend-1"
echo "2. docker exec sistema-gestao-softwares-backend-1 cat /app/.env"