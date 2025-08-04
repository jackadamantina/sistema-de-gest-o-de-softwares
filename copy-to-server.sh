#!/bin/bash

# Script para copiar os arquivos do sistema para o servidor de produção

set -e

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Copiando arquivos para o servidor...${NC}"

# Verificar se o parâmetro foi fornecido
if [ $# -eq 0 ]; then
    echo -e "${RED}Uso: $0 usuario@servidor:/caminho/destino${NC}"
    echo "Exemplo: $0 root@192.168.1.100:/root/sistema-gestao"
    exit 1
fi

DESTINO=$1

# Verificar se os arquivos essenciais existem
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Erro: docker-compose.yml não encontrado!${NC}"
    echo "Execute este script no diretório raiz do projeto."
    exit 1
fi

# Criar arquivo tar.gz com todos os arquivos necessários
echo -e "${YELLOW}Criando arquivo compactado...${NC}"
tar -czf sistema-gestao.tar.gz \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='dist' \
    --exclude='build' \
    --exclude='.env' \
    --exclude='postgres_data' \
    --exclude='uploads' \
    .

echo -e "${GREEN}✓ Arquivo criado: sistema-gestao.tar.gz${NC}"

# Copiar para o servidor
echo -e "${YELLOW}Copiando para o servidor...${NC}"
scp sistema-gestao.tar.gz deploy-production.sh $DESTINO/

# Remover arquivo local
rm -f sistema-gestao.tar.gz

echo -e "${GREEN}✓ Arquivos copiados com sucesso!${NC}"
echo ""
echo -e "${YELLOW}Próximos passos no servidor:${NC}"
echo "1. Acesse o servidor e vá para o diretório: ${DESTINO#*:}"
echo "2. Descompacte os arquivos: tar -xzf sistema-gestao.tar.gz"
echo "3. Execute o script de deploy: ./deploy-production.sh"
echo ""