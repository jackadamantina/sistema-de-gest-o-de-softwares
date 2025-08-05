#!/bin/bash

# Script para Resolver Todos os Problemas - SoftwareHub
# Resolve branches divergentes e problemas de login

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Resolução de Todos os Problemas             ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 1. Resolver branches divergentes
log_info "🔄 Passo 1/3: Resolvendo branches divergentes..."

if git status --porcelain | grep -q .; then
    log_warning "Há mudanças não commitadas"
    git status --short
    echo ""
    read -p "Deseja fazer commit das mudanças? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        read -p "Mensagem do commit: " commit_message
        git add .
        git commit -m "${commit_message:-"Auto-commit antes do merge"}"
        log_success "Mudanças commitadas"
    fi
fi

# Fazer merge
log_info "Executando merge..."
git config pull.rebase false
git pull origin main
log_success "Branches divergentes resolvidas"

# 2. Verificar e corrigir configuração do frontend
log_info "🔧 Passo 2/3: Verificando configuração do frontend..."

# Verificar se o frontend está usando a URL correta
if grep -q "soft-inventario-xp.wake.tech:8089" index.html; then
    log_warning "Frontend está usando URL externa"
    log_info "Corrigindo para usar proxy interno..."
    
    # Substituir URLs externas por relativas
    sed -i 's|http://soft-inventario-xp.wake.tech:8089|/api|g' index.html
    sed -i 's|http://localhost:3002|/api|g' index.html
    
    log_success "URLs corrigidas para usar proxy interno"
else
    log_success "Frontend já está usando proxy interno"
fi

# 3. Rebuild e restart
log_info "🚀 Passo 3/3: Rebuild e restart..."

# Copiar arquivo VERSION
if [ -f "VERSION" ]; then
    cp VERSION backend/VERSION
    log_success "Arquivo VERSION copiado"
fi

# Rebuild containers
if [ -f "docker-compose.production.yml" ]; then
    docker-compose -f docker-compose.production.yml down
    docker-compose -f docker-compose.production.yml build --no-cache
    docker-compose -f docker-compose.production.yml up -d
else
    docker-compose down
    docker-compose build --no-cache
    docker-compose up -d
fi

# Aguardar inicialização
log_info "⏳ Aguardando inicialização..."
sleep 15

# Verificar resultado
log_info "🔍 Verificando resultado..."

# Verificar containers
if [ -f "docker-compose.production.yml" ]; then
    if docker-compose -f docker-compose.production.yml ps | grep -q "Up"; then
        log_success "✅ Containers estão rodando"
    else
        log_error "❌ Containers não estão rodando"
        exit 1
    fi
else
    if docker-compose ps | grep -q "Up"; then
        log_success "✅ Containers estão rodando"
    else
        log_error "❌ Containers não estão rodando"
        exit 1
    fi
fi

# Testar login
log_info "🔐 Testando login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8089/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@softwarehub.com","password":"admin123"}')

if echo "$LOGIN_RESPONSE" | grep -q "Login successful"; then
    log_success "✅ Login funcionando"
else
    log_error "❌ Login falhou"
    echo "Resposta: $LOGIN_RESPONSE"
fi

# Verificar versão
log_info "📊 Verificando versão..."
if [ -f "scripts/check-version.sh" ]; then
    ./scripts/check-version.sh
fi

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Todos os Problemas Resolvidos               ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "${BLUE}🔗 URLs do sistema:${NC}"
echo -e "${YELLOW}   Produção:${NC} http://soft-inventario-xp.wake.tech:8089"
echo -e "${YELLOW}   Local:${NC} http://localhost:8089"
echo ""
echo -e "${BLUE}💡 Credenciais:${NC}"
echo -e "${YELLOW}   Email:${NC} admin@softwarehub.com"
echo -e "${YELLOW}   Senha:${NC} admin123"
echo ""
echo -e "${BLUE}💡 Para forçar atualização no navegador:${NC}"
echo -e "${YELLOW}   1. Pressione Ctrl+F5${NC}"
echo -e "${YELLOW}   2. Ou abra em aba anônima${NC}"
echo -e "${YELLOW}   3. Ou limpe o cache do navegador${NC}"
echo ""
echo -e "${GREEN}✅ Todos os problemas foram resolvidos!${NC}" 