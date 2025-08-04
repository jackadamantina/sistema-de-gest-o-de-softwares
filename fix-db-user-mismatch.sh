#!/bin/bash

# Script para corrigir discrepância no nome do usuário do banco

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Diagnóstico e Correção - Usuário DB${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

# Solicitar informações
read -p "Digite o diretório de instalação (padrão: /opt/sistema-gestao-softwares): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-"/opt/sistema-gestao-softwares"}

cd "$INSTALL_DIR" || exit 1

echo -e "${BLUE}Diretório atual: $(pwd)${NC}"
echo ""

# Verificar arquivos existentes
echo -e "${YELLOW}1. Verificando arquivos de configuração...${NC}"

# Verificar .env
if [ -f ".env" ]; then
    echo -e "${GREEN}✓ Arquivo .env encontrado${NC}"
    echo "Conteúdo atual:"
    grep -E "DATABASE_URL|POSTGRES_USER|DB_" .env || true
    echo ""
else
    echo -e "${RED}✗ Arquivo .env não encontrado${NC}"
fi

# Verificar docker-compose
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
else
    echo -e "${RED}Erro: Arquivo docker-compose não encontrado!${NC}"
    exit 1
fi

echo -e "${BLUE}Usando arquivo: $COMPOSE_FILE${NC}"

# Verificar configuração no docker-compose
echo ""
echo -e "${YELLOW}2. Configuração no $COMPOSE_FILE:${NC}"
grep -E "POSTGRES_USER|DATABASE_URL" $COMPOSE_FILE | head -10

# Verificar containers em execução
echo ""
echo -e "${YELLOW}3. Containers em execução:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "db|backend|postgres" || echo "Nenhum container relevante em execução"

# Perguntar qual correção aplicar
echo ""
echo -e "${YELLOW}O erro indica que o sistema está tentando usar 'software_user'${NC}"
echo -e "${YELLOW}mas a configuração deveria usar 'softwarehub_user'.${NC}"
echo ""
echo "Opções de correção:"
echo "1) Recriar o .env com usuário correto (softwarehub_user)"
echo "2) Parar tudo e reiniciar do zero"
echo "3) Apenas diagnosticar (não fazer mudanças)"
echo ""
read -p "Escolha uma opção (1-3): " OPTION

case $OPTION in
    1)
        echo ""
        echo -e "${YELLOW}Recriando arquivo .env...${NC}"
        
        read -sp "Digite a senha do banco de dados: " DB_PASSWORD
        echo ""
        
        # Backup do .env atual se existir
        if [ -f ".env" ]; then
            cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
            echo -e "${BLUE}Backup criado do .env atual${NC}"
        fi
        
        # Criar novo .env
        cat > .env << EOF
# Database - IMPORTANTE: Usar softwarehub_user, não software_user!
DATABASE_URL=postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub
POSTGRES_USER=softwarehub_user
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=softwarehub
DB_PASSWORD=${DB_PASSWORD}

# JWT
JWT_SECRET=$(openssl rand -base64 32)

# Environment
NODE_ENV=production

# Backend
BACKEND_PORT=3002
EOF
        
        chmod 600 .env
        echo -e "${GREEN}✓ Arquivo .env criado com usuário correto${NC}"
        
        echo ""
        echo -e "${YELLOW}Reiniciando serviços...${NC}"
        docker-compose -f $COMPOSE_FILE down
        docker-compose -f $COMPOSE_FILE up -d
        
        echo ""
        echo -e "${GREEN}✓ Serviços reiniciados${NC}"
        ;;
        
    2)
        echo ""
        echo -e "${YELLOW}Parando e removendo tudo...${NC}"
        
        # Parar containers
        docker-compose -f $COMPOSE_FILE down
        
        # Remover volumes
        echo -e "${YELLOW}Removendo volumes do banco...${NC}"
        docker volume ls | grep postgres_data | awk '{print $2}' | xargs -r docker volume rm 2>/dev/null || true
        
        # Recriar .env
        read -sp "Digite a senha do banco de dados: " DB_PASSWORD
        echo ""
        
        cat > .env << EOF
# Database
DATABASE_URL=postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub
POSTGRES_USER=softwarehub_user
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=softwarehub
DB_PASSWORD=${DB_PASSWORD}

# JWT
JWT_SECRET=$(openssl rand -base64 32)

# Environment
NODE_ENV=production

# Backend
BACKEND_PORT=3002
EOF
        
        chmod 600 .env
        
        echo -e "${GREEN}✓ Configuração recriada${NC}"
        echo -e "${YELLOW}Iniciando serviços...${NC}"
        
        docker-compose -f $COMPOSE_FILE up -d
        
        echo ""
        echo -e "${GREEN}✓ Sistema reiniciado do zero${NC}"
        ;;
        
    3)
        echo ""
        echo -e "${BLUE}Modo diagnóstico - nenhuma mudança foi feita${NC}"
        ;;
        
    *)
        echo -e "${RED}Opção inválida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}4. Verificando logs do backend para mais detalhes...${NC}"
if docker ps | grep -q backend; then
    echo "Últimas linhas do log do backend:"
    docker logs $(docker ps -q -f name=backend) --tail 20 2>&1 | grep -E "database|Database|USER|user|Error|error" || true
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Diagnóstico Completo${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Resumo:${NC}"
echo "- O sistema deve usar: softwarehub_user"
echo "- O erro mostra: software_user"
echo "- Isso indica uma discrepância na configuração"
echo ""
echo -e "${YELLOW}Se o problema persistir:${NC}"
echo "1. Verifique se não há outro arquivo .env no sistema"
echo "2. Verifique as variáveis de ambiente: env | grep -E 'DATABASE|POSTGRES'"
echo "3. Verifique dentro do container: docker exec backend env | grep DATABASE"
echo ""
echo -e "${GREEN}Credenciais padrão do sistema:${NC}"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"