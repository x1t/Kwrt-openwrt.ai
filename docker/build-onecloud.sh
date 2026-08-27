#!/usr/bin/env bash

set -euo pipefail

readonly source_dir=/workspace
readonly openwrt_dir=/build/openwrt
readonly target=amlogic_meson8b
readonly openwrt_repository=https://github.com/openwrt/openwrt.git
readonly openwrt_ref=v25.12.5

git_clone_path() {
	local source_ref="$1"
	local source_url="$2"
	local copy_mode=copy
	local root_dir="$PWD"
	local temporary_dir
	shift 2

	if [[ "${1:-}" == mv ]]; then
		copy_mode=merge
		shift
	fi

	[[ "$#" -gt 0 ]] || {
		echo "git_clone_path: missing sparse path" >&2
		return 1
	}

	temporary_dir="$(mktemp -d)"
	if [[ "$source_ref" =~ ^[0-9a-f]{40}$ ]]; then
		git clone --filter=blob:none --sparse "$source_url" "$temporary_dir"
		git -C "$temporary_dir" checkout "$source_ref"
	else
		git clone --depth=1 --filter=blob:none --sparse \
			--branch "$source_ref" "$source_url" "$temporary_dir"
	fi
	git -C "$temporary_dir" sparse-checkout set "$@"

	local sparse_path
	for sparse_path in "$@"; do
		[[ -e "$temporary_dir/$sparse_path" ]] || {
			echo "Missing path $sparse_path in $source_url@$source_ref" >&2
			return 1
		}
		mkdir -p "$(dirname "$root_dir/$sparse_path")"
		if [[ "$copy_mode" == merge ]]; then
			mkdir -p "$root_dir/$sparse_path"
			cp -a -n "$temporary_dir/$sparse_path/." "$root_dir/$sparse_path/"
		else
			cp -a -n "$temporary_dir/$sparse_path" "$root_dir/$sparse_path"
		fi
	done
	rm -rf "$temporary_dir"
}
export -f git_clone_path

rm -rf "$openwrt_dir"
git clone --depth=1 --branch "$openwrt_ref" "$openwrt_repository" "$openwrt_dir"
cp -a "$source_dir/devices" "$openwrt_dir/devices"

cd "$openwrt_dir"
cp -a devices/common/. ./
cp -a "devices/$target/." ./
bash devices/common/diy.sh

cp devices/common/.config .config
printf '\n' >>.config
cat "devices/$target/.config" >>.config
cat >>.config <<'EOF'
CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT="/opt/go-bootstrap"
CONFIG_GOLANG_BUILD_BOOTSTRAP=y
EOF
bash "devices/$target/diy.sh"
[[ ! -d diy ]] || cp -a diy/. ./

cp -a -n devices/common/patches/. "devices/$target/patches/"
while IFS= read -r -d '' patch_file; do
	git apply "$patch_file"
done < <(find "devices/$target/patches" -maxdepth 1 -type f -name '*.bin.patch' -print0 | sort -z)
while IFS= read -r -d '' patch_file; do
	patch -d . -R --batch --forward --no-backup-if-mismatch -p1 -F 1 <"$patch_file"
done < <(find "devices/$target/patches" -maxdepth 1 -type f -name '*.revert.patch' -print0 | sort -z)
while IFS= read -r -d '' patch_file; do
	patch -d . --batch --forward --no-backup-if-mismatch -p1 -F 1 <"$patch_file"
done < <(find "devices/$target/patches" -maxdepth 1 -type f -name '*.patch' ! -name '*.revert.patch' ! -name '*.bin.patch' -print0 | sort -z)

ln -s /cache/dl dl
ln -s /cache/build_dir build_dir
ln -s /cache/staging_dir staging_dir
mkdir -p /cache/dl /cache/build_dir /cache/staging_dir

make defconfig
grep -Fqx 'CONFIG_TARGET_ROOTFS_PARTSIZE=7168' .config
grep -Fqx 'CONFIG_PACKAGE_luci-app-openclash=y' .config
grep -Fqx 'CONFIG_PACKAGE_luci-app-adguardhome=y' .config
grep -Fqx 'CONFIG_PACKAGE_luci-app-passwall=y' .config
grep -Fqx 'CONFIG_PACKAGE_docker=y' .config
grep -Fqx 'CONFIG_PACKAGE_dockerd=y' .config
grep -Fqx 'CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT="/opt/go-bootstrap"' .config

make download -j2
if find dl -type f -size -1024c -print -quit | grep -q .; then
	echo 'Incomplete source downloads detected' >&2
	exit 1
fi

make -j2 || make -j1 V=s

readonly target_dir="$openwrt_dir/bin/targets/amlogic/meson8b"
manifest="$(find "$target_dir" -maxdepth 1 -type f -name '*onecloud.manifest' -print -quit)"
image="$(find "$target_dir" -maxdepth 1 -type f \( -name '*onecloud*emmc_burn.img' -o -name '*onecloud*emmc_burn.img.gz' \) -print -quit)"
[[ -n "$manifest" && -f "$manifest" ]]
[[ -n "$image" && -f "$image" ]]
grep -Eq '^luci-app-openclash[[:space:]]' "$manifest"
grep -Eq '^luci-app-adguardhome[[:space:]]' "$manifest"
grep -Eq '^luci-app-passwall[[:space:]]' "$manifest"

rm -rf /artifacts/*
cp "$manifest" /artifacts/
cp .config /artifacts/amlogic_meson8b.config
if [[ "$image" == *.gz ]]; then
	gzip -t "$image"
	cp "$image" /artifacts/
else
	pigz -9 -c "$image" >"/artifacts/$(basename "$image").gz"
fi
(
	cd /artifacts
	sha256sum -- * >SHA256SUMS
)
ls -lh /artifacts
