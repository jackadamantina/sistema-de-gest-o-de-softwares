#!/bin/bash

# Script para criar os tipos ENUM do Prisma no banco

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Criando Tipos ENUM do Prisma${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

cd /opt/sistema-gestao-softwares

# 1. Criar script SQL com os tipos
echo -e "${YELLOW}1. Criando script SQL com tipos ENUM...${NC}"

cat > create-enums.sql << 'EOF'
-- Criar tipos ENUM necessários para o Prisma

-- Role
CREATE TYPE "Role" AS ENUM ('Admin', 'Editor', 'Visualizador');

-- Status
CREATE TYPE "Status" AS ENUM ('Ativo', 'Inativo');

-- Hosting
CREATE TYPE "Hosting" AS ENUM ('On-premises', 'Cloud', 'Cloudstack', 'SaaS Público');

-- Acesso
CREATE TYPE "Acesso" AS ENUM ('Interno', 'Externo');

-- NamedUser
CREATE TYPE "NamedUser" AS ENUM ('Sim', 'Sem autenticação', 'Não');

-- IntegratedUser
CREATE TYPE "IntegratedUser" AS ENUM ('Sim', 'Não', 'Integrador', 'Ambos');

-- SSO
CREATE TYPE "SSO" AS ENUM ('Aplicável', 'Integrado', 'Possível (upgrade licença)', 'Sem possibilidade', 'Desenvolver');

-- Offboarding
CREATE TYPE "Offboarding" AS ENUM ('Remover manual', 'Remoção automática', 'N/A');

-- OffboardingType
CREATE TYPE "OffboardingType" AS ENUM ('Alta', 'Média', 'Baixa');

-- LogsInfo
CREATE TYPE "LogsInfo" AS ENUM ('Logs de acesso', 'Logs de sistema', 'Ambos', 'Nenhum log');

-- LogsRetention
CREATE TYPE "LogsRetention" AS ENUM ('Nenhum', 'Semanal', 'Mensal', 'Diário');

-- MFAPolicy
CREATE TYPE "MFAPolicy" AS ENUM ('Sim', 'Não', 'Não aplicável');

-- MFA
CREATE TYPE "MFA" AS ENUM ('Não tem possibilidade', 'Habilitado', 'Não aplicável');

-- MFASMS
CREATE TYPE "MFASMS" AS ENUM ('Não', 'Sim');

-- RegionBlock
CREATE TYPE "RegionBlock" AS ENUM ('Sim', 'Não', 'Não aplicável', 'Não possui funcionalidade');

-- PasswordPolicy
CREATE TYPE "PasswordPolicy" AS ENUM ('Sim', 'Não');

-- SensitiveData
CREATE TYPE "SensitiveData" AS ENUM ('Sim', 'Não');

-- Criticidade
CREATE TYPE "Criticidade" AS ENUM ('Alta', 'Média', 'Baixa');

-- LogType
CREATE TYPE "LogType" AS ENUM ('create', 'update', 'delete', 'login', 'export', 'filter');

-- Verificar se os tipos foram criados
SELECT typname FROM pg_type WHERE typtype = 'e' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
EOF

echo -e "${GREEN}✓ Script SQL criado${NC}"

# 2. Executar no banco
echo -e "${YELLOW}2. Aplicando tipos ENUM no banco de dados...${NC}"

# Verificar primeiro se os tipos já existem
echo "Verificando tipos existentes..."
docker exec sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub -c "SELECT typname FROM pg_type WHERE typtype = 'e' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');" || true

# Aplicar os tipos (ignorando erros se já existirem)
docker exec -i sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub < create-enums.sql 2>&1 | grep -v "already exists" || true

# 3. Alterar colunas das tabelas para usar os tipos
echo -e "${YELLOW}3. Alterando colunas para usar os tipos ENUM...${NC}"

cat > alter-columns.sql << 'EOF'
-- Alterar colunas para usar os tipos ENUM

-- Tabela users
ALTER TABLE users 
  ALTER COLUMN role TYPE "Role" USING role::"Role",
  ALTER COLUMN status TYPE "Status" USING status::"Status";

-- Tabela softwares
ALTER TABLE softwares 
  ALTER COLUMN hosting TYPE "Hosting" USING 
    CASE 
      WHEN hosting = 'OnPremises' THEN 'On-premises'
      ELSE hosting 
    END::"Hosting",
  ALTER COLUMN acesso TYPE "Acesso" USING acesso::"Acesso",
  ALTER COLUMN named_user TYPE "NamedUser" USING 
    CASE 
      WHEN named_user = 'Nao' THEN 'Não'
      ELSE named_user 
    END::"NamedUser",
  ALTER COLUMN integrated_user TYPE "IntegratedUser" USING 
    CASE 
      WHEN integrated_user = 'Nao' THEN 'Não'
      ELSE integrated_user 
    END::"IntegratedUser",
  ALTER COLUMN sso TYPE "SSO" USING 
    CASE 
      WHEN sso = 'Aplicavel' THEN 'Aplicável'
      WHEN sso = 'PossivelUpgradeLicenca' THEN 'Possível (upgrade licença)'
      WHEN sso = 'SemPossibilidade' THEN 'Sem possibilidade'
      ELSE sso 
    END::"SSO",
  ALTER COLUMN offboarding TYPE "Offboarding" USING 
    CASE 
      WHEN offboarding = 'RemoverManual' THEN 'Remover manual'
      WHEN offboarding = 'RemocaoAutomatica' THEN 'Remoção automática'
      WHEN offboarding = 'NA' THEN 'N/A'
      ELSE offboarding 
    END::"Offboarding",
  ALTER COLUMN offboarding_type TYPE "OffboardingType" USING 
    CASE 
      WHEN offboarding_type = 'Media' THEN 'Média'
      ELSE offboarding_type 
    END::"OffboardingType",
  ALTER COLUMN logs_info TYPE "LogsInfo" USING 
    CASE 
      WHEN logs_info = 'LogsAcesso' THEN 'Logs de acesso'
      WHEN logs_info = 'LogsSistema' THEN 'Logs de sistema'
      WHEN logs_info = 'NenhumLog' THEN 'Nenhum log'
      ELSE logs_info 
    END::"LogsInfo",
  ALTER COLUMN logs_retention TYPE "LogsRetention" USING 
    CASE 
      WHEN logs_retention = 'Diario' THEN 'Diário'
      ELSE logs_retention 
    END::"LogsRetention",
  ALTER COLUMN mfa_policy TYPE "MFAPolicy" USING 
    CASE 
      WHEN mfa_policy = 'Nao' THEN 'Não'
      WHEN mfa_policy = 'NaoAplicavel' THEN 'Não aplicável'
      ELSE mfa_policy 
    END::"MFAPolicy",
  ALTER COLUMN mfa TYPE "MFA" USING 
    CASE 
      WHEN mfa = 'NaoTemPossibilidade' THEN 'Não tem possibilidade'
      WHEN mfa = 'NaoAplicavel' THEN 'Não aplicável'
      ELSE mfa 
    END::"MFA",
  ALTER COLUMN mfa_sms TYPE "MFASMS" USING 
    CASE 
      WHEN mfa_sms = 'Nao' THEN 'Não'
      ELSE mfa_sms 
    END::"MFASMS",
  ALTER COLUMN region_block TYPE "RegionBlock" USING 
    CASE 
      WHEN region_block = 'Nao' THEN 'Não'
      WHEN region_block = 'NaoAplicavel' THEN 'Não aplicável'
      WHEN region_block = 'NaoPossuiFuncionalidade' THEN 'Não possui funcionalidade'
      ELSE region_block 
    END::"RegionBlock",
  ALTER COLUMN password_policy TYPE "PasswordPolicy" USING 
    CASE 
      WHEN password_policy = 'Nao' THEN 'Não'
      ELSE password_policy 
    END::"PasswordPolicy",
  ALTER COLUMN sensitive_data TYPE "SensitiveData" USING 
    CASE 
      WHEN sensitive_data = 'Nao' THEN 'Não'
      ELSE sensitive_data 
    END::"SensitiveData",
  ALTER COLUMN criticidade TYPE "Criticidade" USING 
    CASE 
      WHEN criticidade = 'Media' THEN 'Média'
      ELSE criticidade 
    END::"Criticidade";

-- Tabela audit_logs
ALTER TABLE audit_logs 
  ALTER COLUMN type TYPE "LogType" USING type::"LogType";
EOF

echo -e "${GREEN}✓ Script de alteração criado${NC}"

# Executar alterações
docker exec -i sistema-gestao-softwares-db-1 psql -U softwarehub_user -d softwarehub < alter-columns.sql 2>&1 | grep -v "will create implicit" || true

# 4. Reiniciar backend
echo -e "${YELLOW}4. Reiniciando backend...${NC}"
docker-compose -f docker-compose.production.yml restart backend

# 5. Aguardar
echo -e "${YELLOW}5. Aguardando backend inicializar...${NC}"
sleep 10

# 6. Verificar logs
echo -e "${YELLOW}6. Verificando logs do backend...${NC}"
docker-compose -f docker-compose.production.yml logs --tail=20 backend

# Limpar arquivos temporários
rm -f create-enums.sql alter-columns.sql

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ Tipos ENUM Criados!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Teste criar um software novamente!"