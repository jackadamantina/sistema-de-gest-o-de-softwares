#!/bin/bash

# Script para Limpar Cache e Forçar Atualização - SoftwareHub
# Força a atualização do frontend e limpa cache

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Limpeza de Cache - SoftwareHub              ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 1. Adicionar timestamp ao index.html para forçar cache bust
log_info "🔄 Adicionando timestamp para forçar atualização do cache..."

if [ -f "index.html" ]; then
    # Criar backup
    cp index.html index.html.backup
    
    # Adicionar comentário com timestamp
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sed -i "1i<!-- Cache bust: $TIMESTAMP -->" index.html
    
    log_success "Timestamp adicionado: $TIMESTAMP"
else
    log_error "Arquivo index.html não encontrado"
    exit 1
fi

# 2. Atualizar versão no frontend
log_info "📝 Atualizando versão no frontend..."
if [ -f "scripts/update-frontend-version.sh" ]; then
    ./scripts/update-frontend-version.sh
else
    log_warning "Script de atualização não encontrado"
fi

# 3. Reiniciar frontend
log_info "🔄 Reiniciando frontend..."
if command -v docker-compose >/dev/null 2>&1; then
    if [ -f "docker-compose.production.yml" ]; then
        docker-compose -f docker-compose.production.yml restart frontend
    else
        docker-compose restart frontend
    fi
    log_success "Frontend reiniciado"
else
    log_warning "docker-compose não encontrado"
fi

# 4. Aguardar frontend inicializar
log_info "⏳ Aguardando frontend inicializar..."
sleep 5

# 5. Verificar se está funcionando
log_info "🔍 Verificando se frontend está respondendo..."
if curl -s --connect-timeout 10 "http://localhost:8089" > /dev/null 2>&1 || curl -s --connect-timeout 10 "http://localhost:8088" > /dev/null 2>&1; then
    log_success "Frontend está respondendo"
else
    log_warning "Frontend pode não estar respondendo ainda"
fi

# 6. Mostrar instruções para o usuário
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Cache Limpo - Instruções                    ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "${BLUE}💡 Para forçar atualização no navegador:${NC}"
echo -e "${YELLOW}   1. Pressione Ctrl+F5 (ou Cmd+Shift+R no Mac)${NC}"
echo -e "${YELLOW}   2. Ou abra em aba anônima/privada${NC}"
echo -e "${YELLOW}   3. Ou limpe o cache do navegador${NC}"
echo ""
echo -e "${BLUE}🔗 URLs do sistema:${NC}"
echo -e "${YELLOW}   Produção:${NC} http://soft-inventario-xp.wake.tech:8089"
echo -e "${YELLOW}   Local:${NC} http://localhost:8089"
echo ""
echo -e "${BLUE}📋 Comandos úteis:${NC}"
echo -e "${YELLOW}   Ver logs:${NC} docker-compose -f docker-compose.production.yml logs frontend"
echo -e "${YELLOW}   Verificar versão:${NC} ./scripts/check-version.sh"
echo -e "${YELLOW}   Reverter mudanças:${NC} cp index.html.backup index.html"
echo ""
echo -e "${GREEN}✅ Cache limpo com sucesso!${NC}" 