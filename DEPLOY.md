# 🚀 SoftwareHub - Guia de Deploy

Este guia fornece instruções completas para fazer deploy do SoftwareHub em diferentes ambientes.

## 📋 Pré-requisitos

### Para Todos os Ambientes
- Docker e Docker Compose instalados
- Porta 8087 disponível
- Porta 3001 disponível (para API)

### Para Produção (Debian 12)
- Acesso root
- Sistema Debian 12
- Firewall configurável

## 🎯 Opções de Deploy

### 1. 🚀 Quick Start (Preview Rápido)

Para fazer um preview rápido do sistema:

```bash
# Tornar scripts executáveis
chmod +x scripts/*.sh

# Executar quick start
./scripts/quick-start.sh
```

**Resultado:**
- Frontend: http://localhost:8087
- API: http://localhost:3001/api
- Credenciais: admin@softwarehub.com / admin123

### 2. 🏠 Deploy Local (Ubuntu 24)

Para deploy local em Ubuntu 24:

```bash
# Executar script de deploy local
./scripts/deploy-local.sh
```

**Características:**
- Instala Docker automaticamente
- Configura ambiente de desenvolvimento
- Hot reload para desenvolvimento

### 3. 🌐 Deploy Produção (Debian 12)

Para deploy em produção:

```bash
# Executar como root
sudo ./scripts/deploy-prod.sh
```

**Características:**
- Instala Docker automaticamente
- Configura firewall
- Cria serviço systemd
- Backup automático
- Senhas seguras geradas automaticamente

## 🐳 Estrutura Docker

### Containers Criados

```
softwarehub/
├── db/          # PostgreSQL 15
├── backend/     # Node.js API
└── frontend/    # Nginx + HTML
```

### Portas Utilizadas

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| Frontend | 8087 | Interface web |
| Backend | 3001 | API REST |
| Database | 5432 | PostgreSQL |

## 🔧 Configuração Manual

### 1. Variáveis de Ambiente

Crie um arquivo `.env`:

```bash
# Database
DB_PASSWORD=sua_senha_segura
DB_HOST=localhost
DB_PORT=5432
DB_NAME=softwarehub
DB_USER=softwarehub_user

# JWT
JWT_SECRET=seu_jwt_secret_super_seguro
JWT_EXPIRES_IN=24h

# Application
NODE_ENV=production
PORT=3001
CORS_ORIGIN=http://softwarehub-xp.wake.tech:8087

# Security
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=1000
SESSION_TIMEOUT=3600000
```

### 2. Deploy Manual

```bash
# Desenvolvimento
docker-compose -f docker-compose.dev.yml up -d

# Produção
docker-compose -f docker-compose.prod.yml up -d
```

## 📊 Monitoramento

### Health Checks

```bash
# Verificar status geral
curl http://localhost:3001/health

# Verificar logs
docker-compose -f docker-compose.dev.yml logs -f
```

### Comandos Úteis

```bash
# Ver status dos containers
docker-compose -f docker-compose.dev.yml ps

# Reiniciar serviços
docker-compose -f docker-compose.dev.yml restart

# Parar todos os serviços
docker-compose -f docker-compose.dev.yml down

# Ver logs específicos
docker-compose -f docker-compose.dev.yml logs backend
docker-compose -f docker-compose.dev.yml logs db
docker-compose -f docker-compose.dev.yml logs frontend
```

## 🔐 Segurança

### Produção

- ✅ Firewall configurado (UFW)
- ✅ Senhas geradas automaticamente
- ✅ Rate limiting ativo
- ✅ CORS configurado
- ✅ Headers de segurança (Helmet)

### Desenvolvimento

- ✅ Hot reload para desenvolvimento
- ✅ Logs detalhados
- ✅ Debug mode ativo

## 🔄 Backup e Recovery

### Backup Automático (Produção)

```bash
# Backup manual
/opt/softwarehub/backup.sh

# Verificar backups
ls -la /opt/softwarehub/backups/
```

### Restore

```bash
# Restaurar banco
docker exec -i softwarehub_db_1 psql -U softwarehub_user softwarehub < backup_YYYYMMDD_HHMMSS.sql
```

## 🐛 Troubleshooting

### Problemas Comuns

#### 1. Docker não instalado
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### 2. Porta já em uso
```bash
# Verificar portas
sudo netstat -tulpn | grep :8087
sudo netstat -tulpn | grep :3001

# Matar processo
sudo kill -9 <PID>
```

#### 3. Banco não conecta
```bash
# Verificar logs do banco
docker-compose -f docker-compose.dev.yml logs db

# Reiniciar banco
docker-compose -f docker-compose.dev.yml restart db
```

#### 4. Backend não inicia
```bash
# Verificar logs do backend
docker-compose -f docker-compose.dev.yml logs backend

# Executar migrations
docker-compose -f docker-compose.dev.yml exec backend npx prisma migrate deploy
```

#### 5. Frontend não carrega
```bash
# Verificar logs do frontend
docker-compose -f docker-compose.dev.yml logs frontend

# Verificar configuração do Nginx
docker-compose -f docker-compose.dev.yml exec frontend nginx -t
```

## 📈 Performance

### Otimizações Recomendadas

1. **Database**
   - Índices otimizados já configurados
   - Connection pooling ativo

2. **Backend**
   - Rate limiting configurado
   - Compression ativo
   - Logs estruturados

3. **Frontend**
   - Nginx como proxy reverso
   - Caching configurado
   - Gzip compression

## 🔍 Logs e Debug

### Logs por Serviço

```bash
# Backend logs
docker-compose -f docker-compose.dev.yml logs -f backend

# Database logs
docker-compose -f docker-compose.dev.yml logs -f db

# Frontend logs
docker-compose -f docker-compose.dev.yml logs -f frontend

# Todos os logs
docker-compose -f docker-compose.dev.yml logs -f
```

### Debug Mode

Para desenvolvimento, o backend roda em modo debug com:
- Hot reload ativo
- Logs detalhados
- Source maps habilitados

## 🎯 URLs de Acesso

### Desenvolvimento
- **Frontend**: http://localhost:8087
- **API**: http://localhost:3001/api
- **Health**: http://localhost:3001/health

### Produção
- **Frontend**: http://softwarehub-xp.wake.tech:8087
- **API**: http://softwarehub-xp.wake.tech:8087/api
- **Health**: http://softwarehub-xp.wake.tech:8087/health

## 🔐 Credenciais

### Usuário Admin Inicial
- **Email**: admin@softwarehub.com
- **Senha**: admin123
- **Role**: Admin

⚠️ **IMPORTANTE**: Altere a senha do admin após o primeiro login!

## 📞 Suporte

Para problemas ou dúvidas:

1. Verifique os logs: `docker-compose logs -f`
2. Consulte este guia
3. Abra uma issue no repositório

---

**SoftwareHub** - Sistema de Gestão de Softwares Empresariais 