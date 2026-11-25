# shellcheck shell=sh
# shellcheck disable=SC2034 # Sourced by build.sh and package.sh.
# Shared by build.sh and package.sh. All paths are relative to the repo root.
arch=${ALPINE_ARCH:-}
native_arch=
if [ -f /etc/alpine-release ]; then
	native_arch=$(apk --print-arch)
fi
arch=${arch:-${native_arch:-x86_64}}
case "$arch" in
	x86_64) goarch=amd64; elf_machine='Advanced Micro Devices X86-64' ;;
	aarch64) goarch=arm64; elf_machine=AArch64 ;;
	*) echo "Unsupported ALPINE_ARCH=$arch (use x86_64 or aarch64)" >&2; exit 1 ;;
esac
bins=core/bin/alpine-$goarch
