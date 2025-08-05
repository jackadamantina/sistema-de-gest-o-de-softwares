#!/bin/bash

# Script para Corrigir Servidor de Produção - SoftwareHub
# Resolve todos os problemas no servidor remoto

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Correção do Servidor de Produção            ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Função para log
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 1. Verificar se estamos no servidor correto
log_info "🔍 Passo 1/6: Verificando ambiente..."
HOSTNAME=$(hostname)
echo -e "${BLUE}   Servidor: ${YELLOW}${HOSTNAME}${NC}"

# Verificar se é o servidor de produção
if [[ "$HOSTNAME" == *"core-starcraft"* ]] || [[ "$HOSTNAME" == *"wake"* ]]; then
    log_success "✅ Servidor de produção detectado"
else
    log_warning "⚠️  Verifique se está no servidor correto"
fi

# 2. Parar sistema atual
log_info "🛑 Passo 2/6: Parando sistema atual..."
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

# 3. Atualizar código
log_info "📥 Passo 3/6: Atualizando código..."
git fetch origin
git reset --hard origin/main
log_success "Código atualizado para versão mais recente"

# 4. Verificar e corrigir arquivo VERSION
log_info "📋 Passo 4/6: Verificando arquivo VERSION..."
if [ ! -f "VERSION" ] || [ ! -s "VERSION" ]; then
    log_warning "Arquivo VERSION não existe ou está vazio"
    echo "1.0.9" > VERSION
    log_success "Arquivo VERSION criado com versão 1.0.9"
else
    CURRENT_VERSION=$(cat VERSION)
    log_success "Arquivo VERSION encontrado: v${CURRENT_VERSION}"
fi

# 5. Copiar arquivo VERSION e rebuild
log_info "🔨 Passo 5/6: Rebuild completo..."
cp VERSION backend/VERSION
log_success "Arquivo VERSION copiado para backend/"

# Limpar cache Docker
docker system prune -f
log_success "Cache Docker limpo"

# Rebuild containers
if [ -f "docker-compose.production.yml" ]; then
    docker-compose -f docker-compose.production.yml build --no-cache
    docker-compose -f docker-compose.production.yml up -d
else
    docker-compose build --no-cache
    docker-compose up -d
fi
log_success "Containers rebuildados"

# 6. Aguardar e verificar
log_info "⏳ Passo 6/6: Aguardando inicialização..."
sleep 20

# Verificar containers
log_info "🔍 Verificando containers..."
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

# Testar API
log_info "🔐 Testando API..."
API_RESPONSE=$(curl -s --connect-timeout 10 "http://localhost:3002/health")
if echo "$API_RESPONSE" | grep -q "healthy"; then
    log_success "✅ API está respondendo"
else
    log_warning "⚠️  API pode não estar respondendo ainda"
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
else
    log_warning "Script de verificação não encontrado"
fi

# Configurar serviço systemd
log_info "⚙️  Configurando serviço systemd..."
if [ -f "docker-compose.production.yml" ]; then
    cat > /etc/systemd/system/softwarehub.service << EOF
[Unit]
Description=Sistema de Gestão de Softwares
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
ExecReload=/usr/local/bin/docker-compose -f docker-compose.production.yml restart

[Install]
WantedBy=multi-user.target
EOF
else
    cat > /etc/systemd/system/softwarehub.service << EOF
[Unit]
Description=Sistema de Gestão de Softwares
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable softwarehub.service
log_success "✅ Serviço systemd configurado"

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   Servidor de Produção Corrigido              ${NC}"
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
echo -e "${BLUE}📋 Comandos úteis:${NC}"
echo -e "${YELLOW}   Ver status:${NC} systemctl status softwarehub"
echo -e "${YELLOW}   Parar:${NC} systemctl stop softwarehub"
echo -e "${YELLOW}   Iniciar:${NC} systemctl start softwarehub"
echo -e "${YELLOW}   Ver logs:${NC} docker-compose -f docker-compose.production.yml logs -f"
echo ""
echo -e "${BLUE}💡 Para forçar atualização no navegador:${NC}"
echo -e "${YELLOW}   1. Pressione Ctrl+F5${NC}"
echo -e "${YELLOW}   2. Ou abra em aba anônima${NC}"
echo -e "${YELLOW}   3. Ou limpe o cache do navegador${NC}"
echo ""
echo -e "${GREEN}✅ Servidor de produção corrigido com sucesso!${NC}" 