#!/bin/bash
#
# compile all versions of mksquashfs and pv
#
#------------------------------------------------------------------------------

set -Eeuo pipefail  # exit on most errors
trap '>&2 echo "error: line $LINENO, status $?: $BASH_COMMAND"' ERR

#------------------------------------------------------------------------------

self=${0##*/}
here=$(dirname "$(readlink -f "$0")")
bindir=$here/bin  # keep in sync with ./run.sh!
mkdir -p -- "$bindir"
echo '*' > "$bindir"/.gitignore

#------------------------------------------------------------------------------

install_packages() {
	# Install missing packages, marking them as auto-installed to help uninstall
	local pkg=
	local pkgs=()
	local ok
	for pkg in "$@"; do
		# shellcheck disable=SC1083
		ok=$(dpkg-query --showformat=\${Version} --show "$pkg" 2>/dev/null || true)
		if [[ -z "$ok" ]]; then pkgs+=( "$pkg" ); fi
	done
	if (("${#pkgs[@]}")); then
		# Single step in Ubuntu 20.04: apt-get install --mark-auto
		sudo apt-get install "${pkgs[@]}"
		sudo apt-mark auto "${pkgs[@]}"
	fi
}

get_repo() {
	# dir must be global!
	dir=$here/$(basename "$url" .git)
	if ! [[ -d "$dir" ]]; then git clone -- "$url" "$dir"; fi
}
switch_version() {
	cd "$dir"
	git checkout --force "$1"
	rm -rf *
	git reset --hard
	install_packages "${build_deps[@]}"
}
copy_bin() {
	cp -- "$dir"/"$bin" "$bindir"/"${bin##*/}"-"$version"
}

#------------------------------------------------------------------------------
# pv

build_old_pv() {
	switch_version v"$version"
	cd "$dir"
	./generate.sh
	sh ./configure
	make
	copy_bin
}
build_new_pv() {
	local v=; if [[ "$version" != main ]]; then v=v; fi
	switch_version "${v}${version}"
	cd "$dir"
	autoreconf -is
	sh ./configure
	make
	copy_bin
}

url=https://codeberg.org/a-j-wood/pv.git
bin=pv
build_deps=(
	# pv 1.6.6-1build2
	# debhelper (>= 9~)

	# pv 1.8.0
	autoconf  # includes autoreconf
	autopoint
	automake  # includes aclocal
	gettext

	# pv 1.8.5-2build1
	# debhelper-compat (= 13)
	# valgrind-if-available
	tmux
)
env=(
)
old_versions=(
	1.6.6   # Ubuntu 22.04
	1.6.20  # Last 1.6.x release
	1.7.0   # Changes to output and --force
	1.7.24  # Last 1.7.x release
)
new_versions=(
	1.8.5   # Ubuntu 24.04
	1.8.10  # Latest release
	main
)

get_repo
for version in "${old_versions[@]}"; do build_old_pv; done
for version in "${new_versions[@]}"; do build_new_pv; done

#------------------------------------------------------------------------------
# mksquashfs

build_mksquashfs() {
	switch_version "$version"
	cd "$dir"/"$srcdir"
	env "${env[@]}" make
	copy_bin
}

url=https://github.com/plougher/squashfs-tools.git
srcdir=squashfs-tools
bin=$srcdir/mksquashfs
build_deps=(
	# mksquashfs 4.6.1-1build1
	# mksquashfs 4.5-3build1: all from 4.6.1 except help2man
	# debhelper-compat (= 13)
	libattr1-dev
	liblzma-dev
	liblzo2-dev
	liblz4-dev
	zlib1g-dev
	libzstd-dev
	help2man
)
env=(
	# squashfs-tools_4.6.1-1build1.debian.xz/debian/rules
	# same for 4.5
	LZMA_XZ_SUPPORT=1
	LZ4_SUPPORT=1
	LZO_SUPPORT=1
	XZ_SUPPORT=1
	ZSTD_SUPPORT=1
)
versions=(
	4.5     # Ubuntu 22.04
	4.6.1   # Ubuntu 24.04
	master  # Still 4.6.1, 290 commits since last release as of 2024-06-15
)

get_repo && for version in "${versions[@]}"; do build_mksquashfs; done
