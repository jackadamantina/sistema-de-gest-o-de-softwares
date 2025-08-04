#!/bin/bash

# Script para corrigir o Dockerfile do frontend no servidor

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Corrigindo Dockerfile do Frontend...${NC}"

# Determinar diretório
if [ -d "/opt/sistema-gestao-softwares" ]; then
    cd /opt/sistema-gestao-softwares
elif [ -d "/sistema-de-gest-o-de-softwares" ]; then
    cd /sistema-de-gest-o-de-softwares
else
    echo "Erro: Diretório do sistema não encontrado"
    exit 1
fi

# Criar novo Dockerfile para frontend
cat > frontend/Dockerfile << 'EOF'
FROM nginx:alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Note: index.html is mounted as volume in docker-compose

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

echo -e "${GREEN}✓ Dockerfile corrigido${NC}"

# Agora tentar build novamente
echo -e "${YELLOW}Tentando build novamente...${NC}"
docker-compose -f docker-compose.production.yml build frontend

echo -e "${GREEN}✓ Build concluído${NC}"