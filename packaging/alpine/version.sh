#!/bin/sh
# Convert a SemVer release tag (e.g. v0.3.8, v0.3.9-rc.1) into an Alpine APK version.
# Usage: sh packaging/alpine/version.sh TAG [REVISION]
set -eu
tag=${1:?supply a SemVer tag}
rev=${2:-0}
case "$rev" in
	''|*[!0-9]*) echo "Invalid APK revision: $rev" >&2; exit 1 ;;
esac
ver=${tag#v}
ver=${ver%%+*}
base=${ver%%-*}
case "$base" in
	''|.*|*.|*..*|*[!0-9.]*) echo "Invalid version core: $tag" >&2; exit 1 ;;
esac
if [ "$base" = "$ver" ]; then
	printf '%s-r%s\n' "$base" "$rev"
	exit 0
fi
pre=${ver#*-}
case "$pre" in
	alpha|beta|pre|rc) suffix="_$pre" ;;
	alpha.*|beta.*|pre.*|rc.*)
		kind=${pre%%.*}
		num=${pre#*.}
		case "$num" in
			''|*[!0-9]*) echo "Unsupported prerelease number in tag: $tag" >&2; exit 1 ;;
		esac
		suffix="_${kind}${num}"
		;;
	alpha[0-9]*|beta[0-9]*|pre[0-9]*|rc[0-9]*)
		suffix="_$pre"
		num=${pre#alpha}; num=${num#beta}; num=${num#pre}; num=${num#rc}
		case "$num" in
			*[!0-9]*) echo "Unsupported prerelease suffix in tag: $tag" >&2; exit 1 ;;
		esac
		;;
	*) echo "Unsupported prerelease tag for Alpine APK: $tag" >&2; exit 1 ;;
esac
printf '%s%s-r%s\n' "$base" "$suffix" "$rev"
