-- CreateEnum
CREATE TYPE "Role" AS ENUM ('Admin', 'Editor', 'Visualizador');

-- CreateEnum
CREATE TYPE "Status" AS ENUM ('Ativo', 'Inativo');

-- CreateEnum
CREATE TYPE "Hosting" AS ENUM ('On-premises', 'Cloud', 'Cloudstack', 'SaaS Público');

-- CreateEnum
CREATE TYPE "Acesso" AS ENUM ('Interno', 'Externo');

-- CreateEnum
CREATE TYPE "NamedUser" AS ENUM ('Sim', 'Sem autenticação', 'Não');

-- CreateEnum
CREATE TYPE "IntegratedUser" AS ENUM ('Sim', 'Não', 'Integrador', 'Ambos');

-- CreateEnum
CREATE TYPE "SSO" AS ENUM ('Aplicável', 'Integrado', 'Possível (upgrade licença)', 'Sem possibilidade', 'Desenvolver');

-- CreateEnum
CREATE TYPE "Offboarding" AS ENUM ('Remover manual', 'Remoção automática', 'N/A');

-- CreateEnum
CREATE TYPE "OffboardingType" AS ENUM ('Alta', 'Média', 'Baixa');

-- CreateEnum
CREATE TYPE "LogsInfo" AS ENUM ('Logs de acesso', 'Logs de sistema', 'Ambos', 'Nenhum log');

-- CreateEnum
CREATE TYPE "LogsRetention" AS ENUM ('Nenhum', 'Semanal', 'Mensal', 'Diário');

-- CreateEnum
CREATE TYPE "MFAPolicy" AS ENUM ('Sim', 'Não', 'Não aplicável');

-- CreateEnum
CREATE TYPE "MFA" AS ENUM ('Não tem possibilidade', 'Habilitado', 'Não aplicável');

-- CreateEnum
CREATE TYPE "MFASMS" AS ENUM ('Não', 'Sim');

-- CreateEnum
CREATE TYPE "RegionBlock" AS ENUM ('Sim', 'Não', 'Não aplicável', 'Não possui funcionalidade');

-- CreateEnum
CREATE TYPE "PasswordPolicy" AS ENUM ('Sim', 'Não');

-- CreateEnum
CREATE TYPE "SensitiveData" AS ENUM ('Sim', 'Não');

-- CreateEnum
CREATE TYPE "Criticidade" AS ENUM ('Alta', 'Média', 'Baixa');

-- CreateEnum
CREATE TYPE "LogType" AS ENUM ('create', 'update', 'delete', 'login', 'export', 'filter');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "status" "Status" NOT NULL DEFAULT 'Ativo',
    "avatar" TEXT,
    "last_access" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "softwares" (
    "id" TEXT NOT NULL,
    "servico" TEXT NOT NULL,
    "description" TEXT,
    "url" TEXT,
    "hosting" "Hosting" NOT NULL,
    "acesso" "Acesso" NOT NULL,
    "responsible" TEXT,
    "named_user" "NamedUser",
    "integrated_user" "IntegratedUser",
    "sso" "SSO" NOT NULL,
    "onboarding" TEXT,
    "offboarding" "Offboarding",
    "offboarding_type" "OffboardingType",
    "affected_teams" TEXT[],
    "logs_info" "LogsInfo",
    "logs_retention" "LogsRetention",
    "mfa_policy" "MFAPolicy",
    "mfa" "MFA" NOT NULL,
    "mfa_sms" "MFASMS",
    "region_block" "RegionBlock",
    "password_policy" "PasswordPolicy",
    "sensitive_data" "SensitiveData",
    "criticidade" "Criticidade" NOT NULL DEFAULT 'Média',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "softwares_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" TEXT NOT NULL,
    "user_id" TEXT,
    "user_name" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "details" TEXT NOT NULL,
    "type" "LogType" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- AddForeignKey
ALTER TABLE "softwares" ADD CONSTRAINT "softwares_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "softwares" ADD CONSTRAINT "softwares_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
