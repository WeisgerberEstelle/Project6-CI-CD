#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/test-results"
EXIT_CODE=0

# Clean previous test results
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

echo "=== Running tests for all projects ==="

for dir in "$SCRIPT_DIR"/*/; do
  project_name="$(basename "$dir")"

  # Detect Node/Angular project
  if [ -f "$dir/package.json" ]; then
    echo ""
    echo "--- [$project_name] Node/Angular project detected ---"

    # Check dependencies
    if ! command -v node &>/dev/null; then
      echo "ERROR: node is not installed"
      EXIT_CODE=1
      continue
    fi
    if ! command -v npm &>/dev/null; then
      echo "ERROR: npm is not installed"
      EXIT_CODE=1
      continue
    fi
    if [ ! -d "$dir/node_modules" ]; then
      echo "Installing dependencies..."
      (cd "$dir" && npm ci)
    fi

    # Run tests
    echo "Running Angular tests..."
    if (cd "$dir" && npm test); then
      echo "[$project_name] Tests passed"
    else
      echo "[$project_name] Tests FAILED"
      EXIT_CODE=1
    fi

    # Copy JUnit XML reports
    if [ -d "$dir/reports" ]; then
      mkdir -p "$RESULTS_DIR/$project_name"
      cp "$dir"/reports/*.xml "$RESULTS_DIR/$project_name/" 2>/dev/null || true
      echo "[$project_name] Reports copied to test-results/$project_name/"
    fi

  # Detect Gradle/Java project
  elif [ -f "$dir/gradlew" ]; then
    echo ""
    echo "--- [$project_name] Gradle/Java project detected ---"

    # Check dependencies
    if ! command -v java &>/dev/null; then
      echo "ERROR: java is not installed"
      EXIT_CODE=1
      continue
    fi
    if [ ! -x "$dir/gradlew" ]; then
      chmod +x "$dir/gradlew"
    fi

    # Run tests
    echo "Running Gradle tests..."
    if (cd "$dir" && ./gradlew clean test); then
      echo "[$project_name] Tests passed"
    else
      echo "[$project_name] Tests FAILED"
      EXIT_CODE=1
    fi

    # Copy JUnit XML reports
    if [ -d "$dir/build/test-results/test" ]; then
      mkdir -p "$RESULTS_DIR/$project_name"
      cp "$dir"/build/test-results/test/*.xml "$RESULTS_DIR/$project_name/" 2>/dev/null || true
      echo "[$project_name] Reports copied to test-results/$project_name/"
    fi
  fi
done

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "=== All tests passed ==="
else
  echo "=== Some tests FAILED ==="
fi

exit $EXIT_CODE
