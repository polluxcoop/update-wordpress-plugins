#!/bin/bash

# WordPress Plugin Update Checker
# =============================
#
# Version: 1.0
#
# Authors: Sergio Milardovich (@milardovich), Tomas Brasca (@soundOfff)
#
# WARNING: This script will modify your WordPress installation.
#          Always backup your files and database before running this script.
#          It's strongly recommended to test with --dry-run first.
#
# This script helps maintain WordPress plugins by checking for custom modifications
# before updating them. It's particularly useful in development environments where
# plugins might have been modified for testing or customization purposes.
#
# Features:
# - Checks if a plugin has been modified by comparing it with the WordPress.org version
# - Shows detailed differences between local and WordPress.org versions
# - Can process a single plugin or all installed plugins
# - Logs all operations to output.txt for review
# - Prevents updates of modified plugins to avoid losing custom changes
# - Supports dry-run mode to check without making changes
#
#
# Usage:
#   ./check-plugin-updates.sh [--path=/path/to/wordpress] [--dry-run] [--no-log] [--log-file=filename] [plugin-slug|all]
#   Use 'all' to process all installed plugins
#
# Note: This script requires WP-CLI to be available. For more information, visit:
#       https://wp-cli.org/docs/installing/
#
# Note: By default, the script will use the current directory as the WordPress root path.
#       If you don't specify the --path argument, you must run the script from the WordPress root folder.
#
# Output:
#   - Shows results in terminal
#   - Saves detailed log to output.txt in the current directory (unless --no-log is specified)
#   - Displays file differences if any are found
#
# Example:
#   ./check-plugin-updates.sh contact-form-7
#   ./check-plugin-updates.sh --path=/var/www/html contact-form-7
#   ./check-plugin-updates.sh --dry-run contact-form-7
#   ./check-plugin-updates.sh --no-log contact-form-7
#   ./check-plugin-updates.sh --log-file=custom.log contact-form-7
#   ./check-plugin-updates.sh all                     # Process all plugins
#
# Note: This script should be run from within the WordPress container
#       and requires WP-CLI to be available.

# ASCII Art for Pollux
echo "
______ _____ _      _     _   ___   __
| ___ \  _  | |    | |   | | | \ \ / /
| |_/ / | | | |    | |   | | | |\ V / 
|  __/| | | | |    | |   | | | |/   \ 
| |   \ \_/ / |____| |___| |_| / /^\ \

\_|    \___/\_____/\_____/\___/\/   \/

This script has been brought to you by Pollux
A free software cooperative based in Argentina
https://polluxcoop.com
"

# Parse command line arguments
WP_PATH=""
PLUGIN_SLUG=""
DRY_RUN=false
NO_LOG=false
LOG_FILE="plugin-updates.log"
FLUSH_CACHE=false
ALLOW_ROOT=false
SAVE_DIFFS_ONLY=false
SAVE_OLD_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --path=*)
            WP_PATH="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-log)
            NO_LOG=true
            shift
            ;;
        --log-file=*)
            LOG_FILE="${1#*=}"
            shift
            ;;
        --flush-cache)
            FLUSH_CACHE=true
            shift
            ;;
        --allow-root)
            ALLOW_ROOT=true
            shift
            ;;
        --save-diffs-only)
            SAVE_DIFFS_ONLY=true
            shift
            ;;
        --save-old-logs)
            SAVE_OLD_LOGS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options] [plugin-slug|all]"
            echo "Options:"
            echo "  --path=/path/to/wordpress  Specify WordPress installation path"
            echo "  --dry-run                  Run in dry-run mode (no changes)"
            echo "  --no-log                   Disable logging to file"
            echo "  --log-file=filename        Specify custom log file name"
            echo "  --flush-cache              Clear WP-CLI cache before downloading"
            echo "  --allow-root               Allow running WP-CLI commands as root"
            echo "  --save-diffs-only          Save only differences to log file"
            echo "  --save-old-logs            Backup existing log file with date"
            echo "  --help, -h                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 contact-form-7"
            echo "  $0 --path=/var/www/html contact-form-7"
            echo "  $0 --dry-run contact-form-7"
            echo "  $0 --no-log contact-form-7"
            echo "  $0 --log-file=custom.log contact-form-7"
            echo "  $0 --flush-cache contact-form-7"
            echo "  $0 --allow-root contact-form-7"
            echo "  $0 --save-diffs-only contact-form-7"
            echo "  $0 --save-old-logs contact-form-7"
            echo "  $0 all                     # Process all plugins"
            exit 0
            ;;
        *)
            PLUGIN_SLUG="$1"
            shift
            ;;
    esac
done

# If no plugin slug is provided, show help
if [ -z "$PLUGIN_SLUG" ]; then
    echo "Error: No plugin slug provided."
    echo "Use 'all' to process all plugins or specify a plugin slug."
    echo "Run with --help for more information."
    exit 1
fi

# Set WordPress root directory
if [ -z "$WP_PATH" ]; then
    WORDPRESS_ROOT=$(pwd)
else
    WORDPRESS_ROOT="$WP_PATH"
fi

# Verify WordPress installation
if [ ! -f "$WORDPRESS_ROOT/wp-config.php" ]; then
    echo "Error: WordPress installation not found at $WORDPRESS_ROOT"
    exit 1
fi

# Default temp directory if not defined in wp-config.php
DEFAULT_TEMP_DIR="$WORDPRESS_ROOT/wp-content/temp"

# Function to get WordPress temp directory from wp-config.php
get_wp_temp_dir() {
    if [ -f "$WORDPRESS_ROOT/wp-config.php" ]; then
        TEMP_DIR=$(grep -o "define.*WP_TEMP_DIR.*'[^']*'" "$WORDPRESS_ROOT/wp-config.php" | cut -d"'" -f4)
        if [ ! -z "$TEMP_DIR" ]; then
            echo "$TEMP_DIR"
            return 0
        fi
    fi
    echo "$DEFAULT_TEMP_DIR"
}

# Get the temp directory
TEMP_DIR=$(get_wp_temp_dir)
echo "Using temp directory: $TEMP_DIR"

if [ "$DRY_RUN" = true ]; then
    echo "Running in dry-run mode. No changes will be made."
fi

if [ "$NO_LOG" = true ]; then
    echo "Logging disabled."
fi

# Function to check if a plugin is premium
is_premium_plugin() {
    local plugin_slug=$1
    local version=$2
    
    # Try to download the plugin from wordpress.org
    if wget --spider "https://downloads.wordpress.org/plugin/$plugin_slug.$version.zip" 2>/dev/null; then
        return 1  # Plugin exists on wordpress.org, so it's not premium
    else
        return 0  # Plugin doesn't exist on wordpress.org, so it's premium
    fi
}

# Function to download and extract plugin
download_plugin() {
    local plugin_slug=$1
    local version=$2
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Flush WP-CLI cache if requested
    if [ "$FLUSH_CACHE" = true ]; then
        echo "Flushing WP-CLI cache..."
        wp cache flush --path="$WORDPRESS_ROOT" --allow-root
    fi
    
    # Download the plugin
    wget "https://downloads.wordpress.org/plugin/$plugin_slug.$version.zip"
    
    # Extract the plugin (suppress unzip output)
    unzip -q "$plugin_slug.$version.zip"
    
    # Clean up zip file
    rm "$plugin_slug.$version.zip"
}

# Function to compare directories
compare_directories() {
    local dir1=$1
    local dir2=$2
    local output_file=$3
    
    # Check if directories exist
    if [ ! -d "$dir1" ]; then
        echo "Error: Local plugin directory '$dir1' does not exist."
        return 1
    fi
    
    if [ ! -d "$dir2" ]; then
        echo "Error: Downloaded plugin directory '$dir2' does not exist."
        return 1
    fi
    
    # Create a temporary file for diff output
    local temp_diff=$(mktemp)
    
    # First, check if there are any differences
    if diff -r "$dir1" "$dir2" > /dev/null 2>&1; then
        # No differences found
        rm "$temp_diff"
        return 0
    fi
    
    # If we get here, there are differences
    # Extract plugin name from directory path
    local plugin_name=$(basename "$dir1")
    echo "Plugin: $plugin_name" | tee -a "$temp_diff"
    echo "----------------------------------------" | tee -a "$temp_diff"
    echo "Checking for modified files..." | tee -a "$temp_diff"
    echo "----------------------------------------" | tee -a "$temp_diff"
    
    # First, show files that exist in one directory but not in the other
    echo "Files only in local version:" | tee -a "$temp_diff"
    diff -rq "$dir1" "$dir2" | grep "Only in $dir1" | sed "s|Only in $dir1/||" | tee -a "$temp_diff" || true
    echo "----------------------------------------" | tee -a "$temp_diff"
    
    echo "Files only in WordPress.org version:" | tee -a "$temp_diff"
    diff -rq "$dir1" "$dir2" | grep "Only in $dir2" | sed "s|Only in $dir2/||" | tee -a "$temp_diff" || true
    echo "----------------------------------------" | tee -a "$temp_diff"
    
    # Then show files that have different content
    echo "Files with different content:" | tee -a "$temp_diff"
    diff -rq "$dir1" "$dir2" | grep "Files" | cut -d' ' -f4 | sed "s|$dir1/||" | tee -a "$temp_diff" || true
    echo "----------------------------------------" | tee -a "$temp_diff"
    
    # Finally, show the actual differences in the files with line numbers
    echo "Detailed differences (with line numbers):" | tee -a "$temp_diff"
    diff -r --unified=1 "$dir1" "$dir2" | grep -v "^Only in" | grep -v "^Common subdirectories" | tee -a "$temp_diff" || true
    echo "----------------------------------------" | tee -a "$temp_diff"
    
    # If we're saving diffs only, append to log file
    if [ "$NO_LOG" = false ] && [ "$SAVE_DIFFS_ONLY" = true ]; then
        cat "$temp_diff" >> "$output_file"
    fi
    
    # Clean up temp file
    rm "$temp_diff"
    
    return 1
}

# Function to log messages with standard format
log_message() {
    local level=$1
    local message=$2
    local output_file=$3
    
    # Format: [YYYY-MM-DD HH:MM:SS] LEVEL: Message
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] $level: $message"
    
    # Always show in terminal
    echo "$message"
    
    # Write to log file if logging is enabled
    if [ "$NO_LOG" = false ]; then
        echo "$log_entry" >> "$output_file"
    fi
}

# Function to process a single plugin
process_plugin() {
    local plugin_slug=$1
    local output_file=$2
    
    # Only log initial message if not saving diffs only
    if [ "$SAVE_DIFFS_ONLY" = false ]; then
        log_message "INFO" "Processing plugin: $plugin_slug" "$output_file"
    fi
    
    # Get current version
    CURRENT_VERSION=$(wp plugin list --path="$WORDPRESS_ROOT" --name=$plugin_slug --format=csv --fields=version ${ALLOW_ROOT:+--allow-root} | tail -n 1)
    
    if [ -z "$CURRENT_VERSION" ]; then
        log_message "ERROR" "Plugin $plugin_slug not found." "$output_file"
        return 1
    fi
    
    # Only log version if not saving diffs only
    if [ "$SAVE_DIFFS_ONLY" = false ]; then
        log_message "INFO" "Current version: $CURRENT_VERSION" "$output_file"
    fi
    
    # Create temporary directory for comparison
    mkdir -p "$TEMP_DIR"
    
    # Download current version for comparison
    if [ "$SAVE_DIFFS_ONLY" = false ]; then
        log_message "INFO" "Downloading current version for comparison..." "$output_file"
    fi
    download_plugin "$plugin_slug" "$CURRENT_VERSION"
    
    # Compare directories
    if [ "$SAVE_DIFFS_ONLY" = false ]; then
        log_message "INFO" "Comparing directories..." "$output_file"
    fi
    if ! compare_directories "$WORDPRESS_ROOT/wp-content/plugins/$plugin_slug" "$TEMP_DIR/$plugin_slug" "$output_file"; then
        log_message "WARNING" "Local plugin files differ from WordPress.org version." "$output_file"
        log_message "WARNING" "This might indicate custom modifications. Update aborted." "$output_file"
        ((DIFF_COUNT++))
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Clean up temp directory after diff check
    rm -rf "$TEMP_DIR"
    
    # Only check for updates if no diffs were found
    UPDATE_AVAILABLE=$(wp plugin list --path="$WORDPRESS_ROOT" --name=$plugin_slug --format=csv --fields=update ${ALLOW_ROOT:+--allow-root} | tail -n 1)
    
    if [ "$UPDATE_AVAILABLE" = "available" ]; then
        if [ "$SAVE_DIFFS_ONLY" = false ]; then
            log_message "INFO" "Update available for $plugin_slug" "$output_file"
            log_message "INFO" "Plugin files verified. Proceeding with update..." "$output_file"
        fi
        if [ "$DRY_RUN" = true ]; then
            log_message "DRY-RUN" "Would update $plugin_slug to version $CURRENT_VERSION" "$output_file"
        else
            wp plugin update "$plugin_slug" --path="$WORDPRESS_ROOT" --version="$CURRENT_VERSION" ${ALLOW_ROOT:+--allow-root}
            ((UPDATED_COUNT++))
        fi
    else
        if [ "$SAVE_DIFFS_ONLY" = false ]; then
            log_message "INFO" "Plugin $plugin_slug is already up to date." "$output_file"
        fi
        ((UPTODATE_COUNT++))
    fi
    
    # Only log completion message if not saving diffs only
    if [ "$SAVE_DIFFS_ONLY" = false ]; then
        log_message "INFO" "Update process completed for $plugin_slug" "$output_file"
        log_message "INFO" "----------------------------------------" "$output_file"
    fi
}

# Initialize counters
UPDATED_COUNT=0
DIFF_COUNT=0
UPTODATE_COUNT=0
PREMIUM_COUNT=0

# Function to handle log file initialization
init_log_file() {
    local log_file=$1
    
    if [ -f "$log_file" ]; then
        if [ "$SAVE_OLD_LOGS" = true ]; then
            # Create backup with current date and .bak extension
            local backup_file="${log_file%.*}-$(date '+%Y-%m-%d-%H%M%S').bak.${log_file##*.}"
            mv "$log_file" "$backup_file"
            echo "Backed up existing log file to: $backup_file"
        else
            # Clear the existing log file
            : > "$log_file"
        fi
    fi
}

# Main script
if [ "$NO_LOG" = false ]; then
    OUTPUT_FILE="$WORDPRESS_ROOT/$LOG_FILE"
    init_log_file "$OUTPUT_FILE"
    log_message "INFO" "Starting plugin update check" "$OUTPUT_FILE"
fi

if [ "$PLUGIN_SLUG" = "all" ]; then
    # Get list of all installed plugins
    PLUGINS=$(wp plugin list --path="$WORDPRESS_ROOT" --format=csv --fields=name ${ALLOW_ROOT:+--allow-root} | tail -n +2)
    TOTAL_PLUGINS=$(echo "$PLUGINS" | wc -l)
    
    log_message "INFO" "Found $TOTAL_PLUGINS plugins to process..." "$OUTPUT_FILE"
    log_message "INFO" "This process might take several minutes to complete..." "$OUTPUT_FILE"
    log_message "INFO" "----------------------------------------" "$OUTPUT_FILE"
    
    for plugin in $PLUGINS; do
        process_plugin "$plugin" "$OUTPUT_FILE"
    done
else
    log_message "INFO" "This process might take several minutes to complete..." "$OUTPUT_FILE"
    log_message "INFO" "----------------------------------------" "$OUTPUT_FILE"
    process_plugin "$PLUGIN_SLUG" "$OUTPUT_FILE"
fi

# Display summary
log_message "INFO" "============================================" "$OUTPUT_FILE"
log_message "INFO" "Update Summary:" "$OUTPUT_FILE"
log_message "INFO" "--------------------------------------------" "$OUTPUT_FILE"
if [ "$PLUGIN_SLUG" = "all" ]; then
    log_message "INFO" "Total plugins found: $TOTAL_PLUGINS" "$OUTPUT_FILE"
fi
log_message "INFO" "Plugins updated: $UPDATED_COUNT" "$OUTPUT_FILE"
log_message "INFO" "Plugins with differences: $DIFF_COUNT" "$OUTPUT_FILE"
log_message "INFO" "Plugins already up to date: $UPTODATE_COUNT" "$OUTPUT_FILE"
log_message "INFO" "Premium plugins: $PREMIUM_COUNT" "$OUTPUT_FILE"
log_message "INFO" "============================================" "$OUTPUT_FILE"

if [ "$NO_LOG" = false ]; then
    log_message "INFO" "Plugin update check completed" "$OUTPUT_FILE"
fi 