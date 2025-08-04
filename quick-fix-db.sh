#!/bin/bash

# Script rápido para corrigir autenticação do banco

echo "🔧 Correção Rápida - Autenticação do Banco de Dados"
echo "=================================================="
echo ""

# Solicitar informações
read -p "Digite o diretório de instalação (padrão: /opt/sistema-gestao-softwares): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-"/opt/sistema-gestao-softwares"}

read -sp "Digite a senha do banco de dados que você definiu durante o deploy: " DB_PASSWORD
echo ""

# Ir para o diretório
cd "$INSTALL_DIR" || exit 1

# Determinar qual arquivo docker-compose usar
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
else
    COMPOSE_FILE="docker-compose.yml"
fi

echo ""
echo "📝 Criando arquivo .env com as credenciais corretas..."

# Criar arquivo .env
cat > .env << EOF
# Database
DATABASE_URL=postgresql://softwarehub_user:${DB_PASSWORD}@db:5432/softwarehub
POSTGRES_PASSWORD=${DB_PASSWORD}
DB_PASSWORD=${DB_PASSWORD}

# JWT
JWT_SECRET=$(openssl rand -base64 32)

# Environment
NODE_ENV=production
EOF

chmod 600 .env

echo "✅ Arquivo .env criado"
echo ""
echo "🔄 Reiniciando containers..."

# Parar e remover containers
docker-compose -f $COMPOSE_FILE down

# Remover volumes antigos (opcional - descomente se quiser resetar o banco)
# docker volume rm $(docker volume ls -q | grep postgres_data) 2>/dev/null || true

# Iniciar com as novas variáveis
docker-compose -f $COMPOSE_FILE up -d

echo ""
echo "⏳ Aguardando serviços iniciarem..."
sleep 15

# Verificar status
echo ""
echo "📊 Status dos serviços:"
docker-compose -f $COMPOSE_FILE ps

echo ""
echo "✅ Correção aplicada!"
echo ""
echo "🔑 Credenciais de acesso:"
echo "URL: http://seu-dominio:porta"
echo "Email: admin@softwarehub.com"
echo "Senha: admin123"
echo ""
echo "📋 Comandos úteis:"
echo "Ver logs: docker-compose -f $COMPOSE_FILE logs -f"
echo "Status: docker-compose -f $COMPOSE_FILE ps"