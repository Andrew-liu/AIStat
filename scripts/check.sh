#!/usr/bin/env bash
# AIStat 一键校验：编译 + 单元测试。
# 每次开发完成后运行，尽早发现问题。
#
# 用法：
#   ./scripts/check.sh            # 编译 + 测试
#   ./scripts/check.sh build      # 仅编译
#   ./scripts/check.sh test       # 仅测试
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/AIStat.xcodeproj"
SCHEME="AIStat"
DERIVED="$ROOT_DIR/.derivedData"
MODE="${1:-all}"

cd "$ROOT_DIR"

run_build() {
  echo "==> Building ($SCHEME, Debug)"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -derivedDataPath "$DERIVED" build \
    | grep -E "error:|warning: .*Swift|BUILD" || true
}

run_test() {
  echo "==> Testing ($SCHEME)"
  set +e
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" test \
    2>&1 | tee "$DERIVED/test.log" | grep -E "Test Suite|Test Case|error:|\*\* TEST|passed|failed"
  local status=${PIPESTATUS[0]}
  set -e
  return $status
}

case "$MODE" in
  build) run_build ;;
  test)  run_test ;;
  all)   run_build && run_test ;;
  *) echo "Unknown mode: $MODE (use build|test|all)"; exit 2 ;;
esac

echo "==> check.sh done"
