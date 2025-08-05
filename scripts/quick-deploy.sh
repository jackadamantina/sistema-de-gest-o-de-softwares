#!/bin/bash

# Script de Deploy Rápido - SoftwareHub
# Replica o fluxo: sistema-gestao stop → git pull → deploy-production.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   SoftwareHub - Deploy Rápido                 ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Passo 1: Parar sistema
log_info "🛑 Passo 1/3: Parando sistema..."
if systemctl is-active --quiet softwarehub 2>/dev/null; then
    systemctl stop softwarehub
    log_success "Sistema parado via systemctl"
else
    log_info "Parando containers diretamente..."
    docker-compose down
    log_success "Containers parados"
fi

# Aguardar um pouco
sleep 2

# Passo 2: Git pull
log_info "📥 Passo 2/3: Atualizando código..."
git pull origin main || git pull origin master || git pull
if [ $? -eq 0 ]; then
    log_success "Código atualizado com sucesso"
else
    log_error "Erro ao atualizar código"
    exit 1
fi

# Passo 3: Deploy
log_info "🚀 Passo 3/3: Executando deploy..."
./deploy-production.sh

# Verificação final
echo ""
log_info "🔍 Verificando resultado do deploy..."
sleep 5

# Verificar containers usando o arquivo correto
if [ -f "docker-compose.production.yml" ]; then
    if docker-compose -f docker-compose.production.yml ps | grep -q "Up"; then
        log_success "✅ Deploy concluído com sucesso!"
        echo ""
        echo -e "${BLUE}📊 Status dos containers:${NC}"
        docker-compose -f docker-compose.production.yml ps
        echo ""
        echo -e "${BLUE}🔗 URLs:${NC}"
        echo -e "${YELLOW}   Frontend:${NC} http://localhost:8089"
        echo -e "${YELLOW}   Backend:${NC} http://localhost:3002"
    else
        log_error "❌ Deploy falhou - containers não estão rodando"
        docker-compose -f docker-compose.production.yml ps
        exit 1
    fi
else
    if docker-compose ps | grep -q "Up"; then
        log_success "✅ Deploy concluído com sucesso!"
        echo ""
        echo -e "${BLUE}📊 Status dos containers:${NC}"
        docker-compose ps
        echo ""
        echo -e "${BLUE}🔗 URLs:${NC}"
        echo -e "${YELLOW}   Frontend:${NC} http://localhost:8088"
        echo -e "${YELLOW}   Backend:${NC} http://localhost:3002"
    else
        log_error "❌ Deploy falhou - containers não estão rodando"
        docker-compose ps
        exit 1
    fi
fi 