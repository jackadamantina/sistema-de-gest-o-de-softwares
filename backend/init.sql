-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Tabela de usuários
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('Admin', 'Editor', 'Visualizador')),
  status VARCHAR(20) NOT NULL DEFAULT 'Ativo' CHECK (status IN ('Ativo', 'Inativo')),
  avatar VARCHAR(10),
  last_access TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de softwares
CREATE TABLE softwares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  servico VARCHAR(255) NOT NULL,
  description TEXT,
  url VARCHAR(500),
  hosting VARCHAR(100) NOT NULL CHECK (hosting IN ('On-premises', 'Cloud', 'Cloudstack', 'SaaS Público')),
  
  -- Gestão de Acesso
  acesso VARCHAR(50) NOT NULL CHECK (acesso IN ('Interno', 'Externo')),
  responsible TEXT,
  named_user VARCHAR(50) CHECK (named_user IN ('Sim', 'Sem autenticação', 'Não')),
  integrated_user VARCHAR(50) CHECK (integrated_user IN ('Sim', 'Não', 'Integrador', 'Ambos')),
  sso VARCHAR(100) NOT NULL CHECK (sso IN ('Aplicável', 'Integrado', 'Possível (upgrade licença)', 'Sem possibilidade', 'Desenvolver')),
  
  -- Onboarding/Offboarding
  onboarding TEXT,
  offboarding VARCHAR(50) CHECK (offboarding IN ('Remover manual', 'Remoção automática', 'N/A')),
  offboarding_type VARCHAR(20) CHECK (offboarding_type IN ('Alta', 'Média', 'Baixa')),
  affected_teams TEXT[], -- Array de strings
  
  -- Segurança
  logs_info VARCHAR(50) CHECK (logs_info IN ('Logs de acesso', 'Logs de sistema', 'Ambos', 'Nenhum log')),
  logs_retention VARCHAR(20) CHECK (logs_retention IN ('Nenhum', 'Semanal', 'Mensal', 'Diário')),
  mfa_policy VARCHAR(20) CHECK (mfa_policy IN ('Sim', 'Não', 'Não aplicável')),
  mfa VARCHAR(50) NOT NULL CHECK (mfa IN ('Não tem possibilidade', 'Habilitado', 'Não aplicável')),
  mfa_sms VARCHAR(10) CHECK (mfa_sms IN ('Não', 'Sim')),
  region_block VARCHAR(50) CHECK (region_block IN ('Sim', 'Não', 'Não aplicável', 'Não possui funcionalidade')),
  password_policy VARCHAR(10) CHECK (password_policy IN ('Sim', 'Não')),
  
  -- LGPD
  sensitive_data VARCHAR(10) CHECK (sensitive_data IN ('Sim', 'Não')),
  
  -- Campos legados para compatibilidade
  criticidade VARCHAR(20) NOT NULL DEFAULT 'Média' CHECK (criticidade IN ('Alta', 'Média', 'Baixa')),
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id)
);

-- Tabela de logs de auditoria
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  user_name VARCHAR(255) NOT NULL,
  action VARCHAR(255) NOT NULL,
  details TEXT NOT NULL,
  type VARCHAR(50) NOT NULL CHECK (type IN ('create', 'update', 'delete', 'login', 'export', 'filter')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para performance
CREATE INDEX idx_softwares_hosting ON softwares(hosting);
CREATE INDEX idx_softwares_acesso ON softwares(acesso);
CREATE INDEX idx_softwares_sso ON softwares(sso);
CREATE INDEX idx_softwares_mfa ON softwares(mfa);
CREATE INDEX idx_softwares_criticidade ON softwares(criticidade);
CREATE INDEX idx_softwares_created_at ON softwares(created_at);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_type ON audit_logs(type);

-- Triggers para updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_softwares_updated_at BEFORE UPDATE ON softwares
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Dados iniciais
-- Usuário admin inicial (senha: admin123)
INSERT INTO users (name, email, password_hash, role, status, avatar) VALUES
('Rodrigo Oliveira', 'admin@softwarehub.com', '$2a$10$bU1HWkvmgsRLXl7xUMqNTu8BzwGpYCo64tLFKBAJ8gk/KCO3toMH2', 'Admin', 'Ativo', 'RO');

-- Usuário editor (senha: editor123)
INSERT INTO users (name, email, password_hash, role, status, avatar) VALUES
('Editor User', 'editor@softwarehub.com', '$2a$10$fQzJ7mXWzXtxQBT8Y1QLbOzXVLJeNwzXtxQBT8Y1QLbOzXVLJeNwzXtx', 'Editor', 'Ativo', 'EU');

-- Usuário visualizador (senha: viewer123)
INSERT INTO users (name, email, password_hash, role, status, avatar) VALUES
('Viewer User', 'viewer@softwarehub.com', '$2a$10$kLmN8pQrStUvWxYzAbCdEfkLmN8pQrStUvWxYzAbCdEfkLmN8pQrStUv', 'Visualizador', 'Ativo', 'VU');

-- Softwares de exemplo
INSERT INTO softwares (servico, url, hosting, acesso, sso, mfa, criticidade, region_block, logs_info, created_by) 
SELECT 
  'AWS Console', 'https://aws.amazon.com', 'Cloud', 'Interno', 'Integrado', 'Habilitado', 'Alta', 'Sim', 'Logs de sistema', u.id
FROM users u WHERE u.email = 'admin@softwarehub.com';

INSERT INTO softwares (servico, url, hosting, acesso, sso, mfa, criticidade, region_block, logs_info, created_by) 
SELECT 
  'Jira Software', 'https://empresa.atlassian.net', 'SaaS Público', 'Interno', 'Aplicável', 'Habilitado', 'Média', 'Sim', 'Logs de acesso', u.id
FROM users u WHERE u.email = 'admin@softwarehub.com';

INSERT INTO softwares (servico, url, hosting, acesso, sso, mfa, criticidade, region_block, logs_info, created_by) 
SELECT 
  'Sistema ERP', 'http://erp.empresa.local', 'On-premises', 'Interno', 'Desenvolver', 'Não tem possibilidade', 'Alta', 'Não aplicável', 'Logs de sistema', u.id
FROM users u WHERE u.email = 'admin@softwarehub.com';

INSERT INTO softwares (servico, url, hosting, acesso, sso, mfa, criticidade, region_block, logs_info, created_by) 
SELECT 
  'Slack', 'https://empresa.slack.com', 'SaaS Público', 'Interno', 'Integrado', 'Habilitado', 'Baixa', 'Sim', 'Logs de acesso', u.id
FROM users u WHERE u.email = 'admin@softwarehub.com'; 