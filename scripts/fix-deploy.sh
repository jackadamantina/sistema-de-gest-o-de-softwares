#!/bin/bash

# Script para corrigir problemas de deploy
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Corrigindo problemas de deploy...${NC}"

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.production.yml" ]; then
    echo -e "${RED}❌ docker-compose.production.yml não encontrado no diretório atual${NC}"
    echo -e "${YELLOW}📁 Diretório atual: $(pwd)${NC}"
    echo -e "${YELLOW}📋 Arquivos encontrados:${NC}"
    ls -la *.yml 2>/dev/null || echo "Nenhum arquivo .yml encontrado"
    exit 1
fi

# Verificar se o diretório de instalação existe
INSTALL_DIR="/opt/sistema-gestao-softwares"
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}📁 Criando diretório de instalação...${NC}"
    mkdir -p "$INSTALL_DIR"
fi

# Copiar arquivos manualmente
echo -e "${YELLOW}📋 Copiando arquivos para $INSTALL_DIR...${NC}"

# Copiar docker-compose.production.yml primeiro
cp docker-compose.production.yml "$INSTALL_DIR/"
echo -e "${GREEN}✅ docker-compose.production.yml copiado${NC}"

# Copiar outros arquivos necessários
cp -r backend "$INSTALL_DIR/" 2>/dev/null || echo -e "${YELLOW}⚠️  backend já existe${NC}"
cp -r frontend "$INSTALL_DIR/" 2>/dev/null || echo -e "${YELLOW}⚠️  frontend já existe${NC}"
cp -r scripts "$INSTALL_DIR/" 2>/dev/null || echo -e "${YELLOW}⚠️  scripts já existe${NC}"
cp *.html "$INSTALL_DIR/" 2>/dev/null || echo -e "${YELLOW}⚠️  HTML files já existem${NC}"
cp VERSION "$INSTALL_DIR/" 2>/dev/null || echo -e "${YELLOW}⚠️  VERSION já existe${NC}"

# Verificar se os arquivos foram copiados
echo -e "${YELLOW}🔍 Verificando arquivos copiados...${NC}"
cd "$INSTALL_DIR"

if [ -f "docker-compose.production.yml" ]; then
    echo -e "${GREEN}✅ docker-compose.production.yml encontrado${NC}"
else
    echo -e "${RED}❌ docker-compose.production.yml não encontrado${NC}"
    exit 1
fi

# Criar arquivo .env se não existir
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}📝 Criando arquivo .env...${NC}"
    cat > .env << EOF
# ===================================
# Configurações de Produção
# ===================================

# Database
DB_PASSWORD=SoftwareHub@2024Secure
DATABASE_URL=postgresql://softwarehub_user:SoftwareHub@2024Secure@db:5432/softwarehub

# Security
JWT_SECRET=DefaultJWTSecretChangeInProduction2024

# Environment
NODE_ENV=production

# Ports
FRONTEND_PORT=8089
BACKEND_PORT=3002

# URLs
APP_URL=http://soft-inventario-xp.wake.tech:8089
API_URL=http://soft-inventario-xp.wake.tech:3002
EOF
    chmod 600 .env
    echo -e "${GREEN}✅ Arquivo .env criado${NC}"
fi

# Verificar se o backend tem o arquivo VERSION
if [ -f "VERSION" ] && [ -d "backend" ]; then
    echo -e "${YELLOW}📋 Copiando VERSION para backend...${NC}"
    cp VERSION backend/VERSION
    echo -e "${GREEN}✅ VERSION copiado para backend${NC}"
fi

echo -e "${GREEN}🎉 Problemas de deploy corrigidos!${NC}"
echo -e "${BLUE}💡 Agora você pode executar:${NC}"
echo -e "${YELLOW}   cd $INSTALL_DIR${NC}"
echo -e "${YELLOW}   docker-compose -f docker-compose.production.yml up -d${NC}" 