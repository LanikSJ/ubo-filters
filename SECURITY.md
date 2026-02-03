# Security Policy

## Supported Versions

| Application    | Version | Supported          |
| -------------- | ------- | ------------------ |
| Adblock Plus   | 3.x.x   | :white_check_mark: |
| Adblock Plus   | 2.x.x   | :x:                |
| uBlock Origin  | 1.x.x   | :white_check_mark: |
| uBlock Origin  | < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously and appreciate your efforts to responsibly disclose your findings.

### How to Report

**Do NOT open a public issue** for security vulnerabilities. Instead, please report security issues through one of these
 channels:

1. **GitHub Security Advisories** (Preferred): [Report via GitHub](https://github.com/LanikSJ/ubo-filters/security/advisories/new)
2. **Email**: Send details to [security@lanik.us](mailto:security@lanik.us)
3. **Security Discussions**: Open a discussion in our [GitHub Discussions](https://github.com/LanikSJ/ubo-filters/discussions/categories/security)
4. **Security Issues**: Create a [Security Advisory](https://github.com/LanikSJ/ubo-filters/security/advisories/new)
 on GitHub

### What to Include

When reporting a vulnerability, please include:

- **Description**: Clear explanation of the security issue
- **Steps to Reproduce**: Detailed steps to reproduce the vulnerability
- **Impact Assessment**: Potential impact and affected components
- **Proof of Concept**: If applicable, a minimal reproduction case
- **Suggested Fix**: If you have ideas for a fix (optional)

### Response Timeline

We are committed to responding to security reports in a timely manner:

- **Initial Response**: Within 48 hours of receiving the report
- **Status Update**: Within 5 business days with assessment
- **Resolution**: We will work diligently to fix critical vulnerabilities as quickly as possible

### Responsible Disclosure

We ask that you:

- Give us reasonable time to investigate and fix the issue before public disclosure
- Do not access, modify, or delete user data
- Do not perform attacks that could harm the availability of our services
- Do not publicly disclose the vulnerability until we have had a chance to address it

## Security Considerations

### Project-Specific Security

This project provides uBlock Origin and Adblock Plus filter lists. Security considerations include:

- **Filter Validation**: All filters are validated to prevent malicious patterns
- **No Executable Code**: The project contains only text-based filter rules
- **Regular Updates**: Filters are regularly updated to address new threats

## Security Best Practices

### For Users

- **Keep Updated**: Always use the latest version of the filters
- **Verify Sources**: Only download filters from official sources
- **Report Suspicious Filters**: If you notice anything unusual, please report it

### For Developers

When contributing to the project:

- **Validate Filters**: Always validate new filters before submission
- **Follow Guidelines**: Adhere to the project's contribution guidelines
- **Security First**: Prioritize security when adding new filters

## Security Resources

- [uBlock Origin Security](https://github.com/gorhill/uBlock)
- [Adblock Plus Security](https://adblockplus.org/security)
- [GitHub Security Documentation](https://docs.github.com/en/code-security/getting-started)

## Contact

For general security questions or concerns, you can:

- Open a discussion in our [GitHub Discussions](https://github.com/LanikSJ/ubo-filters/discussions)
- Contact the maintainers through the security email above for sensitive matters

Thank you for helping keep ubo-filters secure!
