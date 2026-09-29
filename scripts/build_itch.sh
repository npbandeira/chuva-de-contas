#!/usr/bin/env bash
# Gera os pacotes do Chuva de Contas para publicar no itch.io, em build/itch/:
#   chuva-de-contas-v<versão>.love      jogo puro (precisa do LÖVE 11.5 instalado)
#   chuva-de-contas-v<versão>-web.zip   HTML5, para jogar no navegador (love.js)
#   chuva-de-contas-v<versão>-windows.zip
#   chuva-de-contas-v<versão>-macos.zip
#   chuva-de-contas-v<versão>-linux.AppImage
#   chuva-de-contas-v<versão>-android.apk   (copiado de build/, se existir)
#
# Uso: ./scripts/build_itch.sh
# Ferramentas baixadas ficam em build/tools/itch (fora do git).
set -euo pipefail

APP_NAME="Chuva de Contas"
SLUG="chuva-de-contas"
BUNDLE_ID="com.npbandeira.chuvadecontas"
LOVE_VERSION="11.5"
LOVEJS_VERSION="11.4.1"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n 's/^GAME_VERSION = "\(.*\)"/\1/p' "$ROOT/conf.lua")"
NAME="$SLUG-v$VERSION"
TOOLS="$ROOT/build/tools/itch"
OUT="$ROOT/build/itch"
WORK="$OUT/work"

mkdir -p "$TOOLS"
# apaga só os pacotes antigos: o resto de build/itch (ex.: media/) fica
rm -rf "$WORK" "$OUT"/"$SLUG"-v*
mkdir -p "$WORK"

fetch() { # fetch <arquivo> <url>
    if [ ! -f "$TOOLS/$1" ]; then
        echo ">> baixando $1"
        curl -fsSL -o "$TOOLS/$1" "$2"
    fi
}
LOVE_REL="https://github.com/love2d/love/releases/download/$LOVE_VERSION"
fetch love-win64.zip "$LOVE_REL/love-$LOVE_VERSION-win64.zip"
fetch love-macos.zip "$LOVE_REL/love-$LOVE_VERSION-macos.zip"
fetch love.AppImage "$LOVE_REL/love-$LOVE_VERSION-x86_64.AppImage"
fetch appimagetool "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "$TOOLS/love.AppImage" "$TOOLS/appimagetool"

# ---------------------------------------------------------------- .love
echo ">> .love"
LOVEFILE="$OUT/$NAME.love"
python3 - "$ROOT" "$LOVEFILE" <<'EOF'
import os, sys, zipfile
root, out = sys.argv[1], sys.argv[2]
files = ["main.lua", "conf.lua", "problems.lua", "LICENSE"]
for d in ("src", "assets"):
    for base, _, names in os.walk(os.path.join(root, d)):
        files += [os.path.relpath(os.path.join(base, n), root) for n in names]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(files):
        z.write(os.path.join(root, f), f)
EOF

# ---------------------------------------------------------------- Windows
echo ">> Windows"
WIN="$WORK/$APP_NAME"
mkdir -p "$WORK/win" && unzip -q "$TOOLS/love-win64.zip" -d "$WORK/win"
mv "$WORK/win"/love-*-win64 "$WIN"
# "fused": o jogo vai colado no fim do executável do LÖVE
cat "$WIN/love.exe" "$LOVEFILE" >"$WIN/$APP_NAME.exe"
rm -f "$WIN/love.exe" "$WIN/lovec.exe" "$WIN/love.ico" "$WIN/game.ico" "$WIN/changes.txt" "$WIN/readme.txt"
mv "$WIN/license.txt" "$WIN/LOVE-license.txt"
cp "$ROOT/LICENSE" "$WIN/LICENSE.txt"
(cd "$WORK" && 7z a -tzip -bso0 -bsp0 "$OUT/$NAME-windows.zip" "$APP_NAME")
rm -rf "$WIN" "$WORK/win"

# ---------------------------------------------------------------- macOS
echo ">> macOS"
mkdir -p "$WORK/mac" && unzip -q "$TOOLS/love-macos.zip" -d "$WORK/mac"
APP="$WORK/mac/$APP_NAME.app"
mv "$WORK/mac/love.app" "$APP"
cp "$LOVEFILE" "$APP/Contents/Resources/$SLUG.love"
python3 - "$APP" "$APP_NAME" "$BUNDLE_ID" "$VERSION" "$ROOT/android/icon.png" <<'EOF'
import plistlib, sys
from PIL import Image
app, name, bundle_id, version, icon = sys.argv[1:]
path = f"{app}/Contents/Info.plist"
with open(path, "rb") as f:
    info = plistlib.load(f)
info.update({
    "CFBundleName": name,
    "CFBundleDisplayName": name,
    "CFBundleIdentifier": bundle_id,
    "CFBundleShortVersionString": version,
    "CFBundleVersion": version,
    "NSHumanReadableCopyright": "Copyright (c) 2026 Nicolas Pantoja",
})
# sem isso o macOS trataria o app como "abridor de arquivos .love"
info.pop("UTExportedTypeDeclarations", None)
info.pop("CFBundleDocumentTypes", None)
with open(path, "wb") as f:
    plistlib.dump(info, f)
img = Image.open(icon).convert("RGBA")
for n in ("OS X AppIcon.icns", "GameIcon.icns"):
    img.save(f"{app}/Contents/Resources/{n}", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512)])
EOF
cp "$ROOT/LICENSE" "$WORK/mac/LICENSE.txt"
# -snl mantém os links simbólicos dos frameworks dentro do .app
(cd "$WORK/mac" && 7z a -tzip -snl -bso0 -bsp0 "$OUT/$NAME-macos.zip" "$APP_NAME.app" LICENSE.txt)
rm -rf "$WORK/mac"

# ---------------------------------------------------------------- Linux
echo ">> Linux (AppImage)"
(cd "$WORK" && "$TOOLS/love.AppImage" --appimage-extract >/dev/null)
SQ="$WORK/squashfs-root"
cat "$SQ/bin/love" "$LOVEFILE" >"$SQ/bin/love-fused"
mv "$SQ/bin/love-fused" "$SQ/bin/love"
chmod +x "$SQ/bin/love"
# nome e ícone do atalho
DESKTOP="$(ls "$SQ"/*.desktop | head -1)"
sed -i -e "s/^Name=.*/Name=$APP_NAME/" -e 's/^Comment=.*/Comment=Resolva as contas antes que caiam no chão!/' \
    -e 's/^Icon=.*/Icon=chuva-de-contas/' -e '/^MimeType=/d' "$DESKTOP"
rm -f "$SQ"/*.svg "$SQ"/*.png "$SQ/.DirIcon"
cp "$ROOT/android/icon.png" "$SQ/chuva-de-contas.png"
ln -s chuva-de-contas.png "$SQ/.DirIcon"
ARCH=x86_64 "$TOOLS/appimagetool" --appimage-extract-and-run --no-appstream "$SQ" "$OUT/$NAME-linux.AppImage" >/dev/null 2>&1
rm -rf "$SQ"

# ---------------------------------------------------------------- Web
echo ">> Web (love.js $LOVEJS_VERSION)"
# -c: modo compatível, roda em qualquer navegador sem SharedArrayBuffer
npx --yes "love.js@$LOVEJS_VERSION" -c -t "$APP_NAME" -m 67108864 "$LOVEFILE" "$WORK/web" >/dev/null 2>&1
# troca a página padrão (arte e textos do love.js) por uma própria, em pt-BR
rm -rf "$WORK/web/theme"
cp "$ROOT/scripts/web/index.html" "$WORK/web/index.html"
(cd "$WORK/web" && 7z a -tzip -bso0 -bsp0 "$OUT/$NAME-web.zip" .)
rm -rf "$WORK/web"

# ---------------------------------------------------------------- Android
if [ -f "$ROOT/build/$NAME.apk" ]; then
    cp "$ROOT/build/$NAME.apk" "$OUT/$NAME-android.apk"
else
    echo "!! build/$NAME.apk não encontrado: rode ./android/build_apk.sh para incluir o Android"
fi

rmdir "$WORK"
echo ">> pronto:"
ls -lh "$OUT" | tail -n +2
