#!/bin/bash

# Claude Universal Installer - Shared Libraries Module
# Provides common functionality to eliminate code duplication across installer modules

set -eo pipefail

# Source core utilities and modules
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config-manager.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/rollback.sh"

# Shared installation utilities
declare -A INSTALLATION_REGISTRY=()
declare -A SHARED_FUNCTIONS=()

# Register installation for tracking
register_installation() {
    local installation_type="$1"
    local installation_path="$2"
    local metadata="$3"

    INSTALLATION_REGISTRY["$installation_type"]="$installation_path"
    log "Registered installation: $installation_type -> $installation_path"

    if [[ -n "$metadata" ]]; then
        log "Installation metadata: $metadata"
    fi
}

# Get installation path by type
get_installation_path() {
    local installation_type="$1"
    echo "${INSTALLATION_REGISTRY[$installation_type]:-}"
}

# Common validation functions
validate_system_requirements() {
    local requirements="$1"  # Comma-separated list of requirements
    local strict_mode="${2:-false}"

    log "Validating system requirements: $requirements"

    local missing_requirements=()
    local warnings=()

    IFS=',' read -ra REQUIREMENT_ARRAY <<< "$requirements"
    for requirement in "${REQUIREMENT_ARRAY[@]}"; do
        requirement=$(echo "$requirement" | xargs)  # Trim whitespace

        case "$requirement" in
            "curl"|"wget")
                if ! command_exists "$requirement"; then
                    missing_requirements+=("$requirement (for downloads)")
                fi
                ;;
            "jq")
                if ! command_exists "jq"; then
                    missing_requirements+=("jq (for JSON processing)")
                fi
                ;;
            "python3")
                if ! command_exists "python3"; then
                    missing_requirements+=("python3")
                fi
                ;;
            "node")
                if ! command_exists "node"; then
                    missing_requirements+=("node")
                fi
                ;;
            "npm")
                if ! command_exists "npm"; then
                    missing_requirements+=("npm")
                fi
                ;;
            "docker")
                if ! command_exists "docker"; then
                    warnings+=("docker (optional, for Docker integration)")
                fi
                ;;
            "git")
                if ! command_exists "git"; then
                    warnings+=("git (optional, for version control)")
                fi
                ;;
            *)
                if ! command_exists "$requirement"; then
                    missing_requirements+=("$requirement")
                fi
                ;;
        esac
    done

    # Report results
    if [[ ${#missing_requirements[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_requirements[*]}"
        echo ""
        echo "Installation suggestions:"
        for req in "${missing_requirements[@]}"; do
            case "$req" in
                "curl"|"wget")
                    echo "  • $req: Usually pre-installed on most systems"
                    echo "    Ubuntu/Debian: sudo apt install $req"
                    echo "    macOS: brew install $req"
                    ;;
                "jq")
                    echo "  • jq: JSON processor"
                    echo "    Ubuntu/Debian: sudo apt install jq"
                    echo "    macOS: brew install jq"
                    ;;
                "python3")
                    echo "  • python3: Python interpreter"
                    echo "    Ubuntu/Debian: sudo apt install python3 python3-pip python3-venv"
                    echo "    macOS: brew install python3"
                    ;;
                "node"|"npm")
                    echo "  • Node.js/npm: JavaScript runtime"
                    echo "    Ubuntu/Debian: sudo apt install nodejs npm"
                    echo "    macOS: brew install node"
                    echo "    Official: https://nodejs.org"
                    ;;
            esac
        done

        if [[ "$strict_mode" == "true" ]]; then
            return 1
        fi
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        warn "Optional tools not found: ${warnings[*]}"
        echo "These tools are not required but may enhance functionality"
    fi

    success "System requirements validation completed"
    return 0
}

# Shared directory creation with error handling
create_shared_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    local description="${3:-directory}"

    if [[ -z "$dir_path" ]]; then
        error "Directory path cannot be empty"
        return 1
    fi

    log "Creating $description: $dir_path"

    if [[ -d "$dir_path" ]]; then
        log "Directory already exists: $dir_path"
        return 0
    fi

    # Create parent directories if needed
    local parent_dir
    parent_dir="$(dirname "$dir_path")"
    if [[ ! -d "$parent_dir" ]]; then
        if ! mkdir -p "$parent_dir"; then
            error "Failed to create parent directory: $parent_dir"
            return 1
        fi
    fi

    # Create the directory
    if mkdir -p "$dir_path"; then
        # Set permissions if specified
        if [[ -n "$permissions" ]]; then
            chmod "$permissions" "$dir_path" 2>/dev/null || true
        fi
        success "Created $description: $dir_path"
        return 0
    else
        error "Failed to create $description: $dir_path"
        return 1
    fi
}

# Shared file operations with rollback support
create_shared_file() {
    local file_path="$1"
    local content="$2"
    local permissions="${3:-644}"
    local description="${4:-file}"
    local rollback_point_id="${5:-}"

    if [[ -z "$file_path" ]]; then
        error "File path cannot be empty"
        return 1
    fi

    log "Creating $description: $file_path"

    # Create parent directory if needed
    local parent_dir
    parent_dir="$(dirname "$file_path")"
    create_shared_directory "$parent_dir" "755" "parent directory for $description"

    # Create rollback point if specified
    if [[ -n "$rollback_point_id" ]]; then
        backup_file_for_rollback "$file_path" "$rollback_point_id" "Backup before creating $description"
    fi

    # Write file
    if echo "$content" > "$file_path"; then
        # Set permissions
        chmod "$permissions" "$file_path" 2>/dev/null || true
        success "Created $description: $file_path"
        return 0
    else
        error "Failed to create $description: $file_path"
        return 1
    fi
}

# Shared download function with validation
download_shared_file() {
    local url="$1"
    local output_path="$2"
    local expected_checksum="${3:-}"
    local description="${4:-file}"
    local algorithm="${5:-sha256}"
    local max_attempts="${6:-3}"

    log "Downloading $description from: $url"

    # Validate URL
    if ! validate_url "$url" "download URL"; then
        return 1
    fi

    # Create output directory
    local output_dir
    output_dir="$(dirname "$output_path")"
    create_shared_directory "$output_dir" "755" "download directory for $description"

    # Download with checksum validation
    if [[ -n "$expected_checksum" ]]; then
        download_with_checksum_validation "$url" "$output_path" "$expected_checksum" "$algorithm" "$max_attempts"
    else
        download_with_retry "$url" "$output_path" "$max_attempts" "$description"
    fi
}

# Common binary installation pattern
install_binary() {
    local binary_name="$1"
    local install_dir="$2"
    local download_url="$3"
    local expected_checksum="${4:-}"
    local description="${5:-$binary_name binary}"
    local rollback_point_id="$6"

    local binary_path="$install_dir/$binary_name"

    log "Installing $description"

    # Create installation directory
    create_shared_directory "$install_dir" "755" "installation directory for $description"

    # Create rollback point for existing binary
    if [[ -f "$binary_path" ]]; then
        backup_file_for_rollback "$binary_path" "$rollback_point_id" "Backup existing $description"
    fi

    # Download binary
    if download_shared_file "$download_url" "$binary_path" "$expected_checksum" "$description"; then
        # Make executable
        chmod +x "$binary_path"
        success "$description installed successfully: $binary_path"

        # Register installation
        register_installation "$binary_name" "$binary_path" "version: $(get_latest_version_for_binary "$binary_name")"

        return 0
    else
        error "Failed to install $description"
        return 1
    fi
}

# Get version information for binary (placeholder)
get_latest_version_for_binary() {
    local binary_name="$1"
    echo "latest"
}

# Common project template creation
create_project_template() {
    local template_name="$1"
    local template_dir="$2"
    local template_content="$3"
    local directories=("${@:4}")

    log "Creating project template: $template_name"

    # Create template directory
    create_shared_directory "$template_dir" "755" "project template directory"

    # Create subdirectories
    for dir in "${directories[@]}"; do
        create_shared_directory "$template_dir/$dir" "755" "template subdirectory: $dir"
    done

    # Create template files
    if [[ -n "$template_content" ]]; then
        while IFS= read -r file_info; do
            local file_path="${file_info%%:*}"
            local file_content="${file_info#*:}"

            if [[ -n "$file_path" && -n "$file_content" ]]; then
                create_shared_file "$template_dir/$file_path" "$file_content" "644" "template file: $file_path"
            fi
        done <<< "$template_content"
    fi

    success "Project template created: $template_name"
}

# Common environment file creation
create_environment_file() {
    local env_file="$1"
    local env_vars="$2"
    local description="${3:-environment file}"

    log "Creating $description: $env_file"

    local env_content="# $description\n# Generated by Claude Universal Installer\n\n"

    # Add environment variables
    while IFS= read -r env_var; do
        if [[ -n "$env_var" ]]; then
            env_content+="export $env_var\n"
        fi
    done <<< "$env_vars"

    create_shared_file "$env_file" "$env_content" "600" "$description"
}

# Common package.json creation for Node.js projects
create_package_json() {
    local package_file="$1"
    local project_name="$2"
    local description="${3:-package.json}"
    local dependencies=("${@:4}")
    local dev_dependencies=("${@:5}")

    log "Creating $description: $package_file"

    local package_json='{
  "name": "'$project_name'",
  "version": "1.0.0",
  "description": "'$description'",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "tsx src/index.ts",
    "test": "jest",
    "lint": "eslint src/**/*.ts",
    "clean": "rimraf dist"
  },
  "keywords": ["claude", "anthropic", "ai", "agent"],
  "author": "Claude Agent Developer",
  "license": "MIT",
  "dependencies": {},'

    # Add dependencies
    if [[ ${#dependencies[@]} -gt 0 ]]; then
        package_json+='"dependencies": {'
        for dep in "${dependencies[@]}"; do
            package_json+="\"$dep\": \"latest\","
        done
        package_json+='},'
    fi

    # Add dev dependencies
    if [[ ${#dev_dependencies[@]} -gt 0 ]]; then
        package_json+='"devDependencies": {'
        for dep in "${dev_dependencies[@]}"; do
            package_json+="\"$dep\": \"latest\","
        done
        package_json+='},'
    fi

    package_json+='
}'

    create_shared_file "$package_file" "$package_json" "644" "$description"
}

# Common requirements.txt creation for Python projects
create_requirements_txt() {
    local requirements_file="$1"
    local description="${2:-requirements.txt}"
    local packages=("${@:3}")

    log "Creating $description: $requirements_file"

    local requirements_content="# $description\n# Generated by Claude Universal Installer\n\n"

    # Add packages
    for package in "${packages[@]}"; do
        requirements_content+="$package\n"
    done

    create_shared_file "$requirements_file" "$requirements_content" "644" "$description"
}

# Common .gitignore creation
create_gitignore() {
    local gitignore_file="$1"
    local project_type="${2:-general}"

    log "Creating .gitignore file for: $project_type"

    local gitignore_content="# Generated by Claude Universal Installer\n\n"

    case "$project_type" in
        "node"|"typescript")
            gitignore_content+='# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build outputs
dist/
build/
*.tsbuildinfo

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
*.lcov

# nyc test coverage
.nyc_output

# Dependency directories
.npm
.eslintcache

# Optional npm cache directory
.npm

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity
'
            ;;
        "python")
            gitignore_content+='# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
#  Usually these files are written by a python script from a template
#  before PyInstaller builds the exe, so as to inject date/other infos into it.
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
target/

# Jupyter Notebook
.ipynb_check_points

# IPython
profile_default/
ipython_config.py

# pyenv
.python-version

# celery beat schedule file
celerybeat-schedule

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/
            ;;
        "general")
            gitignore_content+='# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# Logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Temporary files
*.tmp
*.temp
'
            ;;
    esac

    gitignore_content+='
# Claude Universal Installer specific
.claude-universal/
claude-universal-*.log
*.backup
'

    create_shared_file "$gitignore_file" "$gitignore_content" "644" ".gitignore file"
}

# Common README.md creation
create_readme() {
    local readme_file="$1"
    local project_name="$2"
    local project_description="$3"
    local usage_instructions="$4"
    local features=("${@:5}")

    log "Creating README.md for: $project_name"

    local readme_content="# $project_name

$project_description

## Quick Start

$usage_instructions

## Features
"

    # Add features
    for feature in "${features[@]}"; do
        readme_content+="• $feature\n"
    done

    readme_content+='
## License

MIT License

## Support

For support and questions, please refer to the project documentation.
'

    create_shared_file "$readme_file" "$readme_content" "644" "README.md file"
}

# Common validation functions
validate_project_name() {
    local project_name="$1"
    local pattern="^[a-zA-Z][a-zA-Z0-9_-]*$"

    if [[ -z "$project_name" ]]; then
        error "Project name cannot be empty"
        return 1
    fi

    if [[ ! "$project_name" =~ $pattern ]]; then
        error "Invalid project name: $project_name"
        echo "Project names must:"
        echo "  • Start with a letter"
        echo "  • Contain only letters, numbers, hyphens, and underscores"
        echo "  • Be at least 2 characters long"
        return 1
    fi

    return 0
}

validate_file_path() {
    local file_path="$1"
    local allow_absolute="${2:-true}"

    if [[ -z "$file_path" ]]; then
        error "File path cannot be empty"
        return 1
    fi

    # Check for directory traversal
    if [[ "$file_path" == *"../"* || "$file_path" == *"~/"* ]]; then
        error "File path contains potentially dangerous components: $file_path"
        return 1
    fi

    # Check absolute paths if not allowed
    if [[ "$allow_absolute" != "true" && "$file_path" == /* ]]; then
        error "Absolute paths not allowed: $file_path"
        return 1
    fi

    return 0
}

# Common progress indication
show_progress() {
    local current="$1"
    local total="$2"
    local operation="$3"

    local percentage=$((current * 100 / total))
    local filled=$((percentage / 2))
    local empty=$((50 - filled))

    printf "\r${CYAN}[%s%s]${NC} %d%% - %s" \
        "$(printf "%*s" $filled | tr ' ' '=')" \
        "$(printf "%*s" $empty | tr ' ' '-')" \
        "$percentage" \
        "$operation"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Get file size in human readable format
get_file_size() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        echo "0"
        return 1
    fi

    # Try different stat commands based on OS
    local size
    if command -v stat >/dev/null 2>&1; then
        size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
    else
        size=0
    fi

    echo "$size"
}

# Format file size for display
format_file_size() {
    local size_bytes="$1"

    if [[ "$size_bytes" -lt 1024 ]]; then
        echo "${size_bytes}B"
    elif [[ "$size_bytes" -lt 1048576 ]]; then
        echo "$((size_bytes / 1024))KB"
    elif [[ "$size_bytes" -lt 1073741824 ]]; then
        echo "$((size_bytes / 1048576))MB"
    else
        echo "$((size_bytes / 1073741824))GB"
    fi
}

# Generate unique identifier
generate_unique_id() {
    local prefix="${1:-id}"
    local timestamp
    timestamp=$(date +%s%N 2>/dev/null || date +%s)
    local random
    random=$(head -c 8 /dev/urandom 2>/dev/null | hexdump -v -e '/1 "%02x"' | tr -d '\n ' || echo "random")

    echo "${prefix}_${timestamp}_${random}"
}

# Register shared functions
register_shared_function() {
    local function_name="$1"
    local function_description="$2"

    SHARED_FUNCTIONS["$function_name"]="$function_description"
    log "Registered shared function: $function_name - $function_description"
}

# List all shared functions
list_shared_functions() {
    echo "Available Shared Functions:"
    echo "========================="

    if [[ ${#SHARED_FUNCTIONS[@]} -eq 0 ]]; then
        echo "No shared functions registered"
        return 0
    fi

    for func_name in "${!SHARED_FUNCTIONS[@]}"; do
        echo "  $func_name: ${SHARED_FUNCTIONS[$func_name]}"
    done
}

# Export all shared functions
export -f register_installation get_installation_path validate_system_requirements
export -f create_shared_directory create_shared_file create_shared_file
export -f download_shared_file install_binary get_latest_version_for_binary
export -f create_project_template create_environment_file create_package_json
export -f create_requirements_txt create_gitignore create_readme
export -f validate_project_name validate_file_path show_progress
export -f get_file_size format_file_size generate_unique_id
export -f register_shared_function list_shared_functions

# Export variables
export INSTALLATION_REGISTRY SHARED_FUNCTIONS

# Register core shared functions
register_shared_function "validate_system_requirements" "Validate required system tools and dependencies"
register_shared_function "create_shared_directory" "Create directories with error handling"
register_shared_function "download_shared_file" "Download files with checksum validation"
register_shared_function "install_binary" "Install binary executables with rollback"
register_shared_function "create_project_template" "Create project templates with standard structure"
register_shared_function "create_environment_file" "Create environment files with variables"
register_shared_function "create_package_json" "Create package.json for Node.js projects"
register_shared_function "create_requirements_txt" "Create requirements.txt for Python projects"
register_shared_function "create_gitignore" "Create .gitignore files for different project types"
register_shared_function "create_readme" "Create README.md files with project information"
register_shared_function "validate_project_name" "Validate project name format"
register_shared_function "validate_file_path" "Validate file path for security"
register_shared_function "show_progress" "Display progress bars for long operations"
register_shared_function "generate_unique_id" "Generate unique identifiers for projects"