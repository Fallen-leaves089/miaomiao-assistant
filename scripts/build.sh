#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
OUTPUT_DIR="${2:-$REPO_ROOT/dist}"
APKTOOL_VERSION="${APKTOOL_VERSION:-2.10.0}"
APKTOOL_SHA256="${APKTOOL_SHA256:-c0350abbab5314248dfe2ee0c907def4edd14f6faef1f5d372d3d4abd28f0431}"
BUILD_DIR="${MIAOMIAO_BUILD_DIR:-$HOME/.cache/miaomiao-assistant-build}"
JAR_DIR="${MIAOMIAO_APKTOOL_DIR:-$HOME/.cache/apktool}"
JAR_PATH="${APKTOOL_JAR:-$JAR_DIR/apktool_${APKTOOL_VERSION}.jar}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1" >&2
    exit 1
  }
}

need_cmd git
need_cmd java

if [[ ! -d "$REPO_ROOT/MiaoMiaoAssistant" ]]; then
  echo "未找到 MiaoMiaoAssistant: $REPO_ROOT" >&2
  exit 1
fi

if [[ -z "$BUILD_DIR" || "$BUILD_DIR" == "/" ]]; then
  echo "拒绝使用不安全的构建目录: $BUILD_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$JAR_DIR"

if [[ -z "${APKTOOL_JAR:-}" && ! -f "$JAR_PATH" ]]; then
  need_cmd curl
  need_cmd sha256sum
  echo "下载 apktool $APKTOOL_VERSION ..."
  tmp="$JAR_PATH.part"
  curl -fL --retry 3 --connect-timeout 20 -o "$tmp" \
    "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar"
  echo "$APKTOOL_SHA256  $tmp" | sha256sum -c -
  mv "$tmp" "$JAR_PATH"
fi

if [[ -n "${APKTOOL_JAR:-}" && ! -f "$JAR_PATH" ]]; then
  echo "APKTOOL_JAR 不存在: $JAR_PATH" >&2
  exit 1
fi

if [[ -d "$BUILD_DIR" ]]; then
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$(dirname "$BUILD_DIR")"

SOURCE_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
git clone --quiet "$REPO_ROOT" "$BUILD_DIR"
cd "$BUILD_DIR"

VERSION="$(awk '/^[[:space:]]+versionName:/ {print $2; exit}' MiaoMiaoAssistant/apktool.yml | tr -d '\r')"
if [[ -z "$VERSION" ]]; then
  echo "无法从 MiaoMiaoAssistant/apktool.yml 读取 versionName" >&2
  exit 1
fi

OUT_APK="$OUTPUT_DIR/miaomiao-assistant-${VERSION}-unsigned.apk"
rm -f "$OUT_APK"

echo "构建 $VERSION（apktool $APKTOOL_VERSION，源码 $SOURCE_COMMIT）..."
java -jar "$JAR_PATH" b MiaoMiaoAssistant -o "$OUT_APK"

echo "unsigned_apk=$OUT_APK"
echo "version=$VERSION"
echo "source_commit=$SOURCE_COMMIT"
