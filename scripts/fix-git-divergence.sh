#!/bin/bash

# Script para Resolver Branches Divergentes - SoftwareHub
# Resolve conflitos de branches de forma segura

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Resolução de Branches Divergentes           ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Verificar se estamos em um repositório Git
if [ ! -d ".git" ]; then
    log_error "Não é um repositório Git"
    exit 1
fi

# Mostrar status atual
log_info "📊 Status atual do Git:"
git status --short

echo ""
log_info "📋 Últimos commits locais:"
git log --oneline -5

echo ""
log_info "📋 Últimos commits remotos:"
git fetch origin
git log --oneline origin/main -5

echo ""
echo -e "${YELLOW}💡 Opções para resolver branches divergentes:${NC}"
echo -e "${YELLOW}   1. Merge (recomendado) - mantém histórico completo${NC}"
echo -e "${YELLOW}   2. Rebase - reescreve histórico local${NC}"
echo -e "${YELLOW}   3. Reset - descarta mudanças locais${NC}"
echo ""

read -p "Escolha uma opção (1-3): " -n 1 -r
echo

case $REPLY in
    1)
        log_info "🔄 Executando merge..."
        git config pull.rebase false
        git pull origin main
        log_success "Merge concluído"
        ;;
    2)
        log_info "🔄 Executando rebase..."
        git config pull.rebase true
        git pull origin main
        log_success "Rebase concluído"
        ;;
    3)
        log_warning "⚠️  ATENÇÃO: Isso vai descartar todas as mudanças locais!"
        read -p "Tem certeza? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            log_info "🔄 Executando reset..."
            git fetch origin
            git reset --hard origin/main
            log_success "Reset concluído"
        else
            log_info "Operação cancelada"
            exit 0
        fi
        ;;
    *)
        log_error "Opção inválida"
        exit 1
        ;;
esac

# Verificar resultado
echo ""
log_info "📊 Status após resolução:"
git status

echo ""
log_info "📋 Últimos commits:"
git log --oneline -5

echo ""
echo -e "${GREEN}✅ Branches divergentes resolvidas!${NC}" 