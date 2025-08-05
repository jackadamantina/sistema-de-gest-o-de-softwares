#!/bin/bash

# Script para atualizar a versão no frontend automaticamente
# Atualiza todas as referências de versão nos arquivos HTML

set -e

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Atualizando versão no frontend...${NC}"

# Ler versão atual
if [ ! -f "VERSION" ]; then
    echo -e "${YELLOW}⚠️  Arquivo VERSION não encontrado${NC}"
    exit 1
fi

CURRENT_VERSION=$(cat VERSION)
echo -e "${BLUE}📄 Versão atual: v${CURRENT_VERSION}${NC}"

# Lista de arquivos HTML para atualizar
HTML_FILES=(
    "index.html"
    "frontend/test-*.html"
    "test-*.html"
)

# Função para atualizar versão em um arquivo
update_version_in_file() {
    local file="$1"
    local version="$2"
    
    if [ -f "$file" ]; then
        echo -e "${BLUE}📝 Atualizando $file...${NC}"
        
        # Atualizar título da página
        sed -i "s|<title>.*v[0-9]\+\.[0-9]\+\.[0-9]\+|<title>SoftwareHub - Sistema de Gestão de Softwares v${version}|g" "$file"
        
        # Atualizar referências de versão no conteúdo
        sed -i "s|v[0-9]\+\.[0-9]\+\.[0-9]\+|v${version}|g" "$file"
        
        # Atualizar data de última atualização
        CURRENT_DATE=$(date +"%d/%m/%Y")
        sed -i "s|Última atualização: [0-9]\+\/[0-9]\+\/[0-9]\+|Última atualização: ${CURRENT_DATE}|g" "$file"
        
        echo -e "${GREEN}✅ $file atualizado${NC}"
    fi
}

# Atualizar cada arquivo
for pattern in "${HTML_FILES[@]}"; do
    for file in $pattern; do
        if [ -f "$file" ]; then
            update_version_in_file "$file" "$CURRENT_VERSION"
        fi
    done
done

echo ""
echo -e "${GREEN}✅ Versão atualizada em todos os arquivos HTML${NC}"
echo -e "${BLUE}📅 Data de atualização: $(date)${NC}"
echo ""
echo -e "${YELLOW}💡 Para aplicar as mudanças:${NC}"
echo -e "${YELLOW}   1. Reinicie os containers: docker-compose restart${NC}"
echo -e "${YELLOW}   2. Ou faça um novo deploy: ./deploy-production.sh${NC}" 