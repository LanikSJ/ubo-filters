# Agent Rules & Project Standards for ubo-filters

## Repository Overview

ubo-filters contains uBlock Origin filter lists for blocking ads and tracking.

## Code Standards and Practices

### Filter Standards

- Follow AdBlock filter syntax and best practices.
- Use clear, descriptive filter rules with proper comments.
- Implement proper filter validation and testing.
- Document filter purposes and sources.

### Documentation Standards

- Include clear installation and usage instructions for uBlock Origin.
- Document filter list purposes and coverage areas.
- Provide update procedures and maintenance guidelines.
- Use markdown formatting consistently.

### Markdown Compliance Requirements (MANDATORY)

- **ALL markdown files (.md) MUST pass markdownlint validation with zero errors or warnings**
- Run `markdownlint <filename>` on every markdown file before considering it complete
- Follow the project's `.markdownlint.json` configuration strictly
- Address ALL markdownlint issues immediately - no exceptions or workarounds
- Common requirements include:
  - Maximum line length of 80 characters (MD013)
  - Consistent heading styles and hierarchy
  - Proper list formatting and indentation
  - Blank lines around headings and code blocks
  - Consistent link and reference formatting
  - No trailing whitespace
  - Files must end with newlines
  - Proper table formatting when applicable
- Use `markdownlint --fix <filename>` for auto-fixable issues when available
- Validate markdown files in CI/CD pipelines where applicable

### Whitespace and Code Formatting Standards

- **ALL files MUST be free of trailing whitespace**
- Run `grep -n '[[:space:]]$' <filename>` to check for trailing whitespace
- Remove trailing whitespace with: `sed -i '' 's/[[:space:]]*$//' <filename>`
- Ensure consistent indentation (prefer spaces over tabs for shell scripts)
- Use Unix line endings (LF) - no DOS line endings (CRLF)
- Validate shell scripts with `shellcheck` where applicable
- For shell scripts (.sh files):
  - Use 2-space indentation consistently
  - Avoid mixed tabs and spaces
  - Ensure proper shebang lines
  - Use `set -euo pipefail` for error handling
- Clean up whitespace before committing changes

## Development Guidelines

### When Making Changes

- Preserve existing functionality unless explicitly asked to change it
- Update documentation when adding new filter categories or modifying rules
- Test filters across different browsers and ad blockers
- **Always run markdownlint and fix all issues in markdown files before considering changes complete**

### Filter List Standards

- Maintain compatibility with uBlock Origin and similar blockers
- Implement proper rule ordering and priorities
- Use AGLint for comprehensive filter validation
- Test filters against real websites and tracking mechanisms

## GitHub & Automation Standards

These rules apply specifically to files in `.github/*` (workflows, templates, and documentation).

### Quality Gates (MANDATORY)

Before completing any change in `.github/`:

1. ✅ Run `markdownlint` validation (if .md file).
2. ✅ Ensure project standards are followed.
3. ✅ Verify contribution guidelines are up-to-date.
4. ✅ Check that automation maintains project standards.

### Templates and Workflows

- Ensure issue and pull request templates provide clear, actionable guidelines.
- Include project-specific troubleshooting sections in templates.
- Reference existing project documentation and standards.

### Documentation standards in .github/

- `.github/CONTRIBUTING.md` must include:
  - Development environment setup instructions.
  - Testing requirements and procedures.
  - Documentation standards for new features.
  - Project-specific contribution guidelines.

### Automation and CI/CD

- Project workflows must include automated testing stages.
- Code quality checks must be integrated into CI/CD.
- Release automation must be properly configured.

### Error Prevention

- NEVER generate markdown that violates line length or formatting rules.
- ALWAYS cross-reference with existing project practices before making changes.
- ENSURE all links and references are valid and current.
- VALIDATE that new requirements don't conflict with established workflows.
