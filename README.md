# WordPress Plugin Update Checker

A bash script to safely check and update WordPress plugins while preserving custom modifications.

Version: 1.0

## Description

This script helps maintain WordPress plugins by checking for custom modifications before updating them. It's particularly useful in development environments where plugins might have been modified for testing or customization purposes.

The script downloads the current version of the plugin from WordPress.org and compares it with your local version. If any differences are found, it prevents the update to avoid losing custom changes.

## ⚠️ Important Warnings

- This script will modify your WordPress installation
- Always backup your files and database before running this script
- It's strongly recommended to test with `--dry-run` first to see what changes would be made
- Use this script at your own risk!

### Backup Your WordPress Installation

Before running this script, it's crucial to backup your WordPress installation. Here are some helpful resources:

- [WordPress.org - Backing Up Your Database](https://wordpress.org/documentation/article/backing-up-your-database/)
- [WordPress.org - Backing Up Your WordPress Files](https://wordpress.org/documentation/article/backing-up-your-wordpress-files/)
- [WPBeginner - How to Backup WordPress](https://www.wpbeginner.com/beginners-guide/the-ultimate-wordpress-backup-guide/)

For automated backups, consider using one of these popular plugins:
- [UpdraftPlus](https://wordpress.org/plugins/updraftplus/)
- [BackWPup](https://wordpress.org/plugins/backwpup/)
- [WPvivid Backup](https://wordpress.org/plugins/wpvivid-backuprestore/)

## Features

- Checks if a plugin has been modified by comparing it with the WordPress.org version
- Shows detailed differences between local and WordPress.org versions
- Can process a single plugin or all installed plugins
- Logs all operations to plugin-updates.log for review
- Prevents updates of modified plugins to avoid losing custom changes
- Supports dry-run mode to check without making changes
- Configurable logging options
- Line number display for file differences
- WP-CLI cache management
- Root user support
- Option to save only differences to log file
- Standard logging format with timestamps and log levels
- Option to backup existing log files with date

## Requirements

- WordPress installation with WP-CLI ([Installation Guide](https://wp-cli.org/docs/installing/))
- Bash shell
- wget
- unzip
- diff

## Installation

1. Clone this repository
2. Make the script executable:
   ```bash
   chmod +x wordpress/check-plugin-updates.sh
   ```

## Usage

```bash
./check-plugin-updates.sh [options] [plugin-slug|all]
```

### Options

- `--path=/path/to/wordpress`: Specify the WordPress installation path
- `--dry-run`: Run in dry-run mode (no changes will be made)
- `--no-log`: Disable logging to file
- `--log-file=filename`: Specify a custom log file name (default: plugin-updates.log)
- `--flush-cache`: Clear WP-CLI cache before downloading
- `--allow-root`: Allow running WP-CLI commands as root
- `--save-diffs-only`: Save only differences to log file (useful for tracking modified plugins)
- `--save-old-logs`: Backup existing log file with date before starting
- `--help, -h`: Show help message
- `plugin-slug`: The slug of the plugin to check/update
- `all`: Process all installed plugins

### Important Notes

- By default, the script will use the current directory as the WordPress root path. If you don't specify the `--path` argument, you must run the script from the WordPress root folder.
- The script requires WP-CLI to be available in your system. For installation instructions, visit the [WP-CLI documentation](https://wp-cli.org/docs/installing/).
- If no plugin slug is provided, the script will show a help message. Use 'all' to process all installed plugins.
- Always test with `--dry-run` first!
- Use `--allow-root` when running the script as root user
- Use `--flush-cache` if you want to ensure fresh downloads from WordPress.org
- Use `--save-diffs-only` to keep track of only the plugins that have been modified
- By default, existing log files are cleared before starting. Use `--save-old-logs` to backup them with date.

### Examples

```bash
# Show help message
./check-plugin-updates.sh --help

# Check and update a specific plugin
./check-plugin-updates.sh contact-form-7

# Check and update with custom WordPress path
./check-plugin-updates.sh --path=/var/www/html contact-form-7

# Run in dry-run mode (recommended first step)
./check-plugin-updates.sh --dry-run contact-form-7

# Disable logging
./check-plugin-updates.sh --no-log contact-form-7

# Use custom log file
./check-plugin-updates.sh --log-file=custom.log contact-form-7

# Clear WP-CLI cache before downloading
./check-plugin-updates.sh --flush-cache contact-form-7

# Run as root user
./check-plugin-updates.sh --allow-root contact-form-7

# Save only differences to log file
./check-plugin-updates.sh --save-diffs-only contact-form-7

# Backup existing log file before starting
./check-plugin-updates.sh --save-old-logs contact-form-7

# Process all installed plugins (use with caution!)
./check-plugin-updates.sh all
```

## Output

The script provides:
- Terminal output showing the progress and results
- Detailed log file (plugin-updates.log by default) containing:
  - Standard log format: [YYYY-MM-DD HH:MM:SS] LEVEL: Message
  - Log levels: INFO, WARNING, ERROR, DRY-RUN
  - Start and end timestamps
  - Plugin versions
  - File differences (if any)
  - Update status
- File comparison details showing:
  - Files only in local version
  - Files only in WordPress.org version
  - Files with different content
  - Detailed differences in file contents with line numbers
- Summary statistics showing:
  - Total plugins found
  - Plugins updated
  - Plugins with differences
  - Plugins already up to date
  - Premium plugins

When using `--save-diffs-only`, the log file will only contain information about plugins that have differences from their WordPress.org versions.

When using `--save-old-logs`, existing log files will be backed up with the current date in the format: `filename-YYYY-MM-DD-HHMMSS.log`

## Authors

This script was developed by [Pollux](https://polluxcoop.com), a free software cooperative based in Argentina.

Contributors:
- Sergio Milardovich
- Tomás Brasca

## License

This project is licensed under the GNU General Public License v3 (GPL-3.0) - see the LICENSE file for details. 