#!/bin/bash

# Script para resolver conflito de porta

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Resolvendo Conflito de Porta 5432${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

# 1. Verificar o que está usando a porta 5432
echo -e "${YELLOW}1. Verificando o que está usando a porta 5432...${NC}"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep 5432 || echo "Nenhum container visível na porta 5432"

echo ""
echo -e "${YELLOW}2. Listando todos os containers PostgreSQL...${NC}"
docker ps -a | grep -E "postgres|db" || echo "Nenhum container postgres encontrado"

echo ""
echo -e "${YELLOW}3. Verificando com netstat...${NC}"
sudo netstat -tlnp | grep 5432 || echo "Porta 5432 não encontrada no netstat"

echo ""
echo -e "${BLUE}Opções de correção:${NC}"
echo "1) Parar o outro container PostgreSQL"
echo "2) Usar uma porta diferente para este sistema"
echo "3) Forçar parada de todos os containers e reiniciar"
echo ""
read -p "Escolha uma opção (1-3): " OPTION

INSTALL_DIR="/opt/sistema-gestao-softwares"
cd "$INSTALL_DIR"

case $OPTION in
    1)
        echo ""
        echo -e "${YELLOW}Parando outros containers PostgreSQL...${NC}"
        
        # Listar containers usando porta 5432
        CONTAINERS=$(docker ps --format "{{.Names}}" --filter "publish=5432")
        
        if [ -n "$CONTAINERS" ]; then
            echo "Containers encontrados: $CONTAINERS"
            for container in $CONTAINERS; do
                if [[ ! "$container" =~ "sistema-gestao-softwares" ]]; then
                    echo "Parando: $container"
                    docker stop $container
                fi
            done
        fi
        
        # Tentar novamente
        echo -e "${YELLOW}Reiniciando sistema...${NC}"
        docker-compose -f docker-compose.production.yml down
        docker-compose -f docker-compose.production.yml up -d
        ;;
        
    2)
        echo ""
        echo -e "${YELLOW}Alterando para porta 5433...${NC}"
        
        # Fazer backup
        cp docker-compose.production.yml docker-compose.production.yml.port-backup
        
        # Alterar porta no docker-compose
        sed -i 's/- "5432:5432"/- "5433:5432"/' docker-compose.production.yml
        
        # Atualizar .env
        sed -i 's/:5432/:5433/g' .env 2>/dev/null || true
        
        echo -e "${GREEN}✓ Porta alterada para 5433${NC}"
        echo -e "${YELLOW}Nota: O banco interno continua na 5432, apenas o mapeamento externo mudou${NC}"
        
        # Reiniciar
        docker-compose -f docker-compose.production.yml down
        docker-compose -f docker-compose.production.yml up -d
        ;;
        
    3)
        echo ""
        echo -e "${YELLOW}Forçando parada total e reinicialização...${NC}"
        
        # Parar TUDO relacionado a postgres/db
        echo "Parando todos os containers relacionados..."
        docker ps -q | xargs -r docker stop
        
        # Remover containers do sistema
        docker-compose -f docker-compose.production.yml down -v
        
        # Verificar se ainda há algo na porta
        if lsof -i :5432 >/dev/null 2>&1; then
            echo -e "${RED}Ainda há processo na porta 5432${NC}"
            echo "Tentando identificar..."
            sudo lsof -i :5432
            
            read -p "Deseja matar o processo? (s/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                sudo fuser -k 5432/tcp
            fi
        fi
        
        # Aguardar
        sleep 5
        
        # Iniciar limpo
        echo -e "${YELLOW}Iniciando sistema limpo...${NC}"
        docker-compose -f docker-compose.production.yml up -d
        ;;
        
    *)
        echo -e "${RED}Opção inválida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}Aguardando serviços iniciarem...${NC}"
sleep 15

echo ""
echo -e "${YELLOW}Status dos serviços:${NC}"
docker-compose -f docker-compose.production.yml ps

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Correção Aplicada!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Verificar qual porta está sendo usada
if grep -q "5433:5432" docker-compose.production.yml; then
    echo -e "${YELLOW}ATENÇÃO: O banco agora está na porta 5433!${NC}"
    echo "Para conectar externamente use: localhost:5433"
else
    echo "Banco de dados na porta padrão: 5432"
fi

echo ""
echo -e "${BLUE}Teste o sistema:${NC}"
echo "URL: http://soft-inventario-xp.wake.tech:8089"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"