#!/bin/bash

# Script de diagnóstico profundo

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Diagnóstico Profundo - Banco de Dados${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

INSTALL_DIR="/opt/sistema-gestao-softwares"
cd "$INSTALL_DIR"

echo -e "${BLUE}1. Verificando variáveis de ambiente no container backend:${NC}"
docker exec sistema-gestao-softwares-backend-1 env | grep -E "DATABASE|POSTGRES|DB_" | sort

echo ""
echo -e "${BLUE}2. Verificando arquivo .env dentro do container:${NC}"
docker exec sistema-gestao-softwares-backend-1 cat /app/.env 2>/dev/null || echo "Arquivo .env não encontrado no container"

echo ""
echo -e "${BLUE}3. Verificando conexão direta com o banco:${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub -c "SELECT current_user, current_database();" 2>&1 || echo "Erro ao conectar"

echo ""
echo -e "${BLUE}4. Verificando usuários no PostgreSQL:${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U postgres -c "\du" 2>&1 || echo "Não foi possível listar usuários"

echo ""
echo -e "${BLUE}5. Verificando logs recentes do backend:${NC}"
docker logs sistema-gestao-softwares-backend-1 --tail 30 2>&1 | grep -E "database|Database|USER|user|Error|error|prisma" || true

echo ""
echo -e "${BLUE}6. Verificando processo do backend:${NC}"
docker exec sistema-gestao-softwares-backend-1 ps aux | grep node || true

echo ""
echo -e "${BLUE}7. Verificando arquivo Prisma no container:${NC}"
docker exec sistema-gestao-softwares-backend-1 ls -la /app/prisma/ 2>/dev/null || echo "Diretório prisma não encontrado"

echo ""
echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Análise${NC}"
echo -e "${YELLOW}=====================================${NC}"

echo ""
echo "Possíveis causas do erro 'software_user':"
echo "1. Cache do Prisma Client com configuração antiga"
echo "2. Variável DATABASE_URL sendo sobrescrita"
echo "3. Arquivo .env não sendo carregado corretamente"
echo "4. Configuração hardcoded em algum lugar do código"
echo ""

echo -e "${GREEN}Ação recomendada:${NC}"
echo "Execute a opção 1 para forçar reconstrução:"
echo ""
echo -e "${YELLOW}./fix-force-rebuild.sh${NC}"