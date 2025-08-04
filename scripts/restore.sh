#!/bin/bash

# Script de restore para o Sistema de Gestão de Softwares
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

echo -e "${BLUE}=== Sistema de Gestão de Softwares - Restore ===${NC}"

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

# Verificar se foi fornecido um arquivo de backup
if [ -z "$1" ]; then
    echo -e "${YELLOW}Uso: $0 <arquivo-backup.tar.gz> ou <timestamp>${NC}"
    echo -e "\n${BLUE}Backups disponíveis:${NC}"
    ls -lh "${BACKUP_DIR}"/sistema-gestao-backup-*.tar.gz 2>/dev/null | tail -10 || echo "Nenhum backup encontrado"
    exit 1
fi

# Determinar o arquivo de backup
BACKUP_FILE="$1"
if [[ ! "$BACKUP_FILE" =~ \.tar\.gz$ ]]; then
    # Se foi passado apenas o timestamp, construir o nome completo
    BACKUP_FILE="${BACKUP_DIR}/sistema-gestao-backup-${BACKUP_FILE}.tar.gz"
fi

# Verificar se o arquivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    show_error "Arquivo de backup não encontrado: $BACKUP_FILE"
    exit 1
fi

echo -e "${BLUE}Restaurando do backup: $BACKUP_FILE${NC}\n"

# Confirmar restore
echo -e "${YELLOW}⚠️  ATENÇÃO: Este processo irá sobrescrever todos os dados atuais!${NC}"
read -p "Deseja continuar? (sim/não): " -r
if [[ ! $REPLY =~ ^[Ss][Ii][Mm]$ ]]; then
    echo "Restore cancelado."
    exit 0
fi

# Criar diretório temporário
TEMP_DIR="/tmp/sistema-gestao-restore-$$"
mkdir -p "$TEMP_DIR"

# Extrair backup
show_progress "Extraindo backup..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
show_success "Backup extraído"

# Parar containers
show_progress "Parando serviços..."
cd /opt/sistema-gestao-softwares
docker-compose -f docker-compose.production.yml down
show_success "Serviços parados"

# Restaurar banco de dados
show_progress "Iniciando container do banco de dados..."
docker-compose -f docker-compose.production.yml up -d db
sleep 10  # Aguardar o banco iniciar

show_progress "Restaurando banco de dados..."
DB_FILE=$(find "$TEMP_DIR" -name "*-database.sql" -type f | head -1)
if [ -f "$DB_FILE" ]; then
    # Dropar banco existente e recriar
    docker exec sistema-gestao-softwares-db-1 psql -U softwarehub -c "DROP DATABASE IF EXISTS softwarehub;"
    docker exec sistema-gestao-softwares-db-1 psql -U softwarehub -c "CREATE DATABASE softwarehub;"
    
    # Restaurar dados
    docker exec -i sistema-gestao-softwares-db-1 psql -U softwarehub softwarehub < "$DB_FILE"
    show_success "Banco de dados restaurado"
else
    show_error "Arquivo de banco de dados não encontrado no backup"
fi

# Restaurar uploads
show_progress "Restaurando arquivos de upload..."
UPLOADS_FILE=$(find "$TEMP_DIR" -name "*-uploads.tar.gz" -type f | head -1)
if [ -f "$UPLOADS_FILE" ]; then
    rm -rf /opt/sistema-gestao-softwares/uploads
    tar -xzf "$UPLOADS_FILE" -C /opt/sistema-gestao-softwares/
    show_success "Uploads restaurados"
else
    show_progress "Arquivo de uploads não encontrado no backup"
fi

# Restaurar configurações
show_progress "Restaurando configurações..."
ENV_FILE=$(find "$TEMP_DIR" -name "*-env.backup" -type f | head -1)
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" /opt/sistema-gestao-softwares/.env.restored
    echo -e "${YELLOW}Arquivo .env restaurado como .env.restored${NC}"
    echo -e "${YELLOW}Verifique as configurações antes de substituir o .env atual${NC}"
else
    show_progress "Arquivo de configuração não encontrado no backup"
fi

# Limpar arquivos temporários
rm -rf "$TEMP_DIR"

# Reiniciar todos os serviços
show_progress "Reiniciando serviços..."
docker-compose -f docker-compose.production.yml up -d
show_success "Serviços reiniciados"

echo -e "\n${GREEN}✓ Restore concluído com sucesso!${NC}"
echo -e "${YELLOW}Nota: Verifique os logs dos serviços para garantir que tudo está funcionando:${NC}"
echo -e "${BLUE}docker-compose -f docker-compose.production.yml logs -f${NC}"