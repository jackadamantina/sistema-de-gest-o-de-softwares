# Controle de Versão - SoftwareHub

## Visão Geral

O sistema de controle de versão do SoftwareHub permite verificar se a versão em execução está atualizada e sincronizada com o código fonte.

## Arquivos de Controle

### VERSION
- Arquivo principal que contém a versão atual do sistema
- Formato: `MAJOR.MINOR.PATCH` (ex: `1.0.0`)
- Localização: `/VERSION`

### Endpoints de API

#### GET /version
- Retorna informações detalhadas sobre a versão em execução
- Inclui: versão, data do build, uptime, informações do sistema
- Exemplo de resposta:
```json
{
  "version": "1.0.0",
  "buildDate": "2025-01-27T10:30:00.000Z",
  "nodeVersion": "v18.17.0",
  "platform": "linux",
  "uptime": 3600,
  "memoryUsage": {...},
  "environment": "production"
}
```

## Scripts Disponíveis

### 1. Verificação de Versão
```bash
./scripts/check-version.sh
```
- Compara a versão do arquivo VERSION com a versão em execução
- Verifica se o backend está rodando
- Mostra informações detalhadas sobre o sistema

### 2. Incremento de Versão
```bash
./scripts/bump-version.sh [patch|minor|major]
```
- Incrementa a versão automaticamente
- Atualiza package.json do backend e frontend
- Atualiza versão nos arquivos HTML
- Cria tag git (opcional)

### 3. Atualização do Frontend
```bash
./scripts/update-frontend-version.sh
```
- Atualiza todas as referências de versão nos arquivos HTML
- Atualiza data de última atualização
- Sincroniza frontend com a versão atual

## Como Verificar se a Versão Está Atualizada

### 1. Via Interface Web
- Acesse o dashboard
- Clique em "Verificar Versão Atual" na seção de informações
- A versão será atualizada automaticamente na interface

### 2. Via Script
```bash
./scripts/check-version.sh
```

### 3. Via API
```bash
curl http://localhost:3002/version
```

## Fluxo de Deploy

### Opção 1: Deploy Rápido (Recomendado)
```bash
./scripts/quick-deploy.sh
```
- Automatiza: `sistema-gestao stop` → `git pull` → `deploy-production.sh`
- Inclui verificações de segurança
- Mostra status final dos containers

### Opção 2: Deploy Completo
```bash
./scripts/deploy-workflow.sh
```
- Fluxo completo com verificações detalhadas
- Inclui verificação de versão antes e depois
- Tratamento de mudanças não commitadas
- Resumo detalhado do deploy

### Opção 3: Deploy Manual (Seu fluxo atual)
```bash
# 1. Parar sistema
systemctl stop softwarehub

# 2. Atualizar código
git pull

# 3. Fazer deploy
./deploy-production.sh
```

### Opção 4: Deploy com Incremento de Versão
```bash
# 1. Incrementar versão
./scripts/bump-version.sh patch  # ou minor/major

# 2. Deploy completo
./scripts/quick-deploy.sh
```

## Identificação de Problemas

### Versões Diferentes
Se a versão do arquivo VERSION for diferente da versão em execução:

1. **Verificar se o deploy foi concluído**
   ```bash
   docker-compose ps
   ```

2. **Reiniciar containers**
   ```bash
   docker-compose restart
   ```

3. **Fazer novo deploy**
   ```bash
   ./deploy-production.sh
   ```

### Backend Não Responde
Se o endpoint `/version` não responder:

1. **Verificar se containers estão rodando**
   ```bash
   docker-compose ps
   ```

2. **Verificar logs**
   ```bash
   docker-compose logs backend
   ```

3. **Reiniciar sistema**
   ```bash
   docker-compose down
   docker-compose up -d
   ```

## Estrutura de Versões

### Semântica
- **MAJOR**: Mudanças incompatíveis com versões anteriores
- **MINOR**: Novos recursos mantendo compatibilidade
- **PATCH**: Correções de bugs mantendo compatibilidade

### Exemplos
- `1.0.0` - Versão inicial
- `1.0.1` - Correção de bug
- `1.1.0` - Novo recurso
- `2.0.0` - Mudança grande (incompatível)

## Monitoramento

### Logs de Versão
O sistema registra automaticamente:
- Data/hora de cada deploy
- Versão anterior e nova versão
- Usuário que fez o deploy
- Status do deploy

### Alertas
- Versões diferentes entre arquivo e execução
- Backend não respondendo
- Deploy incompleto

## Comandos Úteis

```bash
# Verificar versão atual
cat VERSION

# Verificar status dos containers
docker-compose ps

# Ver logs do backend
docker-compose logs backend

# Verificar se API está respondendo
curl http://localhost:3002/health

# Verificar versão via API
curl http://localhost:3002/version

# Reiniciar sistema
docker-compose restart

# Deploy completo
./deploy-production.sh
```

## Troubleshooting

### Problema: Versão não atualiza no frontend
**Solução:**
```bash
./scripts/update-frontend-version.sh
docker-compose restart
```

### Problema: Backend não responde
**Solução:**
```bash
docker-compose logs backend
docker-compose restart backend
```

### Problema: Versões diferentes
**Solução:**
```bash
./scripts/check-version.sh
./deploy-production.sh
```

## Notas Importantes

1. **Sempre verifique a versão após o deploy**
2. **Use o script de verificação antes de reportar problemas**
3. **Mantenha o arquivo VERSION atualizado**
4. **Documente mudanças importantes nas versões**
5. **Teste sempre em ambiente de desenvolvimento antes do deploy** 