#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="$ROOT_DIR/.env"
REPORTS_ROOT="$ROOT_DIR/reports/security"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="$REPORTS_ROOT/$TIMESTAMP"

if [ -t 1 ]; then
  ESCAPE="$(printf '\033')"
  COLOR_BLUE="${ESCAPE}[34m"
  COLOR_GREEN="${ESCAPE}[32m"
  COLOR_YELLOW="${ESCAPE}[33m"
  COLOR_RED="${ESCAPE}[31m"
  COLOR_RESET="${ESCAPE}[0m"
else
  COLOR_BLUE=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_RED=""
  COLOR_RESET=""
fi

print_header() {
  local title="$1"
  echo ""
  echo -e "${COLOR_BLUE}=========================================${COLOR_RESET}"
  echo -e "${COLOR_BLUE}${title}${COLOR_RESET}"
  echo -e "${COLOR_BLUE}=========================================${COLOR_RESET}"
  echo ""
}

print_success() {
  echo -e "${COLOR_GREEN}✔ $1${COLOR_RESET}"
}

print_warning() {
  echo -e "${COLOR_YELLOW}⚠ $1${COLOR_RESET}"
}

print_error() {
  echo -e "${COLOR_RED}✖ $1${COLOR_RESET}"
}

FAILED_STEPS=()
SKIPPED_STEPS=()
EXECUTED_STEPS=()
WARNED_STEPS=()

run_step() {
  local name="$1"
  local command="$2"
  local report_file="${3:-}"
  local warn_on_exit_one="${4:-0}"

  echo "▶ ${name}"

  set +e
  if [[ -n "$report_file" ]]; then
    eval "$command" | tee "$report_file"
  else
    eval "$command"
  fi
  local exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    print_success "$name completed"
    EXECUTED_STEPS+=("$name")
  elif [[ "$warn_on_exit_one" == "1" && $exit_code -eq 1 && $CI_MODE -eq 0 ]]; then
    local report_hint=""
    if [[ -n "$report_file" ]]; then
      report_hint=" (see ${report_file#"$ROOT_DIR"/})"
    else
      report_hint=" (see reports: ${REPORT_DIR#"$ROOT_DIR"/})"
    fi
    print_warning "$name found potential vulnerabilities${report_hint}"
    WARNED_STEPS+=("$name")
  else
    print_error "$name failed (exit code $exit_code)"
    FAILED_STEPS+=("$name")
  fi

  echo ""
}

skip_step() {
  local name="$1"
  local reason="$2"
  print_warning "$name skipped: $reason"
  SKIPPED_STEPS+=("$name")
  echo ""
}

usage() {
  cat <<'EOF'
Usage: ./scripts/security-tests.sh [options]

Options:
  --profile <quick|full|custom>   Choose execution profile (asks interactively by default)
  --ci                            Non-interactive CI mode (defaults to full profile)
  --allow-fail                    Always exit with 0 even if steps fail
  -h, --help                      Show this message
EOF
}

CI_MODE=0
ALLOW_FAILURES=0
PROFILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      shift
      PROFILE="${1:-}"
      ;;
    --ci)
      CI_MODE=1
      PROFILE="${PROFILE:-full}"
      ;;
    --allow-fail)
      ALLOW_FAILURES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      print_error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift || true
done

detect_backends() {
  local detected=()
  if [[ -f "$ROOT_DIR/backends/php/composer.json" ]]; then
    detected+=("php")
  fi
  if [[ -f "$ROOT_DIR/backends/python/api/manage.py" ]]; then
    detected+=("python")
  fi
  if [[ -f "$ROOT_DIR/backends/node/api/package.json" ]]; then
    detected+=("node")
  fi
  if [[ -f "$ROOT_DIR/frontend/package.json" ]]; then
    detected+=("frontend")
  fi
  echo "${detected[*]}"
}

ask_yes_no() {
  local prompt="$1"
  local default_answer="${2:-y}"
  local answer

  read -r -p "$prompt [$default_answer]: " answer
  answer="${answer:-$default_answer}"

  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "1"
  else
    echo "0"
  fi
}

if [[ -z "$PROFILE" && $CI_MODE -eq 0 ]]; then
  print_header "🛡 Select security profile"
  echo "1) Quick — dependency audit + Semgrep"
  echo "2) Full — quick profile + static analysis + Gitleaks + Trivy"
  echo "3) Custom — configure manually"
  echo ""
  read -r -p "Your choice [1]: " selected_profile
  selected_profile="${selected_profile:-1}"
  case "$selected_profile" in
    1) PROFILE="quick" ;;
    2) PROFILE="full" ;;
    3) PROFILE="custom" ;;
    *) PROFILE="quick" ;;
  esac
fi

if [[ -z "$PROFILE" ]]; then
  PROFILE="quick"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env file not found. Run make dev-init or create .env first."
  exit 1
fi

mkdir -p "$REPORT_DIR"

RUN_DEP_AUDIT=1
RUN_STATIC=0
RUN_SEMGREP=1
RUN_GITLEAKS=0
RUN_TRIVY=0

if [[ "$PROFILE" == "full" ]]; then
  RUN_STATIC=1
  RUN_GITLEAKS=1
  RUN_TRIVY=1
elif [[ "$PROFILE" == "custom" ]]; then
  RUN_DEP_AUDIT="$(ask_yes_no 'Run dependency audit?' 'y')"
  RUN_STATIC="$(ask_yes_no 'Run static analyzers?' 'y')"
  RUN_SEMGREP="$(ask_yes_no 'Run Semgrep OWASP Top 10?' 'y')"
  RUN_GITLEAKS="$(ask_yes_no 'Run Gitleaks (secrets scan)?' 'n')"
  RUN_TRIVY="$(ask_yes_no 'Run Trivy (vuln/config/secret)?' 'n')"
elif [[ "$PROFILE" != "quick" ]]; then
  print_error "Unknown profile: $PROFILE"
  exit 1
fi

print_header "📁 Run configuration"
echo "CI mode: $CI_MODE"
echo "Profile: $PROFILE"
echo "Reports directory: $REPORT_DIR"
echo ""

IFS=' ' read -r -a ACTIVE_TARGETS <<< "$(detect_backends)"

if [[ ${#ACTIVE_TARGETS[@]} -eq 0 ]]; then
  print_warning "No backend/frontend projects detected. Check repo structure."
fi

backend_available() {
  local target="$1"
  for item in "${ACTIVE_TARGETS[@]}"; do
    if [[ "$item" == "$target" ]]; then
      return 0
    fi
  done
  return 1
}

php_dependency_audit() {
  if ! backend_available "php"; then
    skip_step "PHP composer audit" "backends/php missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=php-cli docker compose --env-file \"$ENV_FILE\" run --rm --workdir /var/www php-cli sh -c 'composer audit --locked --format=json'"
  run_step "PHP composer audit" "$cmd" "$REPORT_DIR/php-composer.json" 1
}

php_static_analysis() {
  if ! backend_available "php"; then
    skip_step "PHP phpstan" "backends/php missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=php-cli docker compose --env-file \"$ENV_FILE\" run --rm --workdir /var/www php-cli sh -c 'composer install --no-interaction >/tmp/composer.log 2>&1 && vendor/bin/phpstan analyse --memory-limit=2G -c phpstan.dist.neon --error-format=json'"
  run_step "PHP phpstan security pass" "$cmd" "$REPORT_DIR/php-phpstan.json"
}

python_dependency_audit() {
  if ! backend_available "python"; then
    skip_step "Python pip-audit" "backends/python missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=python docker compose --env-file \"$ENV_FILE\" run --rm --workdir /var/www/api api-python sh -c 'pip install --no-cache-dir pip-audit >/tmp/pip-audit-install.log 2>&1 && pip-audit -r requirements.txt --format json'"
  run_step "Python pip-audit" "$cmd" "$REPORT_DIR/python-pip-audit.json" 1
}

python_static_analysis() {
  if ! backend_available "python"; then
    skip_step "Python bandit" "backends/python missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=python docker compose --env-file \"$ENV_FILE\" run --rm --workdir /var/www/api api-python sh -c 'pip install --no-cache-dir bandit >/tmp/bandit-install.log 2>&1 && bandit -r main -f json'"
  run_step "Python bandit scan" "$cmd" "$REPORT_DIR/python-bandit.json"
}

node_dependency_audit() {
  if ! backend_available "node"; then
    skip_step "Node.js pnpm audit" "backends/node missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=node docker compose --env-file \"$ENV_FILE\" run --rm --workdir /app api-node sh -c 'pnpm install --frozen-lockfile >/tmp/pnpm-install.log 2>&1 && pnpm audit --prod --json'"
  run_step "Node.js pnpm audit" "$cmd" "$REPORT_DIR/node-pnpm-audit.json" 1
}

node_static_analysis() {
  if ! backend_available "node"; then
    skip_step "Node.js eslint" "backends/node missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=node docker compose --env-file \"$ENV_FILE\" run --rm --workdir /app api-node sh -c 'pnpm install --frozen-lockfile >/tmp/pnpm-install.log 2>&1 && npx eslint server.js utils --format json'"
  run_step "Node.js eslint security pass" "$cmd" "$REPORT_DIR/node-eslint.json"
}

frontend_dependency_audit() {
  if ! backend_available "frontend"; then
    skip_step "Frontend pnpm audit" "frontend folder missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=frontend docker compose --env-file \"$ENV_FILE\" run --rm --workdir /app frontend sh -c 'pnpm install --frozen-lockfile >/tmp/pnpm-install.log 2>&1 && pnpm audit --prod --json'"
  run_step "Frontend pnpm audit" "$cmd" "$REPORT_DIR/frontend-pnpm-audit.json" 1
}

frontend_static_analysis() {
  if ! backend_available "frontend"; then
    skip_step "Frontend eslint" "frontend folder missing"
    return
  fi

  local cmd="COMPOSE_PROFILES=frontend docker compose --env-file \"$ENV_FILE\" run --rm --workdir /app frontend sh -c 'pnpm install --frozen-lockfile >/tmp/pnpm-install.log 2>&1 && pnpm run lint -- --format json'"
  run_step "Frontend eslint security pass" "$cmd" "$REPORT_DIR/frontend-eslint.json"
}

semgrep_scan() {
  local cmd="docker run --rm -v \"$ROOT_DIR\":/project returntocorp/semgrep:1.81.0 semgrep --config p/owasp-top-ten --json /project"
  run_step "Semgrep OWASP Top 10" "$cmd" "$REPORT_DIR/semgrep.json" 1
}

gitleaks_scan() {
  local cmd="docker run --rm -v \"$ROOT_DIR\":/repo zricethezav/gitleaks:latest detect --source=/repo --report-format json --report-path -"
  run_step "Gitleaks secret scan" "$cmd" "$REPORT_DIR/gitleaks.json" 1
}

trivy_scan() {
  local cmd="docker run --rm -v \"$ROOT_DIR\":/work aquasec/trivy:0.53.0 fs /work --security-checks vuln,secret --skip-dirs /work/logs --format json"
  run_step "Trivy filesystem scan" "$cmd" "$REPORT_DIR/trivy.json" 1
}

declare -a QUEUE=()

if [[ "$RUN_DEP_AUDIT" == "1" ]]; then
  QUEUE+=("php_dependency_audit")
  QUEUE+=("python_dependency_audit")
  QUEUE+=("node_dependency_audit")
  QUEUE+=("frontend_dependency_audit")
fi

if [[ "$RUN_STATIC" == "1" ]]; then
  QUEUE+=("php_static_analysis")
  QUEUE+=("python_static_analysis")
  QUEUE+=("node_static_analysis")
  QUEUE+=("frontend_static_analysis")
fi

if [[ "$RUN_SEMGREP" == "1" ]]; then
  QUEUE+=("semgrep_scan")
fi

if [[ "$RUN_GITLEAKS" == "1" ]]; then
  QUEUE+=("gitleaks_scan")
fi

if [[ "$RUN_TRIVY" == "1" ]]; then
  QUEUE+=("trivy_scan")
fi

if [[ ${#QUEUE[@]} -eq 0 ]]; then
  print_warning "Не выбрано ни одного шага. Завершение."
  exit 0
fi

print_header "🚀 Running security tests"

for step in "${QUEUE[@]}"; do
  "$step"
done

print_header "📊 Summary"
echo "Total steps: ${#QUEUE[@]}"
echo "Success: ${#EXECUTED_STEPS[@]}"
echo "Warnings: ${#WARNED_STEPS[@]}"
echo "Failures: ${#FAILED_STEPS[@]}"
echo "Skipped: ${#SKIPPED_STEPS[@]}"
echo ""
echo "Reports: $REPORT_DIR"

if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
  echo ""
  print_error "Failed steps: ${FAILED_STEPS[*]}"
  if [[ "$ALLOW_FAILURES" -eq 1 ]]; then
    print_warning "allow-fail enabled, exiting with code 0."
    exit 0
  fi
  exit 2
fi

if [[ ${#WARNED_STEPS[@]} -gt 0 ]]; then
  echo ""
  print_warning "Steps with findings: ${WARNED_STEPS[*]}"
  if [[ "$CI_MODE" -eq 1 && "$ALLOW_FAILURES" -ne 1 ]]; then
    print_error "CI mode requires fixing warnings."
    exit 2
  fi
fi

print_success "Security tests finished"
exit 0

