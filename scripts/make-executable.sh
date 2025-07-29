#!/bin/bash

# Make all scripts executable
chmod +x scripts/*.sh

echo "✅ Todos os scripts tornados executáveis"
echo ""
echo "📋 Scripts disponíveis:"
echo "   • scripts/quick-start.sh     - Início rápido para preview"
echo "   • scripts/deploy-local.sh    - Deploy local (Ubuntu 24)"
echo "   • scripts/deploy-prod.sh     - Deploy produção (Debian 12)"
echo ""
echo "🚀 Para fazer preview, execute:"
echo "   ./scripts/quick-start.sh" 