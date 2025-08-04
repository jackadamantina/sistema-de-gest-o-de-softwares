#!/bin/sh

# Script de inicialização do banco de dados
# Executado automaticamente no primeiro deploy

echo "🚀 Iniciando configuração do banco de dados..."

# Aguardar o banco estar pronto
echo "⏳ Aguardando banco de dados..."
until nc -z db 5432; do
  echo "Banco ainda não está pronto..."
  sleep 2
done

echo "✅ Banco de dados está pronto!"

# Aplicar migrações
echo "📦 Aplicando migrações do Prisma..."
npx prisma migrate deploy

# Verificar se já existem usuários
echo "🔍 Verificando usuários existentes..."
USER_COUNT=$(npx prisma db execute --stdin <<EOF | grep -c "admin@softwarehub.com" || echo "0"
SELECT email FROM users WHERE email = 'admin@softwarehub.com';
EOF
)

if [ "$USER_COUNT" = "0" ]; then
  echo "👤 Criando usuários padrão..."
  node scripts/seed-users.js
else
  echo "✅ Usuários já existem"
fi

echo "🎉 Configuração do banco concluída!"

# Iniciar o servidor
echo "🚀 Iniciando servidor..."
node dist/server.js