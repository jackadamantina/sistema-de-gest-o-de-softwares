#!/bin/bash

# Script para incrementar versão automaticamente

# Ler versão atual
CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")

# Separar versão em partes
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Determinar tipo de incremento
TYPE="${1:-patch}"

case "$TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch|*)
        PATCH=$((PATCH + 1))
        ;;
esac

# Nova versão
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# Atualizar arquivo VERSION
echo "$NEW_VERSION" > VERSION

# Atualizar package.json do backend
if [ -f "backend/package.json" ]; then
    sed -i "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" backend/package.json
fi

# Atualizar package.json do frontend
if [ -f "frontend/package.json" ]; then
    sed -i "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" frontend/package.json
fi

# Atualizar versão no frontend automaticamente
if [ -f "scripts/update-frontend-version.sh" ]; then
    echo "🔄 Atualizando versão no frontend..."
    ./scripts/update-frontend-version.sh
fi

echo "✅ Versão atualizada: $CURRENT_VERSION → $NEW_VERSION"

# Criar tag git
read -p "Criar tag git v$NEW_VERSION? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    git add VERSION backend/package.json frontend/package.json
    git commit -m "chore: bump version to $NEW_VERSION"
    git tag -a "v$NEW_VERSION" -m "Version $NEW_VERSION"
    echo "✅ Tag v$NEW_VERSION criada"
fi