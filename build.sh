#!/usr/bin/env bash
# Сборка EuroOffice-плагина из upstream ONLYOFFICE-плагина. Нужны Docker и git.
set -euo pipefail
cd "$(dirname "$0")"

PLUGIN_ID=88nex.eurooffice
VERSION=1.0.0
OUT=$(pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "== clone upstream =="
git clone --depth 1 --recursive https://github.com/ONLYOFFICE/onlyoffice-mattermost.git "$WORK/src"
cd "$WORK/src"
rm -rf .git dist server/dist webapp/dist webapp/node_modules

echo "== rebrand =="
grep -rIl --exclude-dir=node_modules --exclude-dir=dist 'com.onlyoffice.mattermost' . \
  | xargs -r sed -i "s/com\.onlyoffice\.mattermost/${PLUGIN_ID}/g"
grep -rIl --exclude-dir=node_modules --exclude-dir=dist 'ONLYOFFICE' webapp/src public assets \
  | xargs -r sed -i 's/ONLYOFFICE/EuroOffice/g'
grep -rIl --exclude-dir=node_modules --exclude-dir=dist 'ONLYOFFICE' server \
  | while read -r f; do sed -i '/github\.com\/ONLYOFFICE/!s/ONLYOFFICE/EuroOffice/g' "$f"; done
sed -i 's/Username:    "onlyoffice"/Username:    "eurooffice"/' server/cmd/plugin.go

cp "$OUT/plugin.json" plugin.json

# Mattermost читает настройки в нижнем регистре — приводим JSON-теги к нему
perl -pi -e 'if (/^\t(DESAddress|DESJwt|DESJwtHeader|DESJwtPrefix|DESAllowPrivate|DemoEnabled|DemoExpires|DemoAddress|DemoHeader|DemoPrefix|DemoSecret|Formats|OwnerProtected|PluginsEnabled|MacrosEnabled|HealthNotificationsEnabled)\s+(string|bool|int64)$/) { chomp; $_ .= " `json:\"".lc($1)."\"`\n"; }' server/pkg/configuration/configuration.go

cat > assets/logo.svg <<'EOF'
<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
  <rect width="48" height="48" rx="10" fill="#1F5FBF"/>
  <text x="24" y="31" font-family="Arial, Helvetica, sans-serif" font-size="17" font-weight="700" fill="#FFFFFF" text-anchor="middle">EO</text>
</svg>
EOF

echo "== server =="
docker run --rm -v "$WORK/src":/src -w /src/server -e CGO_ENABLED=0 -e GOOS=linux -e GOARCH=amd64 \
  golang:1.26 sh -c 'go build -trimpath -o dist/plugin-linux-amd64 .'

echo "== webapp =="
docker run --rm -v "$WORK/src":/src -w /src/webapp -e NODE_OPTIONS=--max-old-space-size=4096 \
  node:24 sh -c 'npm ci --no-audit --no-fund >/dev/null 2>&1 && npm run build'

echo "== bundle =="
mkdir -p "$WORK/src/dist/${PLUGIN_ID}/server" "$WORK/src/dist/${PLUGIN_ID}/webapp"
cp plugin.json "$WORK/src/dist/${PLUGIN_ID}/"
cp LICENSE NOTICE AUTHORS.md SECURITY.md "$WORK/src/dist/${PLUGIN_ID}/"
cp -r assets public "$WORK/src/dist/${PLUGIN_ID}/"
cp -r server/dist "$WORK/src/dist/${PLUGIN_ID}/server/"
cp -r webapp/dist "$WORK/src/dist/${PLUGIN_ID}/webapp/"
mkdir -p "$OUT/dist"
tar -C "$WORK/src/dist" -czf "$OUT/dist/${PLUGIN_ID}-${VERSION}.tar.gz" "$PLUGIN_ID"
ls -lh "$OUT/dist/${PLUGIN_ID}-${VERSION}.tar.gz"
