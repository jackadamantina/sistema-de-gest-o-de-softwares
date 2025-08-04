# 🚀 Deploy em Produção - Sistema de Gestão de Softwares

## Visão Geral

O sistema está completamente pré-configurado e otimizado para deploy em produção. Todas as correções e ajustes já estão integrados no código.

## Características do Deploy

### ✅ Pré-configurações Incluídas

1. **PostgreSQL na porta 5435** - Configurado automaticamente
2. **Migrações Prisma** - Aplicadas automaticamente no primeiro deploy
3. **Usuários padrão** - Criados automaticamente
4. **Tipos ENUM** - Configurados corretamente pelo Prisma
5. **Nginx** - Configurado para proxy reverso
6. **JWT e Segurança** - Tokens pré-configurados

### 📋 Requisitos

- Docker e Docker Compose instalados
- Portas disponíveis: 5435 (PostgreSQL), 3002 (Backend), 8089 (Frontend)
- 2GB RAM mínimo
- 10GB espaço em disco

## 🔧 Deploy Rápido

### 1. Execute o script de deploy

```bash
sudo ./deploy-production.sh
```

### 2. Informe apenas 3 configurações

- **Porta do Frontend** (padrão: 8089)
- **Porta do Backend** (padrão: 3002)  
- **URL do sistema** (opcional)

### 3. Pronto!

O script automaticamente:
- ✅ Configura o banco de dados
- ✅ Aplica migrações
- ✅ Cria usuários padrão
- ✅ Configura backup automático
- ✅ Cria serviço systemd

## 📊 Arquitetura

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│   Frontend  │────▶│   Backend   │────▶│  PostgreSQL  │
│  (Nginx)    │     │  (Node.js)  │     │   (5435)     │
│   (8089)    │     │   (3002)    │     └──────────────┘
└─────────────┘     └─────────────┘
```

## 🔑 Credenciais Padrão

| Usuário | Email | Senha | Permissão |
|---------|-------|-------|-----------|
| Admin | admin@softwarehub.com | admin123 | Total |
| Editor | editor@softwarehub.com | editor123 | Edição |
| Viewer | viewer@softwarehub.com | viewer123 | Visualização |

## 🛠️ Comandos Úteis

### Status do Sistema
```bash
# Ver status
sudo systemctl status softwarehub

# Ver containers
docker-compose -f docker-compose.production.yml ps

# Ver logs
docker-compose -f docker-compose.production.yml logs -f
```

### Backup Manual
```bash
/usr/local/bin/softwarehub-backup.sh
```

### Restart dos Serviços
```bash
# Restart completo
sudo systemctl restart softwarehub

# Restart específico
docker-compose -f docker-compose.production.yml restart backend
```

## 🔍 Solução de Problemas

### Backend não inicia
```bash
# Ver logs detalhados
docker-compose -f docker-compose.production.yml logs backend

# Verificar migrações
docker exec sistema-gestao-softwares-backend-1 npx prisma migrate status
```

### Erro 502 Bad Gateway
- Backend ainda está iniciando (aguarde 30 segundos)
- Verificar logs do backend

### Erro 500 ao criar software
- Sistema está aplicando migrações (aguarde 1 minuto)

## 🔐 Segurança

### Recomendações Pós-Deploy

1. **Altere as senhas padrão** imediatamente
2. **Configure SSL/TLS** com Let's Encrypt
3. **Configure firewall** para as portas utilizadas
4. **Altere JWT_SECRET** no arquivo .env
5. **Configure backup externo** além do local

### Firewall Sugerido
```bash
# Permitir apenas portas necessárias
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 8089/tcp  # Frontend
sudo ufw allow 3002/tcp  # Backend (se API pública)
sudo ufw enable
```

## 📈 Monitoramento

### Verificar Saúde
```bash
# Health check do backend
curl http://localhost:3002/api/health

# Verificar banco
docker exec sistema-gestao-softwares-db-1 pg_isready
```

### Logs em Tempo Real
```bash
# Todos os serviços
docker-compose -f docker-compose.production.yml logs -f

# Apenas erros
docker-compose -f docker-compose.production.yml logs -f | grep -E "ERROR|error"
```

## 🔄 Atualizações

Para atualizar o sistema:

1. Faça backup
```bash
/usr/local/bin/softwarehub-backup.sh
```

2. Atualize o código
```bash
git pull origin main
```

3. Reconstrua e reinicie
```bash
docker-compose -f docker-compose.production.yml build
sudo systemctl restart softwarehub
```

## 📞 Suporte

Em caso de problemas:
1. Verifique os logs
2. Consulte a seção de solução de problemas
3. Verifique se todas as portas estão livres
4. Certifique-se que o Docker está funcionando

---

**Sistema desenvolvido com todas as correções integradas - Deploy simples e rápido!**