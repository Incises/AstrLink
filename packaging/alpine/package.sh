#!/bin/sh
# Run from the repository root with apk-tools 3 and readelf after make alpine (use the same ALPINE_ARCH).
# Usage: sh packaging/alpine/package.sh VERSION PRIVATE_SIGNING_KEY OUTPUT_DIR
set -eu
version=${1:?supply an APK version including -rN}
key=${2:?supply the signing key path}
out=${3:?supply the output directory}
src=packaging/alpine
# shellcheck source=packaging/alpine/target.sh
. "$src/target.sh"

# Validate every input before signing any package.
export LC_ALL=C
for binary in astrlink-core astrlink-cli astrlink-privacy-worker; do
	if ! readelf -h "$bins/$binary" | grep -Eq "Machine:[[:space:]]+${elf_machine}[[:space:]]*$"; then
		echo "$bins/$binary: expected a Linux ELF for $arch" >&2
		exit 1
	fi
done
if ! readelf -lW "$bins/astrlink-privacy-worker" | grep -Fq "[Requesting program interpreter: /lib/ld-musl-$arch.so.1]"; then
	echo "privacy worker must use the $arch Alpine musl loader" >&2
	exit 1
fi
url=${ASTRLINK_URL:-https://github.com/Calcium-Ion/AstrLink}
mkdir -p "$out"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
for name in astrlink astrlink-cli astrlink-privacy-worker; do
	root="$stage/$name"
	mkdir -p "$root/usr/bin" "$root/usr/share/licenses/$name"
	cp LICENSE LICENSING.md "$root/usr/share/licenses/$name/"
	cp -R LICENSES "$root/usr/share/licenses/$name/"
	set -- --info "name:$name" --info "version:$version" --info "arch:$arch" \
		--info "origin:astrlink" --info "url:$url" \
		--info "license:AGPL-3.0-only AND Apache-2.0"
	if [ "$name" = astrlink ]; then
		mkdir -p "$root/etc/init.d" "$root/etc/conf.d"
		install -m755 "$bins/astrlink-core" "$root/usr/bin/"
		install -m755 "$src/astrlink.initd" "$root/etc/init.d/astrlink"
		install -m644 "$src/astrlink.confd" "$root/etc/conf.d/astrlink"
		set -- "$@" --info "description:AstrLink gateway with embedded Web UI and rule filtering" \
			--info "depends:openrc busybox ca-certificates-bundle" --script "pre-install:$src/pre-install" \
			--script "post-upgrade:$src/post-upgrade" --script "pre-deinstall:$src/pre-deinstall"
	elif [ "$name" = astrlink-cli ]; then
		install -m755 "$bins/astrlink-cli" "$root/usr/bin/"
		install -m755 "$src/astrlink" "$root/usr/bin/"
		set -- "$@" --info "description:AstrLink local control CLI" --info "depends:astrlink=$version"
	else
		install -m755 "$bins/$name" "$root/usr/bin/"
		set -- "$@" --info "description:AstrLink local privacy model worker" \
			--info "depends:astrlink=$version onnxruntime libgcc" \
			--script "post-install:$src/post-upgrade" --script "post-upgrade:$src/post-upgrade" \
			--script "post-deinstall:$src/post-upgrade"
	fi
	apk mkpkg "$@" --files "$root" --sign-key "$key" --output "$out/$name-$version-$arch.apk"
done
