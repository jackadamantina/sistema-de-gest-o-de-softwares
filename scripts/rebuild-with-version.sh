#!/bin/bash

# Script para Rebuild com Versão Correta - SoftwareHub
# Força rebuild do container com a versão atual

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Rebuild com Versão Correta - SoftwareHub    ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Verificar se arquivo VERSION existe
if [ ! -f "VERSION" ]; then
    log_error "Arquivo VERSION não encontrado"
    exit 1
fi

CURRENT_VERSION=$(cat VERSION)
log_info "📄 Versão atual: v${CURRENT_VERSION}"

# 1. Copiar arquivo VERSION
log_info "📋 Passo 1/4: Copiando arquivo VERSION..."
cp VERSION backend/VERSION
log_success "Arquivo VERSION copiado para backend/"
echo -e "${BLUE}   Conteúdo: $(cat backend/VERSION)${NC}"

# 2. Parar containers
log_info "🛑 Passo 2/4: Parando containers..."
if [ -f "docker-compose.production.yml" ]; then
    docker-compose -f docker-compose.production.yml down
else
    docker-compose down
fi
log_success "Containers parados"

# 3. Rebuild backend
log_info "🔨 Passo 3/4: Rebuild do backend..."
if [ -f "docker-compose.production.yml" ]; then
    docker-compose -f docker-compose.production.yml build --no-cache backend
    docker-compose -f docker-compose.production.yml up -d
else
    docker-compose build --no-cache backend
    docker-compose up -d
fi
log_success "Backend rebuildado"

# 4. Aguardar e verificar
log_info "⏳ Passo 4/4: Aguardando inicialização..."
sleep 15

# Verificar se está funcionando
log_info "🔍 Verificando resultado..."

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

# Verificar versão
log_info "📊 Verificando versão..."
if [ -f "scripts/check-version.sh" ]; then
    ./scripts/check-version.sh
else
    log_warning "Script de verificação não encontrado"
fi

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Rebuild Concluído                            ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "${GREEN}✅ Rebuild com versão v${CURRENT_VERSION} concluído!${NC}" 