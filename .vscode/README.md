# VS Code Configuration for FOP

Pre-configured VS Code settings for filter list projects.

## Quick Setup

**Option 1: Run setup script**
```bash
cd /path/to/your/filterlist
bash /path/to/.vscode/setup.sh .
```

**Option 2: Copy manually**
```bash
cp -r .vscode /path/to/your/filterlist/
```

## Included Files

| File | Purpose |
|------|---------|
| `tasks.json` | FOP tasks (Sort All, Sort File, Fix Typos, etc.) |
| `settings.json` | Editor settings for filter lists |
| `extensions.json` | Recommended extensions |
| `keybindings.example.jsonc` | Keyboard shortcut examples (copy to user settings) |
| `setup.sh` | Setup script for easy installation |

## Usage

### Run Tasks

- **Windows/Linux:** `Ctrl+Shift+P` → "Tasks: Run Task" → Select FOP task
- **macOS:** `Cmd+Shift+P` → "Tasks: Run Task" → Select FOP task

Or use `Ctrl+Shift+B` / `Cmd+Shift+B` for the default task (FOP: Sort All).

### Available Tasks

| Task | Description |
|------|-------------|
| FOP: Sort All | Sort all files in project |
| FOP: Sort Current File | Sort currently open file |
| FOP: Sort and Commit | Sort all + git commit prompt |
| FOP: Preview Changes (Diff) | Preview changes without modifying |
| FOP: Fix Typos | Fix typos in all files |
| FOP: Fix Typos and Commit | Fix typos + git commit prompt |

### Keyboard Shortcuts (Optional)

Copy shortcuts from `keybindings.example.jsonc` to your VS Code user keybindings:
- `Ctrl+K Ctrl+S` → Click the `{}` icon (Open Keyboard Shortcuts JSON)

## Recommended Extensions

When you open the project, VS Code will prompt to install:
- **Adblock Syntax** - Syntax highlighting (ABP, uBO, AdGuard)
- **GitLens** - Enhanced Git integration  
- **Run on Save** - Auto-run FOP on save (optional)

## Customization

Edit `.fopconfig` in your project root for FOP settings:

```ini
no-commit = true
fix-typos = true
quiet = false
```

See [FOP README](../README.md) for all configuration options.
