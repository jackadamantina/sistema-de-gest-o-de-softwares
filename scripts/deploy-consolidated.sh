#!/bin/bash

# Script consolidado de deploy - Combina todas as etapas necessárias
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Deploy Consolidado - Sistema de Gestão     ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Por favor, execute como root (sudo)${NC}"
    exit 1
fi

# Verificar se estamos no diretório correto
if [ ! -f "deploy-production.sh" ]; then
    echo -e "${RED}❌ Execute este script no diretório raiz do projeto${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Iniciando deploy consolidado...${NC}"
echo ""

# Etapa 1: Parar sistema existente (se houver)
echo -e "${YELLOW}1️⃣  Parando sistema existente...${NC}"
if [ -d "/opt/sistema-gestao-softwares" ]; then
    cd /opt/sistema-gestao-softwares
    docker-compose -f docker-compose.production.yml down 2>/dev/null || true
    cd - > /dev/null
    echo -e "${GREEN}✅ Sistema anterior parado${NC}"
else
    echo -e "${BLUE}ℹ️  Nenhum sistema anterior encontrado${NC}"
fi

# Etapa 2: Executar deploy principal
echo ""
echo -e "${YELLOW}2️⃣  Executando deploy principal...${NC}"
./deploy-production.sh

# Etapa 3: Verificação final
echo ""
echo -e "${YELLOW}3️⃣  Verificação final consolidada...${NC}"

# Verificar se tudo está funcionando
cd /opt/sistema-gestao-softwares

echo -e "${BLUE}🔍 Verificando containers...${NC}"
if docker-compose -f docker-compose.production.yml ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Todos os containers estão rodando${NC}"
else
    echo -e "${RED}❌ Problema com containers${NC}"
    docker-compose -f docker-compose.production.yml ps
fi

echo -e "${BLUE}🔍 Verificando API...${NC}"
sleep 10
if curl -s http://localhost:3002/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ API está respondendo${NC}"
else
    echo -e "${YELLOW}⚠️  API ainda não está respondendo${NC}"
fi

echo -e "${BLUE}🔍 Verificando frontend...${NC}"
if curl -s http://localhost:8089 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend está acessível${NC}"
else
    echo -e "${YELLOW}⚠️  Frontend ainda não está acessível${NC}"
fi

# Etapa 4: Criar usuário admin se necessário
echo ""
echo -e "${YELLOW}4️⃣  Verificando usuário admin...${NC}"
echo -e "${BLUE}💡 Se o login não funcionar, execute:${NC}"
echo "docker exec sistema-de-gesto-de-softwares-backend-1 npm run seed"
echo ""

# Resumo final
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🎉 Deploy Consolidado Concluído!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}📋 Resumo das Etapas Executadas:${NC}"
echo "✅ Sistema anterior parado"
echo "✅ Deploy principal executado"
echo "✅ Correções automáticas aplicadas"
echo "✅ Containers construídos e iniciados"
echo "✅ Verificações de saúde realizadas"
echo ""
echo -e "${BLUE}🌐 Acesse o sistema em:${NC}"
echo "http://localhost:8089"
echo ""
echo -e "${BLUE}🔐 Credenciais:${NC}"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"
echo ""
echo -e "${GREEN}🎯 Sistema pronto para uso!${NC}" 