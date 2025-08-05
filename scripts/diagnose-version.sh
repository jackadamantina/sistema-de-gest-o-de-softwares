#!/bin/bash

# Script de Diagnóstico de Versão - SoftwareHub
# Identifica problemas com o endpoint de versão

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Diagnóstico de Versão - SoftwareHub         ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 1. Verificar arquivo VERSION
log_info "📄 Verificando arquivo VERSION..."
if [ -f "VERSION" ]; then
    VERSION_CONTENT=$(cat VERSION)
    log_success "Arquivo VERSION encontrado: v${VERSION_CONTENT}"
else
    log_error "Arquivo VERSION não encontrado no diretório atual"
fi

# 2. Verificar se backend está rodando
log_info "🔍 Verificando se backend está rodando..."
if curl -s --connect-timeout 5 "http://localhost:3002/health" > /dev/null 2>&1; then
    log_success "Backend está respondendo"
else
    log_error "Backend não está respondendo"
    exit 1
fi

# 3. Testar endpoint de versão
log_info "📡 Testando endpoint /version..."
RESPONSE=$(curl -s "http://localhost:3002/version")
if [ $? -eq 0 ]; then
    log_success "Endpoint /version respondeu"
    echo -e "${BLUE}📋 Resposta completa:${NC}"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
else
    log_error "Endpoint /version não respondeu"
    exit 1
fi

# 4. Verificar containers
log_info "🐳 Verificando containers..."
if command -v docker-compose >/dev/null 2>&1; then
    echo -e "${BLUE}📊 Status dos containers:${NC}"
    docker-compose ps
else
    log_warning "docker-compose não encontrado"
fi

# 5. Verificar logs do backend
log_info "📋 Verificando logs do backend..."
if command -v docker-compose >/dev/null 2>&1; then
    echo -e "${BLUE}📋 Últimos logs do backend:${NC}"
    docker-compose logs --tail=20 backend 2>/dev/null || log_warning "Não foi possível obter logs"
else
    log_warning "docker-compose não encontrado"
fi

# 6. Verificar caminhos do arquivo VERSION
log_info "🔍 Verificando caminhos do arquivo VERSION..."
POSSIBLE_PATHS=(
    "./VERSION"
    "/opt/sistema-gestao-softwares/VERSION"
    "/opt/sistema-gest-o-de-softwares/VERSION"
    "/root/sistema-de-gest-o-de-softwares/VERSION"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        log_success "Arquivo VERSION encontrado em: $path"
        echo -e "${YELLOW}   Conteúdo: $(cat "$path")${NC}"
    else
        log_warning "Arquivo VERSION não encontrado em: $path"
    fi
done

# 7. Verificar permissões
log_info "🔐 Verificando permissões..."
if [ -f "VERSION" ]; then
    ls -la VERSION
fi

# 8. Teste de parsing JSON
log_info "🔧 Testando parsing JSON..."
if command -v jq >/dev/null 2>&1; then
    VERSION_FROM_API=$(echo "$RESPONSE" | jq -r '.version // "null"')
    log_info "Versão extraída com jq: $VERSION_FROM_API"
else
    log_warning "jq não está instalado"
fi

# 9. Teste com grep
log_info "🔧 Testando parsing com grep..."
VERSION_FROM_GREP=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "null")
log_info "Versão extraída com grep: $VERSION_FROM_GREP"

# 10. Teste com sed
log_info "🔧 Testando parsing com sed..."
VERSION_FROM_SED=$(echo "$RESPONSE" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
log_info "Versão extraída com sed: $VERSION_FROM_SED"

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Diagnóstico concluído                       ${NC}"
echo -e "${CYAN}================================================${NC}"

# Recomendações
echo ""
echo -e "${BLUE}💡 Recomendações:${NC}"
echo -e "${YELLOW}   1. Se a versão está null, reinicie o backend:${NC}"
echo -e "${YELLOW}      docker-compose restart backend${NC}"
echo -e "${YELLOW}   2. Se o arquivo VERSION não é encontrado, copie-o:${NC}"
echo -e "${YELLOW}      cp VERSION /opt/sistema-gestao-softwares/VERSION${NC}"
echo -e "${YELLOW}   3. Se o parsing falha, instale jq:${NC}"
echo -e "${YELLOW}      apt-get install jq${NC}" 