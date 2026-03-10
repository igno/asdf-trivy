#!/usr/bin/env bash
set -euo pipefail

readonly REPO="aquasecurity/trivy"
readonly GH_API="https://api.github.com"
readonly GH_RELEASES="https://github.com/${REPO}/releases/download"
readonly TOOL_NAME="trivy"

fail() {
	printf '%s\n' "$*" >&2
	exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts+=(-H "Authorization: token ${GITHUB_API_TOKEN}")
elif [ -n "${GITHUB_TOKEN:-}" ]; then
	curl_opts+=(-H "Authorization: token ${GITHUB_TOKEN}")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		sort -t. -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n | awk '{print $2}'
}

list_all_versions() {
	local page=1
	local results=""
	while true; do
		local page_results
		page_results=$(curl "${curl_opts[@]}" \
			"${GH_API}/repos/${REPO}/releases?per_page=100&page=${page}" |
			grep -oE '"tag_name":\s*"v[^"]+"' |
			sed 's/"tag_name": *"v//;s/"//' || true)
		if [ -z "${page_results}" ]; then
			break
		fi
		results="${results}${results:+$'\n'}${page_results}"
		page=$((page + 1))
	done
	echo "${results}"
}

get_platform() {
	local os arch

	os="$(uname -s)"
	case "${os}" in
	Linux) os="Linux" ;;
	Darwin) os="macOS" ;;
	FreeBSD) os="FreeBSD" ;;
	*) fail "Unsupported OS: ${os}" ;;
	esac

	arch="$(uname -m)"
	case "${arch}" in
	x86_64 | amd64) arch="64bit" ;;
	aarch64 | arm64) arch="ARM64" ;;
	armv7l | armv6l) arch="ARM" ;;
	i386 | i686) arch="32bit" ;;
	ppc64le) arch="PPC64LE" ;;
	s390x) arch="s390x" ;;
	*) fail "Unsupported architecture: ${arch}" ;;
	esac

	echo "${os}-${arch}"
}

get_archive_ext() {
	local os
	os="$(uname -s)"
	if [ "${os}" = "Windows_NT" ]; then
		echo "zip"
	else
		echo "tar.gz"
	fi
}

download_release() {
	local version="$1"
	local download_path="$2"
	local platform ext filename url checksum_url

	platform="$(get_platform)"
	ext="$(get_archive_ext)"
	filename="trivy_${version}_${platform}.${ext}"
	url="${GH_RELEASES}/v${version}/${filename}"
	checksum_url="${GH_RELEASES}/v${version}/trivy_${version}_checksums.txt"

	echo "* Downloading ${TOOL_NAME} ${version} for ${platform}..."
	curl "${curl_opts[@]}" -o "${download_path}/${filename}" "${url}"
	curl "${curl_opts[@]}" -o "${download_path}/checksums.txt" "${checksum_url}"

	echo "* Verifying checksum..."
	verify_checksum "${download_path}" "${filename}"

	if command -v cosign &>/dev/null; then
		local sig_url="${GH_RELEASES}/v${version}/trivy_${version}_checksums.txt.sigstore.json"
		echo "* Downloading sigstore bundle for signature verification..."
		curl "${curl_opts[@]}" -o "${download_path}/checksums.txt.sigstore.json" "${sig_url}"
		echo "* Verifying signature with cosign..."
		verify_signature "${download_path}" "${version}"
	else
		echo "* Skipping signature verification (cosign not found in PATH)"
	fi

	echo "* Extracting archive..."
	if [ "${ext}" = "zip" ]; then
		unzip -q "${download_path}/${filename}" -d "${download_path}"
	else
		tar xzf "${download_path}/${filename}" -C "${download_path}"
	fi

	rm -f "${download_path}/${filename}" \
		"${download_path}/checksums.txt" \
		"${download_path}/checksums.txt.sigstore.json"
}

verify_checksum() {
	local download_path="$1"
	local filename="$2"
	local expected actual

	expected=$(grep "  ${filename}$" "${download_path}/checksums.txt" | awk '{print $1}')
	if [ -z "${expected}" ]; then
		fail "Checksum not found for ${filename} in checksums.txt"
	fi

	if command -v sha256sum &>/dev/null; then
		actual=$(sha256sum "${download_path}/${filename}" | awk '{print $1}')
	elif command -v shasum &>/dev/null; then
		actual=$(shasum -a 256 "${download_path}/${filename}" | awk '{print $1}')
	else
		fail "Neither sha256sum nor shasum found in PATH"
	fi
	if [ "${expected}" != "${actual}" ]; then
		fail "Checksum verification failed for ${filename}
  expected: ${expected}
  actual:   ${actual}"
	fi
}

verify_signature() {
	local download_path="$1"
	local version="$2"

	cosign verify-blob \
		--certificate-identity-regexp "^https://github\\.com/${REPO}/" \
		--certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
		--bundle "${download_path}/checksums.txt.sigstore.json" \
		"${download_path}/checksums.txt" ||
		fail "Signature verification failed for checksums.txt"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"
	local download_path="$4"

	if [ "${install_type}" != "version" ]; then
		fail "asdf-${TOOL_NAME} supports release installs only"
	fi

	(
		mkdir -p "${install_path}"
		cp "${download_path}/trivy" "${install_path}/trivy"
		chmod +x "${install_path}/trivy"

		test -x "${install_path}/trivy" || fail "Expected ${install_path}/trivy to be executable."

		echo "${TOOL_NAME} ${version} installation was successful!"
	) || (
		rm -rf "${install_path}"
		fail "An error occurred while installing ${TOOL_NAME} ${version}."
	)
}
