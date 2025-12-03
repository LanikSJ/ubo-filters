# Contributing

Thank you for your interest in contributing to ubo-filters! This document
provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing](#testing)
- [Code of Conduct](#code-of-conduct)

## Getting Started

Before making changes, please:

1. **Discuss first**: Open an issue or contact maintainers via
   [forums.lanik.us](https://forums.lanik.us) before making significant
   changes

2. **Review existing issues**: Check if there's already work in progress
   on your intended changes

3. **Understand the project**: Read through existing filter rules to
   understand the format and structure

## Development Setup

1. **Fork and clone** the repository

2. **Install dependencies** (if any are required for development tools)

3. **Create a feature branch** from `main`:
   `git checkout -b feature/your-feature-name`

4. **Make your changes** following our coding standards

5. **Test your changes** thoroughly before submitting

## Contributing Guidelines

### Types of Contributions

We welcome various types of contributions:

- **Filter rules**: New ad blocking rules, privacy rules, or improvements
  to existing rules

- **Bug fixes**: Corrections to existing filter rules

- **Documentation**: Improvements to README files, inline comments, or
  this contributing guide

- **Tests**: Addition or improvement of automated tests

### Before Submitting

- [ ] Test your filter rules thoroughly in uBlock Origin
- [ ] Ensure rules don't cause false positives
- [ ] Follow the established rule format and syntax
- [ ] Keep rules as specific as possible to avoid over-blocking
- [ ] Update documentation if your changes affect the interface or usage
- [ ] Run markdownlint and fix all issues in markdown files

## Pull Request Process

1. **Ensure any install or build dependencies are removed** before the end
   of the layer when doing a build

2. **Update the README.md** with details of changes to the interface,
   including:
   - New environment variables
   - Exposed ports
   - Useful file locations
   - Container parameters (if applicable)

3. **Update version numbers** in any examples files and the README.md to
   reflect the new version this PR represents

4. **Use semantic versioning** following [SemVer](https://semver.org/)

5. **Request reviews** from at least two maintainers before merging

6. **Ensure CI/CD checks pass** (if applicable)

### PR Checklist

Before submitting your pull request, ensure:

- [ ] Your code follows the established style guidelines
- [ ] You have tested your changes thoroughly
- [ ] All tests pass (if applicable)
- [ ] Documentation is updated
- [ ] Commit messages are clear and descriptive
- [ ] Your branch is up to date with the target branch
- [ ] All markdown files pass markdownlint validation
- [ ] Filter rules follow AdBlock syntax and best practices
- [ ] Filters are validated using available testing tools

## Code Style

### Filter Rules Format

- Follow the existing format used throughout the repository
- Use consistent indentation (2 spaces for most files)
- Add clear comments for complex or non-obvious rules
- Group related rules together
- Use descriptive rule descriptions when possible
- Follow AdBlock filter syntax and best practices
- Use AGLint for comprehensive filter validation

### General Guidelines

- **Be consistent** with existing code style

- **Write clear commit messages**: Use present tense and descriptive
  messages

- **Keep changes focused**: One feature/fix per pull request

- **Document non-obvious code**: Add comments for complex logic

- **Preserve existing functionality** unless explicitly asked to change
  it

- **Test filters across different browsers** and ad blockers

### Markdown Compliance

- All markdown files (.md) MUST pass markdownlint validation with zero
  errors or warnings

- Run `markdownlint <filename>` on every markdown file before
  considering it complete

- Follow the project's `.markdownlint.json` configuration strictly

- Common requirements include:
  - Maximum line length of 120 characters (MD013)
  - Consistent heading styles and hierarchy
  - Proper list formatting and indentation
  - Blank lines around headings and code blocks
  - Consistent link and reference formatting
  - No trailing whitespace
  - Files must end with newlines

- Use `markdownlint --fix <filename>` for auto-fixable issues when
  available

## Testing

### Manual Testing

1. Test filter rules in uBlock Origin

2. Verify rules don't cause false positives on legitimate websites

3. Test across different browsers if possible

4. Validate filter syntax using available tools

5. Test filters against real websites and tracking mechanisms

### Automated Testing

- Ensure any existing tests continue to pass

- Add tests for new functionality where applicable

- Run linting and formatting tools before submitting

- Validate markdown files in CI/CD pipelines where applicable

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive experience for
everyone. We pledge to make participation in our project and community a
harassment-free experience regardless of age, body size, disability,
ethnicity, gender identity and expression, level of experience,
nationality, personal appearance, race, religion, or sexual identity
and orientation.

### Our Standards

Examples of behavior that contribute to creating a positive environment
include:

- Using welcoming and inclusive language

- Being respectful of differing viewpoints and experiences

- Gracefully accepting constructive criticism

- Focusing on what is best for the community

- Showing empathy towards other community members

Examples of unacceptable behavior include:

- The use of sexualized language or imagery and unwelcome sexual
  attention or advances

- Trolling, insulting/derogatory comments, and personal or political
  attacks

- Public or private harassment

- Publishing others' private information (physical or electronic
  address) without explicit permission

- Other conduct which could reasonably be considered inappropriate in a
  professional setting

### Our Responsibilities

Project maintainers are responsible for clarifying standards of
acceptable behavior and are expected to take appropriate and fair
corrective action in response to any instances of unacceptable behavior.

Project maintainers have the right and responsibility to remove, edit, or
reject comments, commits, code, wiki edits, issues, and other
contributions that are not aligned with this Code of Conduct, or to ban
temporarily or permanently any contributor for behaviors deemed
inappropriate, threatening, offensive, or harmful.

### Scope

This Code of Conduct applies both within project spaces and in public
spaces when an individual is representing the project or its community.
Examples include using an official project e-mail address, posting via an
official social media account, or acting as an appointed representative
at an online or offline event.

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may
be reported by contacting the project team at
[forums.lanik.us](https://forums.lanik.us).

All complaints will be reviewed and investigated and will result in a
response that is deemed necessary and appropriate to the circumstances.
The project team is obligated to maintain confidentiality with regard to
the reporter of an incident. Further details of specific enforcement
policies may be posted separately.

Project maintainers who do not follow or enforce the Code of Conduct in
good faith may face temporary or permanent repercussions as determined
by other members of the project's leadership.

### Attribution

This Code of Conduct is adapted from the
[Contributor Covenant](https://www.contributor-covenant.org/), version
1.4, available at
[https://www.contributor-covenant.org/version/1/4/](https://www.contributor-covenant.org/version/1/4/)

---

## Questions?

If you have questions about contributing, please reach out to the
maintainers through:

- Opening an issue in this repository

- Contacting us at [forums.lanik.us](https://forums.lanik.us)

Thank you for contributing to ubo-filters!
