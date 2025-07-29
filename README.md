# SoftwareHub - Sistema de Gestão de Softwares

Sistema completo para gestão de softwares empresariais com funcionalidades de dashboard, CRUD de softwares, gestão de usuários, logs de auditoria e exportação de dados.

## 🚀 Tecnologias Utilizadas

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: Node.js, Express.js, TypeScript
- **Banco de Dados**: PostgreSQL 15+
- **ORM**: Prisma
- **Autenticação**: JWT + bcrypt
- **Containerização**: Docker + Docker Compose
- **Proxy Reverso**: Nginx

## 📋 Funcionalidades

- ✅ Dashboard com métricas e gráficos
- ✅ Gestão completa de softwares (CRUD)
- ✅ Sistema de usuários e permissões
- ✅ Logs de auditoria
- ✅ Filtros avançados e visão customizável
- ✅ Exportação de dados em CSV
- ✅ Autenticação JWT
- ✅ Interface responsiva

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
cd softwarehub

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

- **URL**: http://localhost:8087
- **API**: http://localhost:3001/api
- **Health Check**: http://localhost:3001/health

### 4. Credenciais Iniciais

- **Email**: admin@softwarehub.com
- **Senha**: admin123
- **Role**: Admin

⚠️ **IMPORTANTE**: Altere a senha do admin após o primeiro login!

## 🐳 Deploy em Produção

### 1. Configuração de Produção

```bash
# Configure variáveis de produção
export DB_PASSWORD="sua_senha_segura"
export JWT_SECRET="seu_jwt_secret_super_seguro"
export CORS_ORIGIN="http://softwarehub-xp.wake.tech:8087"
```

### 2. Build das Imagens

```bash
# Build do backend
cd backend
docker build -t softwarehub-backend:latest .

# Build do frontend (se necessário)
# O frontend atual é servido via Nginx
```

### 3. Deploy com Kubernetes

```bash
# Aplicar namespace
kubectl apply -f k8s/namespace.yaml

# Aplicar secrets
kubectl create secret generic softwarehub-secrets -n softwarehub \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=JWT_SECRET="$JWT_SECRET"

# Deploy PostgreSQL
kubectl apply -f k8s/postgres-deployment.yaml

# Deploy Backend
kubectl apply -f k8s/backend-deployment.yaml

# Deploy Frontend
kubectl apply -f k8s/frontend-deployment.yaml

# Deploy Nginx
kubectl apply -f k8s/nginx-deployment.yaml
```

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

- **Health Check**: `/health`
- **Logs**: Estruturados com Morgan
- **Métricas**: Endpoints de estatísticas
- **Auditoria**: Logs de todas as ações

## 🔄 Backup e Recovery

### Backup Automático PostgreSQL

```bash
#!/bin/bash
# backup.sh
DATE=$(date +%Y%m%d_%H%M%S)
docker exec softwarehub_db_1 pg_dump -U softwarehub_user softwarehub > backup_$DATE.sql
```

### Restore

```bash
docker exec -i softwarehub_db_1 psql -U softwarehub_user softwarehub < backup_YYYYMMDD_HHMMSS.sql
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