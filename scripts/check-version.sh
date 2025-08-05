#!/bin/bash

# Script para verificar a versão atual do sistema
# Compara a versão do arquivo VERSION com a versão em execução

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Verificação de Versão do Sistema           ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Verificar se o arquivo VERSION existe
if [ ! -f "VERSION" ]; then
    echo -e "${RED}❌ Arquivo VERSION não encontrado${NC}"
    exit 1
fi

# Ler versão do arquivo VERSION
FILE_VERSION=$(cat VERSION)
echo -e "${BLUE}📄 Versão no arquivo VERSION: ${YELLOW}v${FILE_VERSION}${NC}"

# Verificar se o backend está rodando
echo ""
echo -e "${BLUE}🔍 Verificando se o backend está rodando...${NC}"

# Tentar conectar no endpoint de versão
BACKEND_URL="http://localhost:3002"
VERSION_ENDPOINT="${BACKEND_URL}/version"

if curl -s --connect-timeout 5 "${VERSION_ENDPOINT}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend está rodando${NC}"
    
    # Obter informações da versão via API
    echo -e "${BLUE}📡 Obtendo informações da versão via API...${NC}"
    
    RESPONSE=$(curl -s "${VERSION_ENDPOINT}")
    
    if [ $? -eq 0 ]; then
        # Debug: mostrar resposta bruta
        echo -e "${BLUE}🔍 Resposta da API: ${YELLOW}${RESPONSE}${NC}"
        
        # Extrair versão da resposta JSON (usando jq se disponível, senão grep)
        if command -v jq >/dev/null 2>&1; then
            RUNNING_VERSION=$(echo "$RESPONSE" | jq -r '.version // "null"')
            BUILD_DATE=$(echo "$RESPONSE" | jq -r '.buildDate // "null"')
            UPTIME=$(echo "$RESPONSE" | jq -r '.uptime // "null"')
        else
            # Fallback para grep - mais robusto
            RUNNING_VERSION=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "null")
            BUILD_DATE=$(echo "$RESPONSE" | grep -o '"buildDate":"[^"]*"' | cut -d'"' -f4 || echo "null")
            UPTIME=$(echo "$RESPONSE" | grep -o '"uptime":[0-9.]*' | cut -d':' -f2 || echo "null")
        fi
        
        # Verificar se extraiu corretamente
        if [ "$RUNNING_VERSION" = "null" ] || [ -z "$RUNNING_VERSION" ]; then
            echo -e "${RED}❌ Erro ao extrair versão da resposta da API${NC}"
            echo -e "${YELLOW}💡 Tentando método alternativo...${NC}"
            
            # Método alternativo usando sed
            RUNNING_VERSION=$(echo "$RESPONSE" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
            BUILD_DATE=$(echo "$RESPONSE" | sed -n 's/.*"buildDate":"\([^"]*\)".*/\1/p')
            UPTIME=$(echo "$RESPONSE" | sed -n 's/.*"uptime":\([0-9.]*\).*/\1/p')
        fi
        
        echo -e "${BLUE}🖥️  Versão em execução: ${YELLOW}v${RUNNING_VERSION}${NC}"
        echo -e "${BLUE}📅 Data do build: ${YELLOW}${BUILD_DATE}${NC}"
        echo -e "${BLUE}⏱️  Uptime: ${YELLOW}${UPTIME} segundos${NC}"
        
        # Comparar versões
        echo ""
        echo -e "${CYAN}=== Comparação de Versões ===${NC}"
        
        if [ "$FILE_VERSION" = "$RUNNING_VERSION" ]; then
            echo -e "${GREEN}✅ Versões são iguais!${NC}"
            echo -e "${GREEN}   Sistema está atualizado com a versão mais recente${NC}"
        else
            echo -e "${RED}❌ Versões são diferentes!${NC}"
            echo -e "${YELLOW}   Arquivo VERSION: v${FILE_VERSION}${NC}"
            echo -e "${YELLOW}   Sistema rodando: v${RUNNING_VERSION}${NC}"
            echo ""
            echo -e "${YELLOW}💡 Recomendações:${NC}"
            echo -e "${YELLOW}   1. Execute o deploy novamente: ./deploy-production.sh${NC}"
            echo -e "${YELLOW}   2. Reinicie os containers: docker-compose restart${NC}"
            echo -e "${YELLOW}   3. Verifique se há atualizações pendentes${NC}"
        fi
        
    else
        echo -e "${RED}❌ Erro ao obter informações da API${NC}"
    fi
    
else
    echo -e "${RED}❌ Backend não está rodando ou não responde${NC}"
    echo -e "${YELLOW}💡 Verifique se os containers estão rodando:${NC}"
    echo -e "${YELLOW}   docker-compose ps${NC}"
    echo -e "${YELLOW}   docker-compose up -d${NC}"
fi

echo ""
echo -e "${CYAN}=== Informações Adicionais ===${NC}"

# Verificar containers Docker
echo -e "${BLUE}🐳 Status dos containers:${NC}"
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose ps
else
    echo -e "${YELLOW}⚠️  docker-compose não encontrado${NC}"
fi

# Verificar logs recentes
echo ""
echo -e "${BLUE}📋 Logs recentes do backend:${NC}"
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose logs --tail=10 backend 2>/dev/null || echo -e "${YELLOW}⚠️  Não foi possível obter logs${NC}"
else
    echo -e "${YELLOW}⚠️  docker-compose não encontrado${NC}"
fi

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Verificação concluída                        ${NC}"
echo -e "${CYAN}================================================${NC}" 