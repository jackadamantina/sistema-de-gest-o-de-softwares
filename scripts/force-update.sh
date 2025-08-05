#!/bin/bash

# Script de Atualização Forçada - SoftwareHub
# Força atualização completa do sistema

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Atualização Forçada - SoftwareHub           ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 1. Parar sistema
log_info "🛑 Passo 1/6: Parando sistema..."
if systemctl is-active --quiet softwarehub 2>/dev/null; then
    systemctl stop softwarehub
    log_success "Sistema parado via systemctl"
else
    log_info "Parando containers diretamente..."
    if [ -f "docker-compose.production.yml" ]; then
        docker-compose -f docker-compose.production.yml down
    else
        docker-compose down
    fi
    log_success "Containers parados"
fi

# 2. Atualizar código
log_info "📥 Passo 2/6: Atualizando código..."
git pull origin main || git pull origin master || git pull
if [ $? -eq 0 ]; then
    log_success "Código atualizado com sucesso"
else
    log_error "Erro ao atualizar código"
    exit 1
fi

# 3. Copiar arquivo VERSION
log_info "📋 Passo 3/6: Copiando arquivo VERSION..."
if [ -f "VERSION" ]; then
    cp VERSION backend/VERSION
    log_success "Arquivo VERSION copiado para backend/"
    echo -e "${BLUE}   Conteúdo: $(cat VERSION)${NC}"
else
    log_warning "Arquivo VERSION não encontrado"
fi

# 4. Limpar cache e rebuild
log_info "🧹 Passo 4/6: Limpando cache e rebuild..."
if [ -f "docker-compose.production.yml" ]; then
    docker-compose -f docker-compose.production.yml down
    docker system prune -f
    docker-compose -f docker-compose.production.yml build --no-cache
    docker-compose -f docker-compose.production.yml up -d
else
    docker-compose down
    docker system prune -f
    docker-compose build --no-cache
    docker-compose up -d
fi

# 5. Aguardar inicialização
log_info "⏳ Passo 5/6: Aguardando inicialização..."
sleep 20

# 6. Verificar resultado
log_info "🔍 Passo 6/6: Verificando resultado..."

# Verificar containers
if [ -f "docker-compose.production.yml" ]; then
    if docker-compose -f docker-compose.production.yml ps | grep -q "Up"; then
        log_success "✅ Containers estão rodando"
        echo ""
        echo -e "${BLUE}📊 Status dos containers:${NC}"
        docker-compose -f docker-compose.production.yml ps
    else
        log_error "❌ Containers não estão rodando"
        docker-compose -f docker-compose.production.yml ps
        exit 1
    fi
else
    if docker-compose ps | grep -q "Up"; then
        log_success "✅ Containers estão rodando"
        echo ""
        echo -e "${BLUE}📊 Status dos containers:${NC}"
        docker-compose ps
    else
        log_error "❌ Containers não estão rodando"
        docker-compose ps
        exit 1
    fi
fi

# Verificar API
log_info "🔍 Verificando API..."
if curl -s --connect-timeout 10 "http://localhost:3002/health" > /dev/null 2>&1; then
    log_success "✅ API está respondendo"
else
    log_warning "⚠️  API pode não estar respondendo ainda"
fi

# Verificar versão
log_info "📊 Verificando versão..."
if [ -f "scripts/check-version.sh" ]; then
    ./scripts/check-version.sh
else
    log_warning "Script de verificação não encontrado"
fi

# Limpar cache do frontend
log_info "🔄 Forçando atualização do frontend..."
if [ -f "scripts/clear-cache.sh" ]; then
    ./scripts/clear-cache.sh
else
    log_warning "Script de limpeza de cache não encontrado"
fi

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Atualização Forçada Concluída               ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "${BLUE}🔗 URLs do sistema:${NC}"
echo -e "${YELLOW}   Produção:${NC} http://soft-inventario-xp.wake.tech:8089"
echo -e "${YELLOW}   Local:${NC} http://localhost:8089"
echo ""
echo -e "${BLUE}💡 Para forçar atualização no navegador:${NC}"
echo -e "${YELLOW}   1. Pressione Ctrl+F5${NC}"
echo -e "${YELLOW}   2. Ou abra em aba anônima${NC}"
echo -e "${YELLOW}   3. Ou limpe o cache do navegador${NC}"
echo ""
echo -e "${GREEN}✅ Atualização forçada concluída com sucesso!${NC}" 