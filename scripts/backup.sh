#!/bin/bash

# Script de backup para o Sistema de Gestão de Softwares
# Autor: Sistema de Gestão
# Data: $(date +%Y-%m-%d)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
BACKUP_DIR="/opt/backups/sistema-gestao"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="sistema-gestao-backup-${TIMESTAMP}"
DAYS_TO_KEEP=7

echo -e "${BLUE}=== Sistema de Gestão de Softwares - Backup ===${NC}"
echo -e "${BLUE}Iniciando backup em $(date)${NC}\n"

# Criar diretório de backup se não existir
mkdir -p "${BACKUP_DIR}"

# Verificar se temos permissão de escrita
if [ ! -w "${BACKUP_DIR}" ]; then
    show_error "Sem permissão de escrita no diretório ${BACKUP_DIR}"
    exit 1
fi

# Função para mostrar progresso
show_progress() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Função para mostrar sucesso
show_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Função para mostrar erro
show_error() {
    echo -e "${RED}✗ $1${NC}"
}

# 1. Backup do banco de dados
show_progress "Fazendo backup do banco de dados..."

# Verificar se o container está rodando
# Em produção, o container pode ter um nome diferente
DB_CONTAINER=""
for name in "sistema-gestao-softwares-db-1" "sistema-gestao-db-1" "sistema-gestao-softwares_db_1" "db"; do
    if docker ps --format "{{.Names}}" | grep -q "^${name}$"; then
        DB_CONTAINER="$name"
        show_progress "Container do banco encontrado: $DB_CONTAINER"
        break
    fi
done

if [ -z "$DB_CONTAINER" ]; then
    show_error "Container do banco de dados não encontrado"
    echo "Containers em execução:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 1
fi

# Fazer o backup
if docker exec $DB_CONTAINER pg_dump -U softwarehub softwarehub > "${BACKUP_DIR}/${BACKUP_NAME}-database.sql" 2>&1; then
    DB_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}-database.sql" | cut -f1)
    show_success "Backup do banco de dados concluído (${DB_SIZE})"
else
    show_error "Erro ao fazer backup do banco de dados"
    # Mostrar o erro real
    docker exec $DB_CONTAINER pg_dump -U softwarehub softwarehub
    exit 1
fi

# 2. Backup dos uploads
show_progress "Fazendo backup dos arquivos de upload..."
if [ -d "/opt/sistema-gestao-softwares/uploads" ]; then
    tar -czf "${BACKUP_DIR}/${BACKUP_NAME}-uploads.tar.gz" -C /opt/sistema-gestao-softwares uploads 2>/dev/null
    show_success "Backup dos uploads concluído"
else
    show_progress "Diretório de uploads não encontrado, pulando..."
fi

# 3. Backup das variáveis de ambiente
show_progress "Fazendo backup das configurações..."
if [ -f "/opt/sistema-gestao-softwares/.env" ]; then
    cp /opt/sistema-gestao-softwares/.env "${BACKUP_DIR}/${BACKUP_NAME}-env.backup"
    show_success "Backup das configurações concluído"
fi

# 4. Criar arquivo compactado único
show_progress "Compactando backup..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" \
    "${BACKUP_NAME}-database.sql" \
    $([ -f "${BACKUP_NAME}-uploads.tar.gz" ] && echo "${BACKUP_NAME}-uploads.tar.gz") \
    $([ -f "${BACKUP_NAME}-env.backup" ] && echo "${BACKUP_NAME}-env.backup") 2>/dev/null

# Remover arquivos temporários
rm -f "${BACKUP_NAME}-database.sql" "${BACKUP_NAME}-uploads.tar.gz" "${BACKUP_NAME}-env.backup"

# Calcular tamanho do backup
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
show_success "Backup criado: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"

# 5. Limpeza de backups antigos
show_progress "Removendo backups antigos (mais de ${DAYS_TO_KEEP} dias)..."
find "${BACKUP_DIR}" -name "sistema-gestao-backup-*.tar.gz" -mtime +${DAYS_TO_KEEP} -delete
show_success "Limpeza concluída"

# 6. Listar backups disponíveis
echo -e "\n${BLUE}Backups disponíveis:${NC}"
ls -lh "${BACKUP_DIR}"/sistema-gestao-backup-*.tar.gz 2>/dev/null | tail -5 || echo "Nenhum backup encontrado"

echo -e "\n${GREEN}✓ Backup concluído com sucesso!${NC}"
echo -e "${BLUE}Local: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"

# Opcional: Enviar para storage remoto
# Descomente e configure conforme necessário:
# aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" s3://seu-bucket/backups/
# rsync -avz "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" usuario@servidor-remoto:/path/to/backups/