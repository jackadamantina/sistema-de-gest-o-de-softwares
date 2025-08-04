#!/bin/bash

# Script para corrigir porta 5432 para 5435 no servidor

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Correção: Porta 5432 → 5435${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

# Determinar diretório
if [ -d "/opt/sistema-gestao-softwares" ]; then
    cd /opt/sistema-gestao-softwares
elif [ -d "/sistema-de-gest-o-de-softwares" ]; then
    cd /sistema-de-gest-o-de-softwares
else
    echo -e "${RED}Erro: Diretório do sistema não encontrado${NC}"
    exit 1
fi

echo -e "${BLUE}Diretório: $(pwd)${NC}"

# 1. Parar containers
echo -e "${YELLOW}1. Parando containers...${NC}"
docker-compose down 2>/dev/null || docker-compose -f docker-compose.production.yml down 2>/dev/null || true

# 2. Verificar qual arquivo docker-compose existe
echo -e "${YELLOW}2. Verificando arquivos docker-compose...${NC}"
COMPOSE_FILE=""
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
else
    echo -e "${RED}Erro: Nenhum arquivo docker-compose encontrado!${NC}"
    exit 1
fi

echo -e "${BLUE}Usando: $COMPOSE_FILE${NC}"

# 3. Verificar porta atual no arquivo
echo -e "${YELLOW}3. Verificando configuração atual...${NC}"
echo "Configuração de porta atual:"
grep -A2 -B2 "ports:" "$COMPOSE_FILE" | grep -E "db:|ports:|5432|5435" || echo "Não encontrado"

# 4. Fazer backup
echo -e "${YELLOW}4. Criando backup...${NC}"
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup-$(date +%Y%m%d_%H%M%S)"

# 5. Corrigir porta
echo -e "${YELLOW}5. Atualizando porta para 5435...${NC}"

# Usar sed para substituir a porta
if grep -q '"5432:5432"' "$COMPOSE_FILE"; then
    sed -i 's/"5432:5432"/"5435:5432"/g' "$COMPOSE_FILE"
    echo -e "${GREEN}✓ Atualizado de 5432:5432 para 5435:5432${NC}"
elif grep -q "'5432:5432'" "$COMPOSE_FILE"; then
    sed -i "s/'5432:5432'/'5435:5432'/g" "$COMPOSE_FILE"
    echo -e "${GREEN}✓ Atualizado de 5432:5432 para 5435:5432${NC}"
elif grep -q "- 5432:5432" "$COMPOSE_FILE"; then
    sed -i 's/- 5432:5432/- 5435:5432/g' "$COMPOSE_FILE"
    echo -e "${GREEN}✓ Atualizado de 5432:5432 para 5435:5432${NC}"
elif grep -q "5432:5432" "$COMPOSE_FILE"; then
    sed -i 's/5432:5432/5435:5432/g' "$COMPOSE_FILE"
    echo -e "${GREEN}✓ Atualizado de 5432:5432 para 5435:5432${NC}"
else
    echo -e "${YELLOW}Porta 5432:5432 não encontrada no formato esperado${NC}"
    echo "Tentando substituição mais ampla..."
    sed -i 's/\([[:space:]]*-[[:space:]]*\)"*5432:/"5435:/g' "$COMPOSE_FILE"
fi

# 6. Mostrar resultado
echo -e "${YELLOW}6. Verificando mudança...${NC}"
echo "Nova configuração:"
grep -A2 -B2 "ports:" "$COMPOSE_FILE" | grep -E "db:|ports:|5432|5435" || echo "Não encontrado"

# 7. Verificar se porta 5435 está livre
echo -e "${YELLOW}7. Verificando disponibilidade da porta 5435...${NC}"
if lsof -i :5435 >/dev/null 2>&1; then
    echo -e "${RED}AVISO: Porta 5435 já está em uso!${NC}"
    lsof -i :5435
else
    echo -e "${GREEN}✓ Porta 5435 está livre${NC}"
fi

# 8. Verificar se porta 5432 está em uso
echo -e "${YELLOW}8. Verificando o que está usando a porta 5432...${NC}"
if lsof -i :5432 >/dev/null 2>&1; then
    echo -e "${YELLOW}Processos usando porta 5432:${NC}"
    lsof -i :5432
    echo ""
    echo "Containers Docker usando porta 5432:"
    docker ps --format "table {{.Names}}\t{{.Ports}}" | grep 5432 || echo "Nenhum"
fi

# 9. Reiniciar serviços
echo ""
read -p "Deseja iniciar os serviços com a nova porta? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Iniciando serviços...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d
    
    echo -e "${YELLOW}Aguardando inicialização...${NC}"
    sleep 10
    
    echo -e "${YELLOW}Status dos serviços:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Correção Aplicada!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "PostgreSQL agora deve usar porta 5435"
echo ""
echo "Para verificar:"
echo "docker-compose -f $COMPOSE_FILE ps"