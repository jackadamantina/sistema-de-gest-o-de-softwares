# Changelog - SoftwareHub

## [v1.2.0] - 2025-07-28

### ✅ Adicionado
- **Versão visível no sistema**: Adicionada versão v1.2.0 no título da página e cabeçalhos
- **Seção de informações da versão**: Nova seção no dashboard mostrando status do sistema
- **Logs de debug melhorados**: Adicionados logs para monitoramento de carregamento de dados
- **Teste de listagem de softwares**: Arquivo de teste para validar funcionamento da API
- **Correção da API_BASE_URL**: Configuração corrigida para usar proxy nginx

### 🔧 Corrigido
- **Problema de CORS**: Corrigida configuração da API para usar `/api` via nginx
- **Botão "Salvar software"**: Agora funciona corretamente
- **Listagem de softwares**: Todos os 6 softwares cadastrados são exibidos corretamente
- **Configuração do nginx**: Corrigida porta do backend de 3001 para 3002
- **Acesso em aba anônima**: Sistema agora funciona corretamente

### 📊 Status Atual
- **Total de softwares**: 6 cadastrados
- **API funcionando**: ✅
- **Frontend otimizado**: ✅
- **Sistema estável**: ✅

### 🚀 Melhorias Técnicas
- Configuração de proxy nginx corrigida
- Logs de debug adicionados para monitoramento
- Interface melhorada com informações de versão
- Sistema mais robusto e confiável

### 📝 Notas
- Sistema testado e validado
- Todos os softwares sendo exibidos corretamente
- Botões de CRUD funcionando adequadamente
- Interface responsiva e moderna

---

## [v1.1.0] - 2025-07-28 (Anterior)

### ✅ Funcionalidades Implementadas
- Sistema de gestão de softwares
- Dashboard com métricas
- CRUD completo de softwares
- Gestão de usuários
- Logs de auditoria
- Interface moderna com TailwindCSS

### 🔧 Configuração
- Docker Compose para desenvolvimento
- PostgreSQL como banco de dados
- Node.js/Express backend
- Nginx como proxy reverso 