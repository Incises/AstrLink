#!/bin/sh
set -eu
. packaging/alpine/target.sh

case "$1" in
gateway)
	version=${ASTRLINK_VERSION:-}
	if [ -z "$version" ]; then
		version=$(sed -n 's/^  "version": "\(.*\)",$/\1/p' apps/desktop/package.json)
	fi
	version=${version#v}
	commit=${ASTRLINK_COMMIT:-}
	if [ -z "$commit" ]; then
		commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)
	fi
	(
		cd core
		module=$(go list -m)
		ldflags="-s -w"
		if [ -n "$version" ]; then
			ldflags="$ldflags -X $module/internal/buildinfo.Version=$version"
		fi
		if [ -n "$commit" ]; then
			ldflags="$ldflags -X $module/internal/buildinfo.Commit=$commit"
		fi
		export GOOS=linux GOARCH="$goarch" CGO_ENABLED=0
		go build -trimpath -tags webui -ldflags="$ldflags" -o "../$bins/astrlink-core" ./cmd/astrlink-core
		go build -trimpath -ldflags="$ldflags" -o "../$bins/astrlink-cli" ./cmd/astrlink-cli
	)
	;;
worker)
	target=$arch-unknown-linux-musl
	if [ "$arch" = "$native_arch" ]; then
		# Alpine's packaged Rust can use a vendor-specific host triple.
		host=$(rustc -vV | sed -n 's/^host: //p')
		case "$host" in "$arch"-*-linux-musl) target=$host ;; esac
		cc=cc
		ar='ar'
		cxx=c++
	else
		# Both GNU/Linux cross toolchains and macOS Homebrew toolchains.
		for prefix in "$target" "$arch-linux-musl"; do
			if command -v "$prefix-gcc" >/dev/null; then break; fi
		done
		cc=$prefix-gcc
		cxx=$prefix-g++
		ar=$prefix-ar
		if ! command -v "$cc" >/dev/null; then
			echo "Install a $target GCC toolchain and Rust target ($target) to cross-build the worker." >&2
			exit 1
		fi
	fi
	target_key=$(echo "$target" | tr '-' '_')
	cargo_key=$(echo "$target_key" | tr '[:lower:]' '[:upper:]')
	build_dir=${CARGO_TARGET_DIR:-apps/privacy-worker/target}
	# Dynamic musl is required for loading Alpine's ONNX Runtime with dlopen.
	rustflags="${RUSTFLAGS:+$RUSTFLAGS }-C target-feature=-crt-static"
	case "$target" in
		*-alpine-linux-musl) ;;
		*) rustflags="$rustflags -C link-self-contained=no" ;;
	esac
	env "CC_$target_key=$cc" "CXX_$target_key=$cxx" "AR_$target_key=$ar" \
		"CARGO_TARGET_${cargo_key}_LINKER=$cc" \
		"RUSTFLAGS=$rustflags" \
		cargo build --locked --release --target "$target" --target-dir "$build_dir" \
		--manifest-path apps/privacy-worker/Cargo.toml
	install -d "$bins"
	install -m 755 "$build_dir/$target/release/astrlink-privacy-worker" "$bins/"
	;;
*) echo "Usage: $0 gateway|worker" >&2; exit 2 ;;
esac
