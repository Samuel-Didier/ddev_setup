#!/usr/bin/env bash
set -euo pipefail

# ddev-init.sh — Initialize a DDEV project with auto-detection of type/docroot/versions.
# Usage: ddev-init.sh [options] [project-dir]
# Run from inside the project directory, or pass the path as last argument.

FORCE=0
DO_START=1
DO_INSTALL=1
DO_MIGRATE=0
DO_IMPORT=1
NAME=""
PHP_VERSION=""
DB=""
NODE_VERSION=""
DOCROOT=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [project-dir]

Options:
  --force            Remove existing .ddev before configuring
  --no-start         Do not run 'ddev start'
  --no-install       Skip dependency installation (composer/npm)
  --migrate          Run framework migrations after start (Laravel/Symfony)
  --no-import        Do not auto-import a DB dump if found
  --name NAME        Project name override
  --php VERSION      PHP version override (e.g. 8.3)
  --db TYPE:VER      Database override (e.g. mariadb:11.8, mysql:8.0, postgres:16)
  --node VERSION     Node.js version override
  --docroot PATH     Docroot override
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift;;
    --no-start) DO_START=0; shift;;
    --no-install) DO_INSTALL=0; shift;;
    --migrate) DO_MIGRATE=1; shift;;
    --no-import) DO_IMPORT=0; shift;;
    --name) NAME="$2"; shift 2;;
    --php) PHP_VERSION="$2"; shift 2;;
    --db) DB="$2"; shift 2;;
    --node) NODE_VERSION="$2"; shift 2;;
    --docroot) DOCROOT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    --) shift; break;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1;;
    *) break;;
  esac
done

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"
PROJECT_DIR="$(pwd)"
PROJECT_NAME_DEFAULT="$(basename "$PROJECT_DIR")"

# --- detection helpers ---
detect_type() {
  if [[ -f artisan ]]; then echo laravel; return; fi
  if [[ -f composer.json ]]; then
    local cj=composer.json
    grep -q '"laravel/framework"' "$cj" && { echo laravel; return; }
    grep -qE '"symfony/(framework-bundle|symfony)"' "$cj" && { echo symfony; return; }
    grep -q '"drupal/core' "$cj" && { echo drupal11; return; }
    grep -q '"typo3/cms' "$cj" && { echo typo3; return; }
    grep -q '"shopware/' "$cj" && { echo shopware6; return; }
    grep -qE '"magento/(product|framework|magento2)' "$cj" && { echo magento2; return; }
    grep -q '"cakephp/cakephp' "$cj" && { echo cakephp; return; }
    grep -qE '"codeigniter(4)?/framework' "$cj" && { echo codeigniter; return; }
    grep -q '"craftcms/cms' "$cj" && { echo craftcms; return; }
    grep -q '"silverstripe/' "$cj" && { echo silverstripe; return; }
    grep -qi 'fatfree\|bcosca/fatfree\|f3/framework' "$cj" && { echo php; return; }
    grep -qE '"johnpbloch/wordpress|roots/wordpress|wordpress/wordpress"' "$cj" && { echo wordpress; return; }
  fi
  [[ -f wp-config.php || -f wp-load.php || -d wp-content ]] && { echo wordpress; return; }
  [[ -d web/sites || -d sites/default ]] && { echo drupal11; return; }
  [[ -d typo3 || -f typo3conf/LocalConfiguration.php ]] && { echo typo3; return; }
  if [[ -f package.json && ! -f composer.json ]]; then echo generic; return; fi
  [[ -f index.php && -d lib ]] && grep -qi 'fatfree\|\$f3' index.php 2>/dev/null && { echo php; return; }
    [[ -f index.php ]] && { echo php; return; }
  [[ -f composer.json ]] && { echo php; return; }
  echo generic
}

detect_docroot() {
  local t="$1"
  case "$t" in
    laravel|symfony) echo "public";;
    drupal*) echo "web";;
    typo3) echo "public";;
    shopware6) echo "public";;
    magento2) echo "pub";;
    craftcms) echo "web";;
    *) for d in public web htdocs docroot www html; do
         if [[ -f "$d/index.php" || -f "$d/index.html" ]]; then echo "$d"; return; fi
       done
       echo "";;
  esac
}

detect_php() {
  if [[ -f composer.json ]]; then
    local v
    v=$(grep -oE '"php"[[:space:]]*:[[:space:]]*"[^"]*"' composer.json | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ -n "${v:-}" ]]; then echo "$v"; return; fi
  fi
  echo "8.4"
}

detect_node() {
  if [[ -f package.json ]]; then
    local v
    v=$(grep -oE '"node"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1 | grep -oE '[0-9]+' | head -1)
    if [[ -n "${v:-}" ]]; then echo "$v"; return; fi
  fi
  echo "24"
}

detect_db() {
  if [[ -f .env ]]; then
    local conn
    conn=$(grep -E '^DB_CONNECTION=' .env 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'" || true)
    case "$conn" in
      pgsql|postgres|postgresql) echo "postgres:16"; return;;
      mysql) echo "mysql:8.0"; return;;
      sqlite) echo "sqlite"; return;;
    esac
  fi
  echo "mariadb:11.8"
}

TYPE="$(detect_type)"
[[ -z "$DOCROOT" ]] && DOCROOT="$(detect_docroot "$TYPE")"
[[ -z "$PHP_VERSION" ]] && PHP_VERSION="$(detect_php)"
[[ -z "$NODE_VERSION" ]] && NODE_VERSION="$(detect_node)"
[[ -z "$DB" ]] && DB="$(detect_db)"
[[ -z "$NAME" ]] && NAME="$PROJECT_NAME_DEFAULT"

echo "==> Detected type: $TYPE"
echo "==> Docroot: ${DOCROOT:-.}"
echo "==> PHP: $PHP_VERSION | Node: $NODE_VERSION | DB: $DB | Name: $NAME"

if [[ -d .ddev ]]; then
  if [[ $FORCE -eq 1 ]]; then
    echo "==> Removing existing .ddev (--force)"
    rm -rf .ddev
  else
    echo "==> .ddev exists; using --update"
  fi
fi

ARGS=(--auto --project-type="$TYPE" --project-name="$NAME")
[[ -n "$DOCROOT" ]] && ARGS+=(--docroot="$DOCROOT")
if [[ "$DB" == "sqlite" ]]; then
  ARGS+=(--php-version="$PHP_VERSION" --nodejs-version="$NODE_VERSION" --omit-containers=db)
else
  ARGS+=(--php-version="$PHP_VERSION" --nodejs-version="$NODE_VERSION" --database="$DB")
fi
if [[ -d .ddev ]]; then ARGS+=(--update); fi

ddev config "${ARGS[@]}"

if [[ $DO_START -eq 1 ]]; then
  ddev start
fi

if [[ $DO_INSTALL -eq 1 && $DO_START -eq 1 ]]; then
  if [[ -f composer.json ]]; then
    echo "==> composer install"
    ddev composer install || true
  fi
  if [[ -f package.json ]]; then
    echo "==> npm install"
    ddev npm install || true
  fi
fi

# framework-specific post-setup (requires running containers)
if [[ $DO_START -eq 1 ]]; then
case "$TYPE" in
  laravel)
    if [[ -f .env.example && ! -f .env ]]; then
      ddev exec cp .env.example .env || true
    fi
    if [[ -f artisan ]]; then
      ddev exec php artisan key:generate --force >/dev/null 2>&1 || true
    fi
    if [[ $DO_MIGRATE -eq 1 ]]; then
      ddev exec php artisan migrate --force || true
    fi
    ;;
  symfony)
    if [[ $DO_MIGRATE -eq 1 && -f bin/console ]]; then
      ddev exec php bin/console doctrine:migrations:migrate -n || true
    fi
    ;;
esac
fi

# auto-import DB dump
if [[ $DO_START -eq 1 && $DO_IMPORT -eq 1 ]]; then
  DUMP=""
  for f in *.sql *.sql.gz *.dump; do
    [[ -f "$f" ]] && { DUMP="$f"; break; }
  done
  if [[ -n "$DUMP" ]]; then
    echo "==> Importing DB dump: $DUMP"
    ddev import-db --file="$DUMP" || true
  fi
fi

echo "==> Done. URL: https://${NAME}.ddev.site"
