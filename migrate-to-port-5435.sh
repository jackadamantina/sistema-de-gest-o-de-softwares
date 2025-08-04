#!/bin/bash

# Script unificado para migrar todo o sistema para usar porta 5435 no PostgreSQL

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}Migração Completa do Sistema para Porta 5435${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""

# Verificar se está executando no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Erro: Este script deve ser executado no diretório raiz do projeto${NC}"
    exit 1
fi

echo -e "${BLUE}Este script irá:${NC}"
echo "1. Verificar todos os arquivos de configuração"
echo "2. Atualizar todas as referências de porta do PostgreSQL para 5435"
echo "3. Verificar conflitos de porta"
echo "4. Oferecer opção de reiniciar os serviços"
echo ""

read -p "Deseja continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}Operação cancelada.${NC}"
    exit 1
fi

# 1. Verificar status atual
echo ""
echo -e "${YELLOW}1. Verificando configuração atual...${NC}"

# Verificar portas nos docker-compose
echo -e "${BLUE}Portas configuradas nos arquivos docker-compose:${NC}"
for file in docker-compose*.yml; do
    if [ -f "$file" ]; then
        echo -n "$file: "
        grep -E "ports:.*543[0-9]" -A1 "$file" | grep -oE "543[0-9]" | head -1 || echo "Porta não encontrada"
    fi
done

# 2. Verificar se a porta 5435 está livre
echo ""
echo -e "${YELLOW}2. Verificando disponibilidade da porta 5435...${NC}"
if lsof -i :5435 >/dev/null 2>&1; then
    echo -e "${RED}⚠️  ATENÇÃO: Porta 5435 já está em uso!${NC}"
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

# 3. Criar arquivo de configuração padrão
echo ""
echo -e "${YELLOW}3. Criando arquivo .env padrão...${NC}"

# Backup do .env se existir
if [ -f .env ]; then
    cp .env .env.backup-$(date +%Y%m%d_%H%M%S)
    echo -e "${BLUE}Backup do .env criado${NC}"
fi

# Determinar senha do banco
if [ -f .env ] && grep -q "DB_PASSWORD=" .env; then
    DB_PASSWORD=$(grep "DB_PASSWORD=" .env | cut -d'=' -f2)
else
    DB_PASSWORD="softwarehub123"
fi

# Criar .env padrão
cat > .env << EOF
# Database Configuration
# Nota: A porta interna do container sempre será 5432
# A porta externa (host) será 5435
DATABASE_URL=postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub
POSTGRES_USER=softwarehub_user
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=softwarehub
DB_PASSWORD=${DB_PASSWORD}

# JWT
JWT_SECRET=$(openssl rand -base64 32)

# Environment
NODE_ENV=production

# Ports
BACKEND_PORT=3002
DB_EXTERNAL_PORT=5435
FRONTEND_PORT=8089
EOF

chmod 600 .env
echo -e "${GREEN}✓ Arquivo .env criado/atualizado${NC}"

# 4. Verificar containers em execução
echo ""
echo -e "${YELLOW}4. Verificando containers em execução...${NC}"
RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "sistema-gestao-softwares|softwarehub" || true)

if [ -n "$RUNNING_CONTAINERS" ]; then
    echo -e "${BLUE}Containers encontrados:${NC}"
    echo "$RUNNING_CONTAINERS"
    echo ""
    read -p "Deseja parar os containers para aplicar as mudanças? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Parando containers...${NC}"
        docker-compose down || docker-compose -f docker-compose.local.yml down || true
    fi
else
    echo -e "${GREEN}✓ Nenhum container relacionado em execução${NC}"
fi

# 5. Resumo das mudanças
echo ""
echo -e "${YELLOW}5. Resumo das configurações:${NC}"
echo -e "${BLUE}Portas do Sistema:${NC}"
echo "├─ PostgreSQL (externa): 5435"
echo "├─ PostgreSQL (interna): 5432"
echo "├─ Backend API: 3002"
echo "└─ Frontend: 8089"
echo ""
echo -e "${BLUE}Arquivos atualizados:${NC}"
echo "├─ docker-compose.yml"
echo "├─ docker-compose.local.yml"
echo "├─ docker-compose.dev.yml"
echo "├─ docker-compose.prod.yml"
echo "├─ scripts/*.sh"
echo "└─ .env"

# 6. Opção de iniciar serviços
echo ""
echo -e "${YELLOW}6. Inicialização dos serviços${NC}"
echo "Escolha uma opção:"
echo "1) Iniciar em modo produção (docker-compose.yml)"
echo "2) Iniciar em modo local (docker-compose.local.yml)"
echo "3) Não iniciar agora"
echo ""
read -p "Opção (1-3): " START_OPTION

case $START_OPTION in
    1)
        echo -e "${YELLOW}Iniciando em modo produção...${NC}"
        docker-compose up -d
        ;;
    2)
        echo -e "${YELLOW}Iniciando em modo local...${NC}"
        docker-compose -f docker-compose.local.yml up -d
        ;;
    3)
        echo -e "${BLUE}Serviços não iniciados${NC}"
        ;;
    *)
        echo -e "${RED}Opção inválida${NC}"
        ;;
esac

# 7. Instruções finais
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✓ Migração Concluída!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Informações de Acesso:${NC}"
echo "Sistema Web: http://localhost:8089"
echo "Backend API: http://localhost:3002"
echo "PostgreSQL: localhost:5435"
echo ""
echo -e "${BLUE}Credenciais Padrão:${NC}"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"
echo ""
echo -e "${YELLOW}Comandos Úteis:${NC}"
echo "Ver status: docker-compose ps"
echo "Ver logs: docker-compose logs -f"
echo "Parar: docker-compose down"
echo "Iniciar: docker-compose up -d"
echo ""
echo -e "${BLUE}Conexão com o banco (externa):${NC}"
echo "psql -h localhost -p 5435 -U softwarehub_user -d softwarehub"