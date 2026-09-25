#!/usr/bin/env bash
# Gera o APK Android do Chuva de Contas a partir do APK "embed" oficial do LÖVE 11.5.
# Uso: ./android/build_apk.sh   ->   build/chuva-de-contas-v<versão>.apk
set -euo pipefail

APP_NAME="Chuva de Contas"
PACKAGE="com.npbandeira.chuvadecontas"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# versão vem do GAME_VERSION no conf.lua ("1.1" -> versionCode 101)
VERSION_NAME="$(sed -n 's/^GAME_VERSION = "\(.*\)"/\1/p' "$ROOT/conf.lua")"
VERSION_CODE="$(echo "$VERSION_NAME" | awk -F. '{ print $1 * 100 + $2 }')"
OUTPUT="chuva-de-contas-v$VERSION_NAME.apk"
BUILD="$ROOT/build"
TOOLS="$BUILD/tools"
WORK="$BUILD/decoded"
KEYSTORE="$ROOT/android/release.keystore"
KS_PASS="chuvadecontas"
KS_ALIAS="chuvadecontas"

mkdir -p "$TOOLS"

fetch() { # fetch <arquivo> <url>
    if [ ! -f "$TOOLS/$1" ]; then
        echo ">> baixando $1"
        curl -fsSL -o "$TOOLS/$1" "$2"
    fi
}
fetch love-embed.apk https://github.com/love2d/love-android/releases/download/11.5/love-11.5-android-embed-norecording.apk
fetch apktool.jar https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar
fetch uber-apk-signer.jar https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar

echo ">> abrindo o APK base do LÖVE"
rm -rf "$WORK"
java -jar "$TOOLS/apktool.jar" d -f -s -o "$WORK" "$TOOLS/love-embed.apk" >/dev/null

echo ">> copiando o jogo para assets/"
# O LÖVE 11.5 no Android só carrega o jogo embutido com os arquivos soltos em
# assets/ (main.lua na raiz). Um assets/game.love é ignorado e abre a tela "no game".
rm -rf "$WORK/assets/main.love" "$WORK/assets/main.lua" "$WORK/assets/a" "$WORK/assets/game.love"
cp "$ROOT/main.lua" "$ROOT/conf.lua" "$ROOT/problems.lua" "$WORK/assets/"
cp -r "$ROOT/src" "$WORK/assets/src"
cp -r "$ROOT/assets" "$WORK/assets/assets"

echo ">> ajustando nome, pacote e orientação"
MANIFEST="$WORK/AndroidManifest.xml"
sed -i \
    -e "s/package=\"org.love2d.android\"/package=\"$PACKAGE\"/" \
    -e "s/android:label=\"LÖVE for Android\"/android:label=\"$APP_NAME\"/g" \
    -e 's/android:screenOrientation="landscape"/android:screenOrientation="portrait"/' \
    -e "s/org.love2d.android.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION/$PACKAGE.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION/g" \
    -e "s/org.love2d.android.androidx-startup/$PACKAGE.androidx-startup/" \
    "$MANIFEST"
sed -i \
    -e "s/versionCode: .*/versionCode: $VERSION_CODE/" \
    -e "s/versionName: .*/versionName: $VERSION_NAME/" \
    "$WORK/apktool.yml"

echo ">> trocando o ícone"
[ -f "$ROOT/android/icon.png" ] || python3 "$ROOT/android/make_icon.py"
python3 - "$ROOT/android/icon.png" "$WORK/res" <<'EOF'
import sys
from PIL import Image
icon = Image.open(sys.argv[1]).convert("RGBA")
for dpi, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    icon.resize((size, size), Image.LANCZOS).save(f"{sys.argv[2]}/drawable-{dpi}/love.png")
EOF

echo ">> montando o APK"
UNSIGNED="$BUILD/chuva-de-contas-unsigned.apk"
java -jar "$TOOLS/apktool.jar" b -o "$UNSIGNED" "$WORK" >/dev/null

# chave própria do app: mantenha este arquivo para poder instalar atualizações por cima
if [ ! -f "$KEYSTORE" ]; then
    echo ">> criando chave de assinatura ($KEYSTORE)"
    keytool -genkeypair -keystore "$KEYSTORE" -alias "$KS_ALIAS" -keyalg RSA -keysize 2048 \
        -validity 10000 -storepass "$KS_PASS" -keypass "$KS_PASS" \
        -dname "CN=$APP_NAME, O=Vekttor, C=BR" >/dev/null 2>&1
fi

echo ">> alinhando e assinando"
java -jar "$TOOLS/uber-apk-signer.jar" --apks "$UNSIGNED" --out "$BUILD/signed" \
    --ks "$KEYSTORE" --ksAlias "$KS_ALIAS" --ksPass "$KS_PASS" --ksKeyPass "$KS_PASS" >/dev/null
mv "$BUILD/signed/"*.apk "$BUILD/$OUTPUT"
rm -rf "$BUILD/signed" "$UNSIGNED"

echo ">> pronto: $BUILD/$OUTPUT (versão $VERSION_NAME, code $VERSION_CODE)"
