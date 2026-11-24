#!/usr/bin/env bash
# Быстрая проверка синтаксиса Swift-файлов без Xcode.
# Работает в Linux-контейнере (GitHub Codespaces).
# Важно: проверяется только синтаксис, импорты и типы не резолвятся.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc не найден. Нужен Swift (см. .devcontainer/devcontainer.json)." >&2
  exit 1
fi

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find Sources -name '*.swift' -print0)

if [ ${#files[@]} -eq 0 ]; then
  echo "В папке Sources нет .swift файлов." >&2
  exit 1
fi

echo "Проверяю синтаксис ${#files[@]} файл(ов)..."
swiftc -parse "${files[@]}"
echo "OK: синтаксис в порядке"
