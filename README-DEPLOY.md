# Sistema de Gestão de Softwares - Deploy Simplificado

## 🚀 Deploy Rápido para Produção

O sistema já vem pré-configurado com todas as configurações necessárias. Você só precisa definir as portas e a URL.

### Configurações Pré-definidas

- **PostgreSQL**: Porta 5435 (fixo)
- **Senha do Banco**: Configurada automaticamente
- **JWT Secret**: Configurado automaticamente
- **Backend**: Porta 3002 (customizável)
- **Frontend**: Porta 8089 (customizável)

### Passo a Passo

1. **Execute o script de deploy como root:**
```bash
sudo ./deploy-production.sh
```

2. **Informe apenas:**
   - Diretório de instalação (padrão: `/opt/sistema-gestao-softwares`)
   - Porta do Frontend (padrão: `8089`)
   - Porta do Backend (padrão: `3002`)
   - URL do sistema (opcional)

3. **O script automaticamente irá:**
   - Instalar Docker e Docker Compose se necessário
   - Criar todas as configurações
   - Construir e iniciar os containers
   - Configurar serviço systemd
   - Configurar backup automático

### Credenciais Padrão

- **Email**: admin@softwarehub.com
- **Senha**: admin123

### Comandos Úteis

```bash
# Ver status
docker-compose -f docker-compose.production.yml ps

# Ver logs
docker-compose -f docker-compose.production.yml logs -f

# Parar sistema
systemctl stop softwarehub

# Iniciar sistema
systemctl start softwarehub
```

### Estrutura de Arquivos

```
/opt/sistema-gestao-softwares/
├── docker-compose.production.yml  # Configuração Docker
├── .env                          # Variáveis de ambiente
├── backend/                      # Código do backend
├── frontend/                     # Arquivos do frontend
├── uploads/                      # Arquivos enviados
└── index.html                    # Interface principal
```

### Portas Utilizadas

| Serviço    | Porta | Descrição               |
|------------|-------|-------------------------|
| PostgreSQL | 5435  | Banco de dados (fixo)   |
| Backend    | 3002  | API (customizável)      |
| Frontend   | 8089  | Interface (customizável)|

### Backup

Backups automáticos são realizados diariamente às 2h da manhã.
Local: `/var/backups/softwarehub/`

Para backup manual:
```bash
/usr/local/bin/softwarehub-backup.sh
```

### Solução de Problemas

**Porta já em uso:**
```bash
# Verificar o que está usando a porta
sudo lsof -i :PORTA

# Verificar containers Docker
docker ps
```

**Erro de permissão:**
- Execute o script como root: `sudo ./deploy-production.sh`

**Container não inicia:**
```bash
# Ver logs detalhados
docker-compose -f docker-compose.production.yml logs [serviço]
```

### Segurança

1. **Altere a senha padrão** após o primeiro login
2. Configure um **certificado SSL** para produção
3. Configure o **firewall** adequadamente
4. Revise as configurações em `.env`

### Suporte

Para mais informações, consulte a documentação completa em `DEPLOY.md`.