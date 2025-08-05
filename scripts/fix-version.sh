#!/bin/bash

# Script de Correção de Versão - SoftwareHub
# Corrige problemas com o endpoint de versão

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Correção de Versão - SoftwareHub            ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 1. Verificar se arquivo VERSION existe
log_info "📄 Verificando arquivo VERSION..."
if [ ! -f "VERSION" ]; then
    log_error "Arquivo VERSION não encontrado no diretório atual"
    exit 1
fi

VERSION_CONTENT=$(cat VERSION)
log_success "Versão atual: v${VERSION_CONTENT}"

# 2. Copiar arquivo VERSION para locais possíveis
log_info "📋 Copiando arquivo VERSION para locais possíveis..."

POSSIBLE_PATHS=(
    "/opt/sistema-gestao-softwares/VERSION"
    "/opt/sistema-gest-o-de-softwares/VERSION"
    "/root/sistema-de-gest-o-de-softwares/VERSION"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    dir=$(dirname "$path")
    if [ ! -d "$dir" ]; then
        log_warning "Diretório não existe: $dir"
        continue
    fi
    
    cp VERSION "$path" 2>/dev/null && log_success "Copiado para: $path" || log_warning "Não foi possível copiar para: $path"
done

# 3. Reiniciar backend
log_info "🔄 Reiniciando backend..."
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose restart backend
    log_success "Backend reiniciado"
    
    # Aguardar backend inicializar
    log_info "⏳ Aguardando backend inicializar..."
    sleep 10
else
    log_warning "docker-compose não encontrado"
fi

# 4. Verificar se backend está respondendo
log_info "🔍 Verificando se backend está respondendo..."
if curl -s --connect-timeout 10 "http://localhost:3002/health" > /dev/null 2>&1; then
    log_success "Backend está respondendo"
else
    log_error "Backend não está respondendo após reinicialização"
    exit 1
fi

# 5. Testar endpoint de versão
log_info "📡 Testando endpoint /version..."
RESPONSE=$(curl -s "http://localhost:3002/version")
if [ $? -eq 0 ]; then
    log_success "Endpoint /version respondeu"
    
    # Extrair versão da resposta
    if command -v jq >/dev/null 2>&1; then
        VERSION_FROM_API=$(echo "$RESPONSE" | jq -r '.version // "null"')
    else
        VERSION_FROM_API=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "null")
    fi
    
    if [ "$VERSION_FROM_API" != "null" ] && [ "$VERSION_FROM_API" != "" ]; then
        log_success "Versão extraída da API: v${VERSION_FROM_API}"
        
        if [ "$VERSION_FROM_API" = "$VERSION_CONTENT" ]; then
            log_success "✅ Versões são iguais!"
        else
            log_warning "⚠️  Versões são diferentes:"
            log_warning "   Arquivo VERSION: v${VERSION_CONTENT}"
            log_warning "   API: v${VERSION_FROM_API}"
        fi
    else
        log_error "❌ Não foi possível extrair versão da API"
        echo -e "${BLUE}📋 Resposta da API:${NC}"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    fi
else
    log_error "Endpoint /version não respondeu"
    exit 1
fi

# 6. Executar verificação completa
echo ""
log_info "🔍 Executando verificação completa..."
./scripts/check-version.sh

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Correção concluída                          ${NC}"
echo -e "${CYAN}================================================${NC}"

# Recomendações finais
echo ""
echo -e "${BLUE}💡 Se o problema persistir:${NC}"
echo -e "${YELLOW}   1. Verifique os logs: docker-compose logs backend${NC}"
echo -e "${YELLOW}   2. Execute diagnóstico: ./scripts/diagnose-version.sh${NC}"
echo -e "${YELLOW}   3. Reconstrua o container: docker-compose build backend${NC}"
echo -e "${YELLOW}   4. Faça deploy completo: ./scripts/quick-deploy.sh${NC}" 