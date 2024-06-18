#!/bin/bash
#
# Test pv usage with mksquashfs using several different versions and options
#
#------------------------------------------------------------------------------

set -Eeuo pipefail  # exit on most errors
trap '>&2 echo "error: line $LINENO, status $?: $BASH_COMMAND"' ERR

#------------------------------------------------------------------------------

self=${0##*/}
here=$(dirname "$(readlink -f "$0")")
bindir=$here/bin  # keep in sync with ./prepare.sh!

outdir=$here/out
tmpdir=$(mktemp --directory)
trap 'rm -rf -- "$tmpdir"' EXIT
mkdir -p -- "$outdir"

# -------------------------------------------------------------

escape()  { printf '%q' "$1"; }  # $@ will not work as expected

run() {
	pseudo="zeroes.img f 444 0 0 $(escape "$pv") -Ss 10G /dev/zero"
	tmpfile=${here}/test_${mksquashfs##*/}_${pv##*/}.sqsh
	rm -f "$tmpfile"
	"$mksquashfs" "$tmpdir" "$tmpfile" -info -p "$pseudo"
}

pv_bins=( "$bindir"/pv-* )
mk_bins=( "$bindir"/mksquashfs-* )

for mksquashfs in "${mk_bins[@]}"; do
	for pv in "${pv_bins[@]}"; do
		run
	done
done
