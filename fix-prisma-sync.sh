#!/bin/bash

# Script para sincronizar Prisma com banco existente

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Sincronizando Prisma com Banco${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

cd /opt/sistema-gestao-softwares

echo -e "${YELLOW}Este processo irá:${NC}"
echo "1. Fazer backup dos dados atuais"
echo "2. Resetar o schema do banco"
echo "3. Deixar o Prisma criar a estrutura correta"
echo "4. Restaurar os dados"
echo ""
read -p "Continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Operação cancelada"
    exit 1
fi

# 1. Fazer backup dos dados
echo -e "${YELLOW}1. Fazendo backup dos dados...${NC}"
docker exec sistema-gestao-softwares-db-1 pg_dump -U softwarehub_user -d softwarehub --data-only > backup_data.sql
echo -e "${GREEN}✓ Backup salvo em backup_data.sql${NC}"

# 2. Parar backend
echo -e "${YELLOW}2. Parando backend...${NC}"
docker-compose -f docker-compose.production.yml stop backend

# 3. Resetar banco mantendo apenas os dados dos usuários
echo -e "${YELLOW}3. Salvando usuários...${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub -c "
COPY (SELECT name, email, password_hash FROM users WHERE email IN ('admin@softwarehub.com', 'editor@softwarehub.com', 'viewer@softwarehub.com')) 
TO '/tmp/users_backup.csv' WITH CSV HEADER;
"

# 4. Resetar schema
echo -e "${YELLOW}4. Resetando schema do banco...${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub << 'EOF'
-- Remover todas as tabelas e tipos
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO softwarehub_user;
GRANT ALL ON SCHEMA public TO PUBLIC;
EOF

echo -e "${GREEN}✓ Schema resetado${NC}"

# 5. Aplicar migrações do Prisma
echo -e "${YELLOW}5. Aplicando estrutura do Prisma...${NC}"
docker-compose -f docker-compose.production.yml run --rm backend sh -c "
npx prisma migrate deploy
"

# 6. Restaurar usuários
echo -e "${YELLOW}6. Restaurando usuários...${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub << 'EOF'
-- Criar tabela temporária
CREATE TEMP TABLE users_temp (
    name VARCHAR(255),
    email VARCHAR(255),
    password_hash VARCHAR(255)
);

-- Importar dados
COPY users_temp FROM '/tmp/users_backup.csv' WITH CSV HEADER;

-- Inserir usuários com estrutura completa
INSERT INTO users (id, name, email, "passwordHash", role, status, avatar, "createdAt", "updatedAt")
SELECT 
    gen_random_uuid(),
    name,
    email,
    password_hash,
    CASE 
        WHEN email = 'admin@softwarehub.com' THEN 'Admin'::public."Role"
        WHEN email = 'editor@softwarehub.com' THEN 'Editor'::public."Role"
        ELSE 'Visualizador'::public."Role"
    END,
    'Ativo'::public."Status",
    UPPER(SUBSTRING(name FROM 1 FOR 2)),
    NOW(),
    NOW()
FROM users_temp
ON CONFLICT (email) DO NOTHING;

-- Limpar
DROP TABLE users_temp;
EOF

echo -e "${GREEN}✓ Usuários restaurados${NC}"

# 7. Adicionar alguns softwares de exemplo
echo -e "${YELLOW}7. Adicionando softwares de exemplo...${NC}"
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub << 'EOF'
-- Buscar ID do admin
DO $$
DECLARE
    admin_id UUID;
BEGIN
    SELECT id INTO admin_id FROM users WHERE email = 'admin@softwarehub.com' LIMIT 1;
    
    -- Inserir softwares de exemplo
    INSERT INTO softwares (id, servico, description, url, hosting, acesso, responsible, "namedUser", "integratedUser", sso, onboarding, offboarding, "offboardingType", "affectedTeams", "logsInfo", "logsRetention", "mfaPolicy", mfa, "mfaSMS", "regionBlock", "passwordPolicy", "sensitiveData", criticidade, "createdAt", "updatedAt", "createdBy", "updatedBy")
    VALUES 
    (
        gen_random_uuid(),
        'Microsoft Office 365',
        'Suite de produtividade Microsoft',
        'https://office.com',
        'Cloud'::public."Hosting",
        'Externo'::public."Acesso",
        'TI - Infraestrutura',
        'Sim'::public."NamedUser",
        'Sim'::public."IntegratedUser",
        'Integrado'::public."SSO",
        'Automático via AD',
        'Remoção automática'::public."Offboarding",
        'Alta'::public."OffboardingType",
        ARRAY['TI', 'RH', 'Financeiro'],
        'Ambos'::public."LogsInfo",
        'Mensal'::public."LogsRetention",
        'Sim'::public."MFAPolicy",
        'Habilitado'::public."MFA",
        'Sim'::public."MFASMS",
        'Sim'::public."RegionBlock",
        'Sim'::public."PasswordPolicy",
        'Sim'::public."SensitiveData",
        'Alta'::public."Criticidade",
        NOW(),
        NOW(),
        admin_id,
        admin_id
    );
END $$;
EOF

echo -e "${GREEN}✓ Dados de exemplo adicionados${NC}"

# 8. Reiniciar backend
echo -e "${YELLOW}8. Iniciando backend...${NC}"
docker-compose -f docker-compose.production.yml start backend

# 9. Aguardar
echo -e "${YELLOW}9. Aguardando inicialização...${NC}"
sleep 10

# 10. Verificar
echo -e "${YELLOW}10. Verificando status...${NC}"
docker-compose -f docker-compose.production.yml ps

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Sincronização Completa!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Informações:${NC}"
echo "- Estrutura do banco sincronizada com Prisma"
echo "- Usuários preservados"
echo "- Software de exemplo adicionado"
echo ""
echo -e "${YELLOW}Teste agora:${NC}"
echo "1. Faça login: admin@softwarehub.com / admin123"
echo "2. Tente criar um novo software"