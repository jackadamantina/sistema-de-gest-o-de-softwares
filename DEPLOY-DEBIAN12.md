# 🚀 SoftwareHub - Deploy no Debian 12

Este documento descreve como instalar e configurar o SoftwareHub em um servidor Debian 12, considerando a coexistência com outros containers e bancos de dados.

## 📋 Pré-requisitos

- **Sistema**: Debian 12 (Bookworm)
- **Acesso**: Root ou sudo
- **Recursos mínimos**:
  - 2GB RAM
  - 10GB espaço em disco
  - 2 cores CPU

## 🛠️ Scripts de Instalação

### 1. Instalação Rápida (Recomendado)

```bash
# Baixar o projeto
git clone <seu-repositorio>
cd sistema-de-gestão-de-softwares

# Executar instalação completa
sudo ./scripts/install-debian12.sh
```

### 2. Deploy Simplificado

```bash
# Para sistemas já com Docker instalado
sudo ./scripts/deploy-debian12.sh
```

### 3. Gerenciamento de Containers

```bash
# Para configurar coexistência com outros containers
sudo ./scripts/manage-containers.sh
```

## 🔧 Instalação Manual

### Passo 1: Preparar o Sistema

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    net-tools \
    ufw \
    openssl \
    cron \
    htop \
    tree
```

### Passo 2: Instalar Docker

```bash
# Adicionar repositório Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Iniciar e habilitar Docker
sudo systemctl start docker
sudo systemctl enable docker
```

### Passo 3: Configurar Docker

```bash
# Criar configuração do Docker
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << EOF
{
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Reiniciar Docker
sudo systemctl restart docker
```

### Passo 4: Preparar Diretório da Aplicação

```bash
# Criar diretórios
sudo mkdir -p /opt/softwarehub
sudo mkdir -p /opt/softwarehub/data/postgres
sudo mkdir -p /opt/softwarehub/data/uploads
sudo mkdir -p /opt/softwarehub/logs
sudo mkdir -p /opt/softwarehub/backups

# Copiar arquivos
sudo cp -r * /opt/softwarehub/
cd /opt/softwarehub
```

### Passo 5: Configurar Ambiente

```bash
# Gerar senhas seguras
DB_PASSWORD=$(openssl rand -base64 24)
JWT_SECRET=$(openssl rand -base64 48)

# Criar arquivo .env
sudo tee .env << EOF
# Database
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5435
DB_NAME=softwarehub
DB_USER=softwarehub_user

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=24h

# Application
NODE_ENV=production
PORT=3001
CORS_ORIGIN=http://localhost:8087

# Security
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=1000
SESSION_TIMEOUT=3600000
EOF

# Definir permissões
sudo chmod 600 .env
```

### Passo 6: Configurar Rede Docker

```bash
# Criar rede dedicada
sudo docker network create --driver bridge --subnet=172.20.0.0/16 softwarehub-network
```

### Passo 7: Fazer Deploy

```bash
# Construir e iniciar containers
sudo docker-compose -f docker-compose.prod.yml up -d --build
```

### Passo 8: Configurar Firewall

```bash
# Configurar UFW
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8087/tcp
sudo ufw allow 3001/tcp
```

### Passo 9: Criar Serviço Systemd

```bash
# Criar arquivo de serviço
sudo tee /etc/systemd/system/softwarehub.service << EOF
[Unit]
Description=SoftwareHub Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/softwarehub
ExecStart=/usr/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Habilitar serviço
sudo systemctl daemon-reload
sudo systemctl enable softwarehub.service
```

## 🌐 Configuração de Rede

### Portas Utilizadas

- **8087**: Frontend (HTTP)
- **3001**: Backend API
- **5435**: PostgreSQL (externo)

### Verificar Conflitos de Porta

```bash
# Verificar portas em uso
sudo netstat -tuln | grep -E ":(3001|5435|8087)"

# Verificar containers usando estas portas
sudo docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "(3001|5435|8087)"
```

## 🔍 Monitoramento

### Script de Monitoramento

```bash
# Executar monitoramento manual
sudo /opt/softwarehub/monitor.sh

# Ver logs em tempo real
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml logs -f
```

### Verificar Status dos Serviços

```bash
# Status do serviço systemd
sudo systemctl status softwarehub

# Status dos containers
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml ps

# Verificar saúde dos serviços
curl -f http://localhost:3001/health
curl -f http://localhost:8087
```

## 💾 Backup e Restauração

### Backup Automático

O sistema configura automaticamente:
- Backup diário às 2h da manhã
- Retenção de 7 dias
- Backup do banco de dados e arquivos

### Backup Manual

```bash
# Executar backup manual
sudo /opt/softwarehub/backup.sh

# Verificar backups
sudo ls -la /opt/softwarehub/backups/
```

### Restauração

```bash
# Parar aplicação
sudo systemctl stop softwarehub

# Restaurar banco de dados
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml exec -T db psql -U softwarehub_user -d softwarehub < /opt/softwarehub/backups/db_backup_YYYYMMDD_HHMMSS.sql

# Restaurar arquivos
sudo tar -xzf /opt/softwarehub/backups/app_backup_YYYYMMDD_HHMMSS.tar.gz -C /opt/softwarehub/

# Reiniciar aplicação
sudo systemctl start softwarehub
```

## 🔧 Comandos Úteis

### Gerenciamento de Serviços

```bash
# Iniciar aplicação
sudo systemctl start softwarehub

# Parar aplicação
sudo systemctl stop softwarehub

# Reiniciar aplicação
sudo systemctl restart softwarehub

# Ver status
sudo systemctl status softwarehub
```

### Gerenciamento de Containers

```bash
# Ver logs
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml logs -f

# Reiniciar containers
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml restart

# Reconstruir containers
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml up -d --build

# Parar containers
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml down
```

### Limpeza e Manutenção

```bash
# Limpar containers não utilizados
sudo docker system prune -f

# Limpar volumes não utilizados
sudo docker volume prune -f

# Limpar imagens não utilizadas
sudo docker image prune -f

# Ver uso de recursos
sudo docker stats
```

## 🚨 Solução de Problemas

### Problemas Comuns

1. **Porta já em uso**
   ```bash
   # Verificar o que está usando a porta
   sudo netstat -tuln | grep :3001
   sudo docker ps | grep 3001
   ```

2. **Container não inicia**
   ```bash
   # Ver logs do container
   sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml logs [service_name]
   ```

3. **Problemas de permissão**
   ```bash
   # Corrigir permissões
   sudo chown -R 999:999 /opt/softwarehub/data/postgres
   sudo chmod -R 755 /opt/softwarehub/data
   ```

4. **Problemas de rede**
   ```bash
   # Verificar redes Docker
   sudo docker network ls
   sudo docker network inspect softwarehub-network
   ```

### Logs Importantes

```bash
# Logs do sistema
sudo journalctl -u softwarehub -f

# Logs do Docker
sudo journalctl -u docker -f

# Logs da aplicação
sudo docker-compose -f /opt/softwarehub/docker-compose.prod.yml logs -f
```

## 📊 Informações de Acesso

Após a instalação, o sistema estará disponível em:

- **Frontend**: http://localhost:8087
- **API**: http://localhost:3001
- **Health Check**: http://localhost:3001/health

### Credenciais Padrão

- **Email**: admin@softwarehub.com
- **Senha**: admin123

⚠️ **IMPORTANTE**: Altere a senha do administrador após o primeiro login!

## 🔒 Segurança

### Configurações de Segurança

1. **Firewall configurado** com UFW
2. **Senhas geradas automaticamente** com OpenSSL
3. **Arquivo .env protegido** (600)
4. **Rede Docker isolada**
5. **Logs rotacionados** (10MB, 3 arquivos)

### Recomendações Adicionais

1. **Configurar SSL/TLS** para produção
2. **Usar proxy reverso** (Nginx/Apache)
3. **Implementar autenticação** adicional
4. **Configurar monitoramento** externo
5. **Fazer backup externo** dos dados

## 📞 Suporte

Para problemas ou dúvidas:

1. Verifique os logs: `/opt/softwarehub/logs/`
2. Execute o monitor: `/opt/softwarehub/monitor.sh`
3. Consulte a documentação do projeto
4. Abra uma issue no repositório

---

**Versão**: 1.0  
**Data**: $(date)  
**Compatível**: Debian 12 (Bookworm)