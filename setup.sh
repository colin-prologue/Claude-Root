#!/usr/bin/env bash
set -euo pipefail

# Spec-Kit Setup Script
# Integrates the Spec-Kit template into an existing or new repository.
# Safe for existing projects — never overwrites files without asking.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/colin-prologue/Claude-Root/main/setup.sh | bash
#   ./setup.sh                          # Run locally
#   ./setup.sh --force                  # Overwrite existing template files (not CLAUDE.md)
#   ./setup.sh --repo user/repo         # Use a different template repo
#   ./setup.sh --ref branch-name        # Use a specific branch/tag

REPO="${SPECKIT_REPO:-colin-prologue/Claude-Root}"
REF="${SPECKIT_REF:-main}"
FORCE=false
VERBOSE=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force) FORCE=true; shift ;;
    --repo) REPO="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    --dry-run) DRY_RUN=true; VERBOSE=true; shift ;;
    -h|--help)
      echo "Usage: setup.sh [OPTIONS]"
      echo ""
      echo "Integrate Spec-Kit template into the current directory."
      echo ""
      echo "Options:"
      echo "  --force       Overwrite existing template files (never overwrites CLAUDE.md)"
      echo "  --repo REPO   GitHub repo to fetch from (default: colin-prologue/Claude-Root)"
      echo "  --ref REF     Branch or tag to fetch (default: main)"
      echo "  --verbose     Show detailed progress"
      echo "  --dry-run     Show what would be done without making changes"
      echo "  -h, --help    Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Colors (if terminal supports them)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  GREEN='' YELLOW='' RED='' BLUE='' NC=''
fi

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }
info() { [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[i]${NC} $1" || true; }

# Track what we do for the summary
CREATED=()
SKIPPED=()
UPDATED=()

# Copy a file from the temp clone to the target, respecting --force
copy_file() {
  local src="$1"
  local dest="$2"
  local category="${3:-template}"  # template, config, or protected

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -f "$dest" ]]; then
      if [[ "$FORCE" == true && "$category" != "protected" ]]; then
        echo "  [dry-run] Would overwrite: $dest"
      else
        echo "  [dry-run] Would skip (exists): $dest"
      fi
    else
      echo "  [dry-run] Would create: $dest"
    fi
    return
  fi

  # Create parent directory
  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]]; then
    if [[ "$category" == "protected" ]]; then
      # Never overwrite protected files (CLAUDE.md, constitution.md)
      SKIPPED+=("$dest (protected — merge manually if needed)")
      info "Skipped (protected): $dest"
      return
    elif [[ "$FORCE" == true ]]; then
      cp "$src" "$dest"
      UPDATED+=("$dest")
      info "Updated: $dest"
      return
    else
      SKIPPED+=("$dest (exists — use --force to overwrite)")
      info "Skipped (exists): $dest"
      return
    fi
  fi

  cp "$src" "$dest"
  CREATED+=("$dest")
  info "Created: $dest"
}

# --- Main ---

echo ""
echo "  Spec-Kit Setup"
echo "  =============="
echo "  Source: $REPO@$REF"
echo ""

# Check we're in a reasonable directory
if [[ ! -d ".git" && ! -f "package.json" && ! -f "pyproject.toml" && ! -f "go.mod" && ! -f "Cargo.toml" && ! -f "Gemfile" && ! -f "Makefile" ]]; then
  warn "This doesn't look like a project root (no .git, package.json, etc.)"
  read -rp "  Continue anyway? [y/N] " confirm
  [[ "$confirm" =~ ^[yY] ]] || exit 0
fi

# Create temp directory for clone
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log "Fetching template from $REPO@$REF..."

# Try git clone (works for private repos if user has access)
if command -v git &>/dev/null; then
  git clone --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$TMPDIR/template" 2>/dev/null \
    || git clone --depth 1 --branch "$REF" "git@github.com:$REPO.git" "$TMPDIR/template" 2>/dev/null \
    || { err "Failed to clone $REPO. Check the repo exists and you have access."; exit 1; }
else
  err "git is required. Install git and try again."
  exit 1
fi

TMPL="$TMPDIR/template"

log "Installing Spec-Kit files..."

# --- Commands (always copy, these are the core product) ---
for f in "$TMPL"/.claude/commands/speckit.*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_file "$f" ".claude/commands/$name" "template"
done

# --- Agents ---
for f in "$TMPL"/.claude/agents/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_file "$f" ".claude/agents/$name" "template"
done

# --- Rules ---
for f in "$TMPL"/.claude/rules/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_file "$f" ".claude/rules/$name" "template"
done

# --- Templates ---
for f in "$TMPL"/.specify/templates/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_file "$f" ".specify/templates/$name" "template"
done

# --- Scripts ---
for f in "$TMPL"/.specify/scripts/bash/*.sh; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_file "$f" ".specify/scripts/bash/$name" "template"
  [[ "$DRY_RUN" != true ]] && chmod +x ".specify/scripts/bash/$name"
done

# --- Init options ---
if [[ -f "$TMPL/.specify/init-options.json" ]]; then
  copy_file "$TMPL/.specify/init-options.json" ".specify/init-options.json" "template"
fi

# --- Protected files (never overwrite) ---
if [[ -f "$TMPL/CLAUDE.md" ]]; then
  copy_file "$TMPL/CLAUDE.md" "CLAUDE.md" "protected"
fi

if [[ -f "$TMPL/.specify/memory/constitution.md" ]]; then
  copy_file "$TMPL/.specify/templates/constitution-template.md" ".specify/memory/constitution.md" "protected"
fi

# --- Settings (local, gitignored) ---
if [[ ! -f ".claude/settings.local.json" ]]; then
  copy_file "$TMPL/.claude/settings.local.json" ".claude/settings.local.json" "config"
fi

# --- Directories (ensure they exist) ---
if [[ "$DRY_RUN" != true ]]; then
  mkdir -p specs docs src tests .specify/memory
fi

# --- Gitignore (append if needed) ---
if [[ "$DRY_RUN" != true ]]; then
  if [[ -f ".gitignore" ]]; then
    if ! grep -q "settings.local.json" ".gitignore" 2>/dev/null; then
      echo "" >> .gitignore
      echo "# Spec-Kit local settings" >> .gitignore
      echo ".claude/settings.local.json" >> .gitignore
      log "Appended Spec-Kit entries to .gitignore"
    fi
  else
    cp "$TMPL/.gitignore" ".gitignore"
    CREATED+=(".gitignore")
  fi
fi

# --- Summary ---
echo ""
echo "  Setup Summary"
echo "  ============="

if [[ ${#CREATED[@]} -gt 0 ]]; then
  log "Created ${#CREATED[@]} files:"
  for f in "${CREATED[@]}"; do echo "    $f"; done
fi

if [[ ${#UPDATED[@]} -gt 0 ]]; then
  warn "Updated ${#UPDATED[@]} files:"
  for f in "${UPDATED[@]}"; do echo "    $f"; done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  info "Skipped ${#SKIPPED[@]} files:"
  for f in "${SKIPPED[@]}"; do echo "    $f"; done
fi

echo ""
log "Spec-Kit installed. Next steps:"
echo ""
echo "  1. Run /speckit.constitution to set up project governance"
echo "  2. Update CLAUDE.md with your project name, stack, and commands"
echo "  3. Run /speckit.brainstorm if you have a vague idea to explore"
echo "  4. Run /speckit.specify to start your first feature"
echo ""
