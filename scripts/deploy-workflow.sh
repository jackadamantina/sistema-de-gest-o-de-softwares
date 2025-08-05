#!/bin/bash

# Script de Deploy Workflow - SoftwareHub
# Automatiza o fluxo completo de deploy: stop → git pull → deploy → verify

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   SoftwareHub - Deploy Workflow               ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Verificar se está no diretório correto
if [ ! -f "VERSION" ] || [ ! -f "docker-compose.yml" ]; then
    log_error "Execute este script no diretório raiz do projeto"
    exit 1
fi

# Verificar se git está disponível
if ! command -v git &> /dev/null; then
    log_error "Git não está instalado"
    exit 1
fi

# Verificar se docker-compose está disponível
if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose não está instalado"
    exit 1
fi

# Função para parar o sistema
stop_system() {
    log_info "🛑 Parando o sistema..."
    
    # Tentar parar via systemctl primeiro
    if systemctl is-active --quiet softwarehub 2>/dev/null; then
        log_info "Parando via systemctl..."
        systemctl stop softwarehub
        log_success "Sistema parado via systemctl"
    else
        log_info "Parando containers diretamente..."
        docker-compose down
        log_success "Containers parados"
    fi
    
    # Aguardar um pouco para garantir que tudo parou
    sleep 3
}

# Função para atualizar código
update_code() {
    log_info "📥 Atualizando código do repositório..."
    
    # Verificar se há mudanças não commitadas
    if [ -n "$(git status --porcelain)" ]; then
        log_warning "Há mudanças não commitadas no repositório"
        echo "Mudanças detectadas:"
        git status --short
        echo ""
        read -p "Deseja fazer commit das mudanças? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Mensagem do commit: " commit_message
            git add .
            git commit -m "${commit_message:-"Auto-commit antes do deploy"}"
            log_success "Mudanças commitadas"
        fi
    fi
    
    # Fazer pull das mudanças
    log_info "Fazendo git pull..."
    git pull origin main || git pull origin master || git pull
    
    # Verificar se houve mudanças
    if [ $? -eq 0 ]; then
        log_success "Código atualizado com sucesso"
        
        # Mostrar últimas mudanças
        echo ""
        log_info "📋 Últimas mudanças:"
        git log --oneline -5
    else
        log_error "Erro ao atualizar código"
        exit 1
    fi
}

# Função para verificar versão atual
check_current_version() {
    log_info "🔍 Verificando versão atual..."
    
    if [ -f "scripts/check-version.sh" ]; then
        ./scripts/check-version.sh
    else
        log_warning "Script de verificação não encontrado"
    fi
}

# Função para fazer deploy
run_deploy() {
    log_info "🚀 Iniciando deploy..."
    
    if [ -f "deploy-production.sh" ]; then
        ./deploy-production.sh
    else
        log_error "Script de deploy não encontrado"
        exit 1
    fi
}

# Função para verificar se deploy foi bem-sucedido
verify_deploy() {
    log_info "🔍 Verificando se o deploy foi bem-sucedido..."
    
    # Aguardar um pouco para os containers iniciarem
    sleep 10
    
    # Verificar se containers estão rodando
    if docker-compose ps | grep -q "Up"; then
        log_success "Containers estão rodando"
    else
        log_error "Containers não estão rodando"
        docker-compose ps
        exit 1
    fi
    
    # Verificar se API está respondendo
    if curl -s --connect-timeout 5 "http://localhost:3002/health" > /dev/null; then
        log_success "API está respondendo"
    else
        log_warning "API não está respondendo ainda"
    fi
    
    # Verificar versão final
    if [ -f "scripts/check-version.sh" ]; then
        echo ""
        log_info "📊 Verificação final da versão:"
        ./scripts/check-version.sh
    fi
}

# Função para mostrar resumo
show_summary() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}   Resumo do Deploy                          ${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    # Informações do sistema
    echo -e "${BLUE}📊 Status do sistema:${NC}"
    docker-compose ps
    
    echo ""
    echo -e "${BLUE}🔗 URLs do sistema:${NC}"
    echo -e "${YELLOW}   Frontend:${NC} http://localhost:8088"
    echo -e "${YELLOW}   Backend API:${NC} http://localhost:3002"
    echo -e "${YELLOW}   Health Check:${NC} http://localhost:3002/health"
    echo -e "${YELLOW}   Version Info:${NC} http://localhost:3002/version"
    
    echo ""
    echo -e "${BLUE}📋 Comandos úteis:${NC}"
    echo -e "${YELLOW}   Verificar versão:${NC} ./scripts/check-version.sh"
    echo -e "${YELLOW}   Ver logs:${NC} docker-compose logs -f"
    echo -e "${YELLOW}   Parar sistema:${NC} systemctl stop softwarehub"
    echo -e "${YELLOW}   Reiniciar:${NC} systemctl restart softwarehub"
    
    echo ""
    echo -e "${GREEN}✅ Deploy concluído com sucesso!${NC}"
}

# Função principal
main() {
    local step=1
    local total_steps=5
    
    echo -e "${BLUE}🔄 Iniciando fluxo de deploy (${step}/${total_steps})${NC}"
    
    # Passo 1: Verificar versão atual
    log_info "Passo ${step}/${total_steps}: Verificando versão atual"
    check_current_version
    ((step++))
    
    # Passo 2: Parar sistema
    log_info "Passo ${step}/${total_steps}: Parando sistema"
    stop_system
    ((step++))
    
    # Passo 3: Atualizar código
    log_info "Passo ${step}/${total_steps}: Atualizando código"
    update_code
    ((step++))
    
    # Passo 4: Fazer deploy
    log_info "Passo ${step}/${total_steps}: Executando deploy"
    run_deploy
    ((step++))
    
    # Passo 5: Verificar deploy
    log_info "Passo ${step}/${total_steps}: Verificando deploy"
    verify_deploy
    
    # Mostrar resumo
    show_summary
}

# Executar função principal
main "$@" 