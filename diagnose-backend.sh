#!/bin/bash

# Script para diagnosticar problemas no backend

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Diagnóstico do Backend${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

cd /opt/sistema-gestao-softwares

# 1. Verificar status dos containers
echo -e "${YELLOW}1. Status dos containers:${NC}"
docker-compose -f docker-compose.production.yml ps

# 2. Verificar logs do backend
echo ""
echo -e "${YELLOW}2. Logs do backend (últimas 50 linhas):${NC}"
docker-compose -f docker-compose.production.yml logs --tail=50 backend

# 3. Verificar se o backend está ouvindo na porta
echo ""
echo -e "${YELLOW}3. Verificando portas no container do backend:${NC}"
docker exec sistema-gestao-softwares-backend-1 netstat -tuln 2>/dev/null || echo "netstat não disponível"

# 4. Verificar variáveis de ambiente
echo ""
echo -e "${YELLOW}4. Variáveis de ambiente do backend:${NC}"
docker exec sistema-gestao-softwares-backend-1 env | grep -E "DATABASE|PORT|NODE_ENV" | sort

# 5. Testar conexão com o banco
echo ""
echo -e "${YELLOW}5. Testando conexão backend -> banco de dados:${NC}"
docker exec sistema-gestao-softwares-backend-1 sh -c "nc -zv db 5432" 2>&1 || echo "Conexão com banco falhou"

# 6. Verificar saúde do banco
echo ""
echo -e "${YELLOW}6. Status do banco de dados:${NC}"
docker exec sistema-gestao-softwares-db-1 pg_isready || echo "Banco não está pronto"

# 7. Reiniciar backend
echo ""
echo -e "${YELLOW}7. Tentando reiniciar o backend...${NC}"
docker-compose -f docker-compose.production.yml restart backend

echo ""
echo -e "${YELLOW}Aguardando 15 segundos...${NC}"
sleep 15

# 8. Verificar novamente
echo ""
echo -e "${YELLOW}8. Status após reinicialização:${NC}"
docker-compose -f docker-compose.production.yml ps backend

# 9. Logs após reinicialização
echo ""
echo -e "${YELLOW}9. Logs do backend após reinicialização:${NC}"
docker-compose -f docker-compose.production.yml logs --tail=30 backend

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Diagnóstico Completo${NC}"
echo -e "${GREEN}=====================================${NC}"