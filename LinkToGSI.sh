#!/bin/bash

ROM_LINK=$1
ROM_TYPE=$2
partitions="vendor system system_ext product optics prism mi_ext my_bigball my_engineering my_manifest my_region my_carrier my_heytap my_product my_stock"

if [[ -d "Tools/Firmware_extractor" ]]; then
    git -C "Tools"/Firmware_extractor fetch origin
    git -C "Tools"/Firmware_extractor reset --hard origin/master
else
    echo "Cloning Firmware_extractor..."
    git clone -q --recurse-submodules https://github.com/AndroidDumps/Firmware_extractor.git  "Tools"/Firmware_extractor
fi

usage() {
  echo "Usage: $0 [rom_link] [rom_type]"
  echo ""
  echo "Parameters:"
  echo "  rom_link  - Link to the base ROM"
  echo "  rom_type  - Type of rom"
  echo ""
  echo "Example:"
  echo "  sudo bash $0 https://dl.google.com/dl/android/aosp/redfin-tq3a.230901.001.c2-factory-ca20bd02.zip  Pixel"
  echo ""
}

supported_roms() {
    echo "Available ROMs:"
    echo ""
    declare -a versions=(15 16)
    for version in "${versions[@]}"; do
        rom_dir="ROMsPatches/$version"
        if [ -d "$rom_dir" ]; then
            names=$(find "$rom_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)
            filtered=$(echo "$names" | grep -vxF -f <(printf '%s\n' "${versions[@]}"))
            if [ -n "$filtered" ]; then
                echo "Android $version:"
                echo "$filtered" | sed 's|^|  - |' | tr '\n' '\n'
                echo ""
            fi
        fi
    done
}

if [ -z "$2" ]; then
  usage
  exit 0
fi

# --- f2fs support: pastikan tools tersedia ---
if ! command -v mount.f2fs >/dev/null 2>&1 || ! command -v fsck.f2fs >/dev/null 2>&1; then
    echo "f2fs-tools tidak ditemukan, menginstall..."
    sudo apt-get update -qq
    sudo apt-get install -y f2fs-tools
fi

rm -rf DownloadedROMs
rm -rf UnpackedROMs

mkdir -p DownloadedROMs
mkdir -p UnpackedROMs

wget -nv -P "DownloadedROMs/" "$ROM_LINK"

Tools/Firmware_extractor/extractor.sh "DownloadedROMs/"* "UnpackedROMs/"

for partition in $partitions; do
    if [[ -f "UnpackedROMs/${partition}_a.img" ]]; then
        mv "UnpackedROMs/${partition}_a.img" "UnpackedROMs/$partition.img"
    fi
done

# --- fungsi bantu: deteksi fs_type dengan fallback manual untuk f2fs ---
detect_fs_type() {
    local img="$1"
    local fs_type
    fs_type=$(blkid -o value -s TYPE "$img" 2>/dev/null)

    if [[ -z "$fs_type" ]]; then
        # blkid kadang gagal deteksi f2fs pada image sparse/truncated,
        # jadi cek magic number f2fs lewat fsck dry-run
        if fsck.f2fs -n "$img" >/dev/null 2>&1; then
            fs_type="f2fs"
        fi
    fi

    echo "$fs_type"
}

for partition in $partitions; do
    if [[ -f "UnpackedROMs/$partition.img" ]]; then
        echo "File found: UnpackedROMs/$partition.img"
        mkdir -p "UnpackedROMs/temp_mount"
        mkdir -p "UnpackedROMs/$partition"

        fs_type=$(detect_fs_type "UnpackedROMs/$partition.img")
        echo "Detected fs_type for $partition: ${fs_type:-unknown}"

        if [[ "$fs_type" == "ext2" || "$fs_type" == "ext4" ]]; then
            sudo mount -o loop,ro -t ext4 "UnpackedROMs/$partition.img" "UnpackedROMs/temp_mount"
        elif [[ "$fs_type" == "f2fs" ]]; then
            sudo mount -o loop,ro -t f2fs "UnpackedROMs/$partition.img" "UnpackedROMs/temp_mount"
        else
            sudo mount "UnpackedROMs/$partition.img" "UnpackedROMs/temp_mount"
        fi

        cp -r "UnpackedROMs/temp_mount/". "UnpackedROMs/$partition/"
        sudo umount -R "UnpackedROMs/temp_mount"
    fi
done

for partition in $partitions; do
    if [ "$partition" != "system" ]; then
        if [ -d "UnpackedROMs/system/$partition" ] && [ ! -L "UnpackedROMs/system/$partition" ]; then
            source_dir="UnpackedROMs/system/$partition"
        elif [ -d "UnpackedROMs/system/system/$partition" ] && [ ! -L "UnpackedROMs/system/system/$partition" ]; then
            source_dir="UnpackedROMs/system/system/$partition"
        else
            continue
        fi
        if [ -d "UnpackedROMs/$partition" ]; then
            echo "Moving $partition into root..."
            mv "UnpackedROMs/$partition" "$source_dir/.."
        fi
    fi
done

sudo bash ZestUITool.sh "UnpackedROMs/system" "$ROM_TYPE"
