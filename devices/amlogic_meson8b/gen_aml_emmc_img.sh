#!/bin/bash

set -euo pipefail

if [[ "$#" -ne 5 ]]; then
	echo "Usage: $0 <output_image> <boot_partition_image> <rootfs_image> <bootfs_size> <rootfs_size>" >&2
	exit 1
fi

readonly output_image="$(readlink -f "$1")"
readonly boot_partition_image="$(readlink -f "$2")"
readonly rootfs_image="$(readlink -f "$3")"
readonly template_url="https://github.com/hzyitc/u-boot-onecloud/releases/download/build-20221028-0940/eMMC.burn.img"
readonly template_sha256="d33d979d23b8a607447c5af424b1e24003820e7e159e540c7f47c89d45cdc491"
readonly work_dir="$(mktemp -d "${TMPDIR:-/tmp}/onecloud-burn.XXXXXX")"

case "$(uname -m)" in
	x86_64)
		readonly amlimg_asset="AmlImg_v0.3.1_linux_amd64"
		readonly amlimg_sha256="b4c72e35b3ff45fb76c6ed2fd7b4b9235a73cd8558b2b432af3efd5aac78f622"
		;;
	aarch64 | arm64)
		readonly amlimg_asset="AmlImg_v0.3.1_linux_arm64"
		readonly amlimg_sha256="853c5d74d6da5d64dcd7cc08b833d3fb9913da460a9a037b9741859e1aa9b99b"
		;;
	*)
		echo "Unsupported AmlImg host architecture: $(uname -m)" >&2
		exit 1
		;;
esac

readonly amlimg_url="https://github.com/hzyitc/AmlImg/releases/download/v0.3.1/$amlimg_asset"

cleanup() {
	rm -rf -- "$work_dir"
}
trap cleanup EXIT

download_and_verify() {
	local url="$1"
	local destination="$2"
	local checksum="$3"

	curl --fail --location --retry 3 --retry-all-errors --silent --show-error \
		"$url" --output "$destination"
	printf '%s  %s\n' "$checksum" "$destination" | sha256sum --check --status
}

command -v img2simg >/dev/null

download_and_verify "$amlimg_url" "$work_dir/AmlImg" "$amlimg_sha256"
download_and_verify "$template_url" "$work_dir/template.img" "$template_sha256"
chmod 0755 "$work_dir/AmlImg"

"$work_dir/AmlImg" unpack "$work_dir/template.img" "$work_dir/burn"
img2simg "$boot_partition_image" "$work_dir/burn/boot.simg"
img2simg "$rootfs_image" "$work_dir/burn/rootfs.simg"

printf '%s\n' \
	'PARTITION:boot:sparse:boot.simg' \
	'PARTITION:rootfs:sparse:rootfs.simg' \
	>>"$work_dir/burn/commands.txt"

"$work_dir/AmlImg" pack "$output_image" "$work_dir/burn"

header="$(od -An -tx1 -j4 -N8 "$output_image" | tr -d '[:space:]')"
if [[ "$header" != "020000005619b527" ]]; then
	echo "Invalid Amlogic burn image header: $header" >&2
	exit 1
fi
