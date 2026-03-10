<div align="center">

# asdf-trivy [![Build](https://github.com/igno/asdf-trivy/actions/workflows/build.yml/badge.svg)](https://github.com/igno/asdf-trivy/actions/workflows/build.yml) [![Lint](https://github.com/igno/asdf-trivy/actions/workflows/lint.yml/badge.svg)](https://github.com/igno/asdf-trivy/actions/workflows/lint.yml)

[Trivy](https://github.com/aquasecurity/trivy) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Dependencies

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).
- `sha256sum` or `shasum` for checksum verification.
- `cosign` (optional) for sigstore signature verification.

# Install

Plugin:

```shell
asdf plugin add trivy https://github.com/igno/asdf-trivy.git
```

Trivy:

```shell
# Show all installable versions
asdf list-all trivy

# Install specific version
asdf install trivy latest

# Set a version globally (on your ~/.tool-versions file)
asdf global trivy latest

# Now trivy commands are available
trivy --version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Security

This plugin verifies every download:

- **SHA256 checksum** verification is always performed against the official checksums file from each release.
- **Sigstore signature** verification is automatically performed if `cosign` is found in PATH, using keyless verification against the Trivy GitHub Actions OIDC identity.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

# License

See [LICENSE](LICENSE) © [igno](https://github.com/igno/)
