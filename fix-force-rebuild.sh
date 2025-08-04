#!/bin/bash

# Script para forçar reconstrução completa

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Reconstrução Forçada - Sistema${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

INSTALL_DIR="/opt/sistema-gestao-softwares"
cd "$INSTALL_DIR"

echo -e "${RED}ATENÇÃO: Este script irá:${NC}"
echo "1. Parar todos os containers"
echo "2. Remover imagens antigas"
echo "3. Reconstruir tudo do zero"
echo "4. Recriar o banco de dados"
echo ""
read -p "Tem certeza que deseja continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}Operação cancelada.${NC}"
    exit 1
fi

# Parar tudo
echo ""
echo -e "${YELLOW}1. Parando todos os containers...${NC}"
docker-compose -f docker-compose.production.yml down -v

# Remover imagens antigas
echo ""
echo -e "${YELLOW}2. Removendo imagens antigas...${NC}"
docker rmi sistema-gestao-softwares-backend sistema-gestao-softwares-frontend 2>/dev/null || true

# Verificar e corrigir .env
echo ""
echo -e "${YELLOW}3. Verificando arquivo .env...${NC}"

# Criar .env correto
cat > .env << 'EOF'
# Database - USANDO softwarehub_user (NÃO software_user!)
DATABASE_URL=postgresql://softwarehub_user:softwarehub123@db:5432/softwarehub
POSTGRES_USER=softwarehub_user
POSTGRES_PASSWORD=softwarehub123
POSTGRES_DB=softwarehub
DB_PASSWORD=softwarehub123

# JWT
JWT_SECRET=seu_jwt_secret_aqui_32_caracteres_no_minimo

# Environment
NODE_ENV=production

# Backend
BACKEND_PORT=3002
EOF

chmod 600 .env
echo -e "${GREEN}✓ Arquivo .env recriado${NC}"

# Verificar docker-compose.production.yml
echo ""
echo -e "${YELLOW}4. Ajustando docker-compose.production.yml...${NC}"

# Garantir que o backend use o .env
if ! grep -q "env_file:" docker-compose.production.yml; then
    echo "Adicionando configuração env_file ao backend..."
    # Fazer backup
    cp docker-compose.production.yml docker-compose.production.yml.backup
    
    # Adicionar env_file ao serviço backend
    sed -i '/backend:/,/^[[:space:]]*[^[:space:]]/{
        /environment:/i\    env_file:\n      - .env
    }' docker-compose.production.yml
fi

# Limpar cache do Docker
echo ""
echo -e "${YELLOW}5. Limpando cache do Docker...${NC}"
docker system prune -f

# Reconstruir e iniciar
echo ""
echo -e "${YELLOW}6. Reconstruindo e iniciando serviços...${NC}"
docker-compose -f docker-compose.production.yml build --no-cache backend
docker-compose -f docker-compose.production.yml up -d

# Aguardar inicialização
echo ""
echo -e "${YELLOW}7. Aguardando serviços iniciarem...${NC}"
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# Verificar status
echo ""
echo -e "${YELLOW}8. Verificando status dos serviços...${NC}"
docker-compose -f docker-compose.production.yml ps

# Verificar logs
echo ""
echo -e "${YELLOW}9. Verificando logs do backend...${NC}"
docker logs sistema-gestao-softwares-backend-1 --tail 20

# Testar conexão
echo ""
echo -e "${YELLOW}10. Testando conexão com o banco...${NC}"
docker exec sistema-gestao-softwares-backend-1 env | grep DATABASE_URL

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Reconstrução Completa!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Próximos passos:${NC}"
echo "1. Acesse: http://soft-inventario-xp.wake.tech:8089"
echo "2. Login: admin@softwarehub.com"
echo "3. Senha: admin123"
echo ""
echo -e "${YELLOW}Se ainda houver erro:${NC}"
echo "Execute: ./deep-diagnose-db.sh"