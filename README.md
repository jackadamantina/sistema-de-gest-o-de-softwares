# SoftwareHub - Sistema de Gestão de Softwares

Sistema completo para gestão de softwares empresariais com funcionalidades de dashboard, CRUD de softwares, gestão de usuários, logs de auditoria, filtros avançados e exportação de dados.

## ⚡ Quick Start

### 🚀 Deploy Rápido em Produção

```bash
# 1. Clone o projeto
git clone <repository-url>
cd sistema-de-gestão-de-softwares

# 2. Execute o deploy consolidado (ROOT necessário)
sudo ./scripts/deploy-consolidated.sh

# 3. Acesse o sistema
# URL: http://seu-servidor:8089
# Login: admin@softwarehub.com / admin123
```

### 🐳 Deploy Local

```bash
# 1. Clone e configure
git clone <repository-url>
cd sistema-de-gestão-de-softwares

# 2. Inicie com Docker
docker-compose up -d

# 3. Acesse o sistema
# URL: http://localhost:8089
# Login: admin@softwarehub.com / admin123
```

## 🚀 Tecnologias Utilizadas

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: Node.js, Express.js, TypeScript
- **Banco de Dados**: PostgreSQL 15+
- **ORM**: Prisma
- **Autenticação**: JWT + bcrypt
- **Containerização**: Docker + Docker Compose
- **Proxy Reverso**: Nginx

## 📋 Funcionalidades

### 🎯 Funcionalidades Principais
- ✅ Dashboard com métricas e gráficos
- ✅ Gestão completa de softwares (CRUD)
- ✅ Sistema de usuários e permissões
- ✅ Logs de auditoria
- ✅ Autenticação JWT
- ✅ Interface responsiva

### 🔍 Sistema de Filtros Avançados
- ✅ **Filtros com operadores lógicos** (AND/OR)
- ✅ **Todos os campos disponíveis** para filtro
- ✅ **Múltiplos operadores**: Contém, É igual, Começa com, etc.
- ✅ **Seleção múltipla** de itens
- ✅ **Exportação seletiva** em CSV
- ✅ **Ações em lote** (exclusão múltipla)
- ✅ **Interface intuitiva** para criar regras

### 📊 Visão Customizável
- ✅ **Gerenciamento de colunas** visíveis
- ✅ **Visão essencial** e **visão completa**
- ✅ **Filtros em tempo real**
- ✅ **Estatísticas** de filtros aplicados

### 📤 Exportação e Relatórios
- ✅ **Exportação completa** em CSV
- ✅ **Exportação seletiva** de itens filtrados
- ✅ **Relatórios customizados**
- ✅ **Backup automático** configurado

## 🏗️ Arquitetura

```
SoftwareHub/
├── backend/                 # API Backend (Node.js + TypeScript)
│   ├── src/
│   │   ├── controllers/    # Controllers da aplicação
│   │   ├── middleware/     # Middlewares (auth, validation)
│   │   ├── routes/         # Rotas da API
│   │   ├── services/       # Serviços de negócio
│   │   ├── types/          # Tipos TypeScript
│   │   └── server.ts       # Servidor principal
│   ├── prisma/             # Schema e migrations
│   └── Dockerfile          # Container do backend
├── index.html              # Frontend (HTML + JavaScript)
├── nginx.conf              # Configuração do Nginx
├── docker-compose.yml      # Orquestração Docker
└── README.md               # Documentação
```

## 🚀 Deploy Local

### Pré-requisitos

- Docker e Docker Compose instalados
- Node.js 18+ (para desenvolvimento local)

### 1. Clone e Configure

```bash
# Clone o repositório
git clone <repository-url>
cd sistema-de-gestão-de-softwares

# Configure as variáveis de ambiente
cp backend/env.example backend/.env
# Edite backend/.env com suas configurações
```

### 2. Deploy com Docker Compose

```bash
# Iniciar todos os serviços
docker-compose up -d

# Verificar logs
docker-compose logs -f

# Parar serviços
docker-compose down
```

### 3. Acesse a Aplicação

- **URL**: http://localhost:8089
- **API**: http://localhost:3002/api
- **Health Check**: http://localhost:3002/health

### 4. Credenciais Iniciais

- **Email**: admin@softwarehub.com
- **Senha**: admin123
- **Role**: Admin

⚠️ **IMPORTANTE**: Altere a senha do admin após o primeiro login!

## 🐳 Deploy em Produção

### 🚀 Deploy Consolidado (Recomendado)

O sistema agora possui um **deploy totalmente automatizado** que inclui todas as correções necessárias:

```bash
# 1. Acesse o servidor
ssh seu-servidor

# 2. Navegue para o projeto
cd /caminho/para/sistema-de-gestão-de-softwares

# 3. Execute o deploy consolidado (ROOT necessário)
sudo ./scripts/deploy-consolidated.sh
```

### 📋 O que o Deploy Consolidado Faz:

1. **🛑 Para sistema existente** (se houver)
2. **📁 Copia arquivos** com feedback detalhado
3. **🔧 Aplica correções** automáticas:
   - Verifica/cria arquivo VERSION
   - Copia VERSION para backend
   - Gera package-lock.json se necessário
   - Configura nginx.conf se necessário
   - Define permissões dos scripts
4. **🐳 Constrói containers** com verificações
5. **🚀 Inicia serviços** com aguardar inicialização
6. **🔍 Verifica saúde** de todos os componentes
7. **⚙️ Configura systemd** para auto-start
8. **💾 Configura backup** automático
9. **📋 Fornece resumo** completo

### 🔧 Deploy Manual (Alternativo)

Se preferir controle manual:

```bash
# Execute o deploy principal
sudo ./deploy-production.sh
```

### 📊 URLs de Produção

- **Sistema Web**: http://seu-dominio:8089
- **API Backend**: http://seu-dominio:3002
- **PostgreSQL**: localhost:5435

### 🔐 Credenciais de Produção

- **Email**: admin@softwarehub.com
- **Senha**: admin123

⚠️ **IMPORTANTE**: Altere a senha do admin após o primeiro login!

### 🛠️ Comandos de Gerenciamento

```bash
# Ver status dos containers
docker-compose -f docker-compose.production.yml ps

# Ver logs
docker-compose -f docker-compose.production.yml logs -f

# Parar sistema
systemctl stop softwarehub

# Iniciar sistema
systemctl start softwarehub

# Reiniciar sistema
systemctl restart softwarehub

# Backup manual
/usr/local/bin/softwarehub-backup.sh
```

### 🔍 Verificações de Saúde

O deploy inclui verificações automáticas:
- ✅ Containers rodando
- ✅ API respondendo
- ✅ Frontend acessível
- ✅ Banco de dados conectado

## 🔧 Desenvolvimento Local

### 1. Setup do Backend

```bash
cd backend

# Instalar dependências
npm install

# Configurar banco de dados
npx prisma generate
npx prisma migrate dev

# Executar em modo desenvolvimento
npm run dev
```

### 2. Setup do Frontend

O frontend é um arquivo HTML estático que pode ser servido por qualquer servidor web.

```bash
# Usando Python
python -m http.server 8087

# Usando Node.js
npx serve -s . -l 8087
```

## 📊 API Endpoints

### Autenticação
- `POST /api/auth/login` - Login de usuário
- `POST /api/auth/logout` - Logout
- `GET /api/auth/me` - Perfil do usuário
- `PUT /api/auth/profile` - Atualizar perfil
- `PUT /api/auth/password` - Alterar senha

### Softwares
- `GET /api/softwares` - Listar softwares
- `GET /api/softwares/:id` - Obter software específico
- `POST /api/softwares` - Criar software
- `PUT /api/softwares/:id` - Atualizar software
- `DELETE /api/softwares/:id` - Deletar software
- `GET /api/softwares/stats` - Estatísticas
- `POST /api/softwares/export` - Exportar CSV

### Auditoria
- `GET /api/audit` - Logs de auditoria
- `GET /api/audit/stats` - Estatísticas de auditoria

## 🛡️ Segurança

- ✅ Autenticação JWT
- ✅ Rate limiting
- ✅ CORS configurado
- ✅ Helmet.js para headers de segurança
- ✅ Validação de entrada
- ✅ Logs de auditoria
- ✅ Senhas hasheadas com bcrypt

## 📈 Monitoramento

### Health Checks
- **API Health**: `GET /health`
- **Version Info**: `GET /version`
- **Database Status**: Incluído no health check

### Logs e Métricas
- **Logs Estruturados**: Morgan + Winston
- **Métricas em Tempo Real**: Dashboard integrado
- **Auditoria Completa**: Logs de todas as ações
- **Backup Logs**: `/var/log/softwarehub-backup.log`

### Verificações Automáticas
O deploy inclui verificações automáticas de:
- ✅ Status dos containers
- ✅ Resposta da API
- ✅ Acessibilidade do frontend
- ✅ Conexão com banco de dados
- ✅ Versão do sistema

## 🔄 Backup e Recovery

### Backup Automático PostgreSQL

O sistema configura automaticamente backup diário às 2h da manhã:

```bash
# Backup manual
/usr/local/bin/softwarehub-backup.sh

# Ver logs de backup
tail -f /var/log/softwarehub-backup.log
```

### Restore

```bash
# Restaurar backup
docker exec -i sistema-de-gesto-de-softwares-db-1 psql -U softwarehub_user softwarehub < backup_YYYYMMDD_HHMMSS.sql
```

## 📋 Controle de Versão

### Sistema de Versionamento

O sistema possui controle de versão integrado:

```bash
# Ver versão atual
cat VERSION

# Incrementar versão (patch)
./scripts/bump-version.sh patch

# Incrementar versão (minor)
./scripts/bump-version.sh minor

# Incrementar versão (major)
./scripts/bump-version.sh major
```

### Verificação de Versão

```bash
# Verificar versão em execução
./scripts/check-version.sh

# Diagnóstico de problemas de versão
./scripts/diagnose-version.sh

# Corrigir problemas de versão
./scripts/fix-version.sh
```

## 🐛 Troubleshooting

### Problemas Comuns

1. **Banco não conecta**
   ```bash
   docker-compose logs db
   docker-compose restart db
   ```

2. **Backend não inicia**
   ```bash
   docker-compose logs backend
   docker-compose exec backend npx prisma migrate deploy
   ```

3. **Frontend não carrega**
   ```bash
   docker-compose logs frontend
   docker-compose restart frontend
   ```

4. **Login não funciona (usuário admin não existe)**
   ```bash
   # Criar usuário admin
   docker exec sistema-de-gesto-de-softwares-backend-1 npm run seed
   
   # Ou acessar o container e executar
   docker exec -it sistema-de-gesto-de-softwares-backend-1 sh
   npx prisma db seed
   ```

5. **Versão não aparece corretamente**
   ```bash
   # Verificar arquivo VERSION
   cat VERSION
   
   # Copiar para backend
   cp VERSION backend/VERSION
   
   # Rebuild do backend
   docker-compose -f docker-compose.production.yml build backend
   docker-compose -f docker-compose.production.yml up -d
   ```

6. **Deploy falha**
   ```bash
   # Usar script consolidado
   sudo ./scripts/deploy-consolidated.sh
   
   # Ou aplicar correções manualmente
   sudo ./scripts/fix-deploy.sh
   ```

### 🔧 Scripts de Correção

O sistema inclui scripts automáticos para correção de problemas:

- **`scripts/deploy-consolidated.sh`**: Deploy completo com todas as correções
- **`scripts/fix-deploy.sh`**: Corrige problemas de deploy
- **`scripts/check-version.sh`**: Verifica versão do sistema
- **`scripts/rebuild-with-version.sh`**: Rebuild com versão correta

## 📝 Licença

Este projeto está sob a licença MIT.

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📞 Suporte

Para suporte, entre em contato através de:
- Email: suporte@softwarehub.com
- Issues: GitHub Issues

---

**SoftwareHub** - Sistema de Gestão de Softwares Empresariais 