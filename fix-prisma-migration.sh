#!/bin/bash

# Script para resolver problema de migração do Prisma

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Corrigindo Migração do Prisma${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

cd /opt/sistema-gestao-softwares

# 1. Parar o backend
echo -e "${YELLOW}1. Parando backend...${NC}"
docker-compose -f docker-compose.production.yml stop backend

# 2. Verificar conexão com o banco
echo -e "${YELLOW}2. Verificando conexão com banco de dados...${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub -c "SELECT 1;" || {
    echo -e "${RED}Erro ao conectar no banco!${NC}"
    exit 1
}

# 3. Opções para resolver
echo ""
echo -e "${YELLOW}O banco já possui tabelas. Escolha uma opção:${NC}"
echo "1) Marcar migrações como aplicadas (baseline) - RECOMENDADO"
echo "2) Resetar banco e aplicar do zero (PERDERÁ DADOS)"
echo "3) Iniciar backend sem migrações"
echo ""
read -p "Opção (1-3): " OPTION

case $OPTION in
    1)
        echo -e "${YELLOW}Marcando migrações como aplicadas...${NC}"
        
        # Criar comando para marcar migração como aplicada
        docker-compose -f docker-compose.production.yml run --rm backend sh -c "
            npx prisma migrate resolve --applied 20250728165348_init
        "
        
        # Atualizar docker-compose para pular migrações
        echo -e "${YELLOW}Atualizando comando do backend...${NC}"
        sed -i 's/npx prisma migrate deploy/echo "Migrações já aplicadas"/g' docker-compose.production.yml
        ;;
        
    2)
        echo -e "${RED}AVISO: Isso apagará todos os dados!${NC}"
        read -p "Tem certeza? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            echo -e "${YELLOW}Resetando banco de dados...${NC}"
            docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub -c "
                DROP SCHEMA public CASCADE;
                CREATE SCHEMA public;
                GRANT ALL ON SCHEMA public TO softwarehub_user;
            "
            
            # Reexecutar init.sql
            docker exec -i sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub < backend/init.sql
        else
            echo "Operação cancelada"
            exit 1
        fi
        ;;
        
    3)
        echo -e "${YELLOW}Configurando para iniciar sem migrações...${NC}"
        ;;
        
    *)
        echo -e "${RED}Opção inválida${NC}"
        exit 1
        ;;
esac

# 4. Criar comando alternativo para o backend
echo -e "${YELLOW}4. Criando comando otimizado para o backend...${NC}"

# Backup do docker-compose atual
cp docker-compose.production.yml docker-compose.production.yml.backup

# Criar novo docker-compose com comando simplificado
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

echo -e "${GREEN}✓ Docker-compose atualizado${NC}"

# 5. Iniciar backend
echo -e "${YELLOW}5. Iniciando backend...${NC}"
docker-compose -f docker-compose.production.yml up -d backend

# 6. Aguardar e verificar
echo -e "${YELLOW}6. Aguardando inicialização...${NC}"
sleep 10

# 7. Verificar logs
echo -e "${YELLOW}7. Verificando logs do backend...${NC}"
docker-compose -f docker-compose.production.yml logs --tail=20 backend

# 8. Testar API
echo -e "${YELLOW}8. Testando API...${NC}"
curl -s http://localhost:3002/api/health || echo "API ainda não está respondendo"

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Processo Concluído${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Se o backend ainda não estiver funcionando:"
echo "1. Verifique os logs: docker-compose -f docker-compose.production.yml logs -f backend"
echo "2. Verifique se a porta 3002 está aberta: netstat -tuln | grep 3002"