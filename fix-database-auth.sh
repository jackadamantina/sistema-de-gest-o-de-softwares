#!/bin/bash

# Script para corrigir problemas de autenticação do banco de dados

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Correção de Autenticação do Banco${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

# Verificar se está no servidor de produção
echo -e "${BLUE}Este script irá:${NC}"
echo "1. Parar os containers atuais"
echo "2. Remover o volume do banco de dados"
echo "3. Recriar o banco com as credenciais corretas"
echo ""
read -p "Deseja continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}Operação cancelada.${NC}"
    exit 1
fi

# Obter informações
INSTALL_DIR="/opt/sistema-gestao-softwares"
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Erro: Diretório de instalação não encontrado: $INSTALL_DIR${NC}"
    echo "Por favor, informe o diretório de instalação:"
    read -p "Diretório: " INSTALL_DIR
fi

cd "$INSTALL_DIR"

# Verificar arquivo docker-compose
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
else
    echo -e "${RED}Erro: Arquivo docker-compose não encontrado!${NC}"
    exit 1
fi

echo -e "${YELLOW}Usando arquivo: $COMPOSE_FILE${NC}"

# Parar containers
echo -e "${YELLOW}1. Parando containers...${NC}"
docker-compose -f $COMPOSE_FILE down

# Remover volume do banco
echo -e "${YELLOW}2. Removendo volume do banco de dados...${NC}"
docker volume rm sistema-gestao-softwares_postgres_data 2>/dev/null || true
docker volume rm sistema-de-gesto-de-softwares_postgres_data 2>/dev/null || true
docker volume rm sistema-de-gest-o-de-softwares_postgres_data 2>/dev/null || true

# Verificar se existe .env
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}3. Criando arquivo .env...${NC}"
    
    read -sp "Digite a senha para o banco de dados: " DB_PASSWORD
    echo
    read -sp "Digite o JWT Secret (deixe em branco para gerar): " JWT_SECRET
    echo
    
    if [ -z "$JWT_SECRET" ]; then
        JWT_SECRET=$(openssl rand -base64 32)
        echo -e "${GREEN}JWT Secret gerado automaticamente${NC}"
    fi
    
    cat > .env << EOF
# Database
DATABASE_URL=postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub
DB_PASSWORD=${DB_PASSWORD}

# JWT
JWT_SECRET=${JWT_SECRET}

# Environment
NODE_ENV=production
EOF
    
    chmod 600 .env
    echo -e "${GREEN}✓ Arquivo .env criado${NC}"
else
    echo -e "${YELLOW}3. Arquivo .env já existe${NC}"
    # Ler a senha do .env existente
    if grep -q "DB_PASSWORD=" .env; then
        DB_PASSWORD=$(grep "DB_PASSWORD=" .env | cut -d'=' -f2)
    elif grep -q "DATABASE_URL=" .env; then
        # Extrair senha da DATABASE_URL
        DB_PASSWORD=$(grep "DATABASE_URL=" .env | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    fi
fi

# Atualizar docker-compose com a senha correta
echo -e "${YELLOW}4. Atualizando configuração do Docker Compose...${NC}"

# Criar backup do arquivo original
cp $COMPOSE_FILE ${COMPOSE_FILE}.backup

# Se for o arquivo de produção, garantir que a senha está correta
if [ "$COMPOSE_FILE" = "docker-compose.production.yml" ]; then
    # Verificar se a variável DB_PASSWORD está sendo usada
    if ! grep -q "POSTGRES_PASSWORD: \${DB_PASSWORD}" $COMPOSE_FILE; then
        # Atualizar para usar a variável de ambiente
        sed -i 's/POSTGRES_PASSWORD:.*/POSTGRES_PASSWORD: ${DB_PASSWORD}/' $COMPOSE_FILE
    fi
fi

# Criar arquivo temporário com variáveis de ambiente
cat > .env.temp << EOF
DB_PASSWORD=${DB_PASSWORD}
EOF

# Iniciar apenas o banco de dados primeiro
echo -e "${YELLOW}5. Iniciando banco de dados...${NC}"
DB_PASSWORD=${DB_PASSWORD} docker-compose -f $COMPOSE_FILE up -d db

# Aguardar o banco inicializar
echo -e "${YELLOW}6. Aguardando banco de dados inicializar...${NC}"
sleep 10

# Verificar se o banco está acessível
echo -e "${YELLOW}7. Verificando conexão com o banco...${NC}"
docker exec $(docker ps -q -f name=db) pg_isready -U softwarehub_user -d softwarehub

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Banco de dados está acessível!${NC}"
else
    echo -e "${RED}✗ Banco de dados não está acessível${NC}"
    echo -e "${YELLOW}Verificando logs do banco...${NC}"
    docker logs $(docker ps -q -f name=db) --tail 50
    exit 1
fi

# Iniciar os outros serviços
echo -e "${YELLOW}8. Iniciando demais serviços...${NC}"
DB_PASSWORD=${DB_PASSWORD} docker-compose -f $COMPOSE_FILE up -d

# Remover arquivo temporário
rm -f .env.temp

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Correção concluída!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Informações importantes:${NC}"
echo "- Senha do banco: ${DB_PASSWORD}"
echo "- Arquivo de configuração: $COMPOSE_FILE"
echo "- Diretório: $INSTALL_DIR"
echo ""
echo -e "${YELLOW}Para verificar o status:${NC}"
echo "docker-compose -f $COMPOSE_FILE ps"
echo ""
echo -e "${YELLOW}Para ver os logs:${NC}"
echo "docker-compose -f $COMPOSE_FILE logs -f"
echo ""
echo -e "${GREEN}Login padrão do sistema:${NC}"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"