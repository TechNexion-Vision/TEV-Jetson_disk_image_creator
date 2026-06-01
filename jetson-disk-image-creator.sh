#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: LicenseRef-NvidiaProprietary
#
# NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
# property and proprietary rights in and to this material, related
# documentation and any modifications thereto. Any use, reproduction,
# disclosure or distribution of this material and related documentation
# without an express license agreement from NVIDIA CORPORATION or
# its affiliates is strictly prohibited.

# This is a script to generate the SD card flashable image for
# jetson-xavier-nx-devkit and jetson-agx-orin-devkit platforms

set -e

function usage()
{
	if [ -n "${1}" ]; then
		echo ""
		echo "${1}"
	fi

	echo ""
	echo "Usage: ${script_name} -o <sd_blob_name> -b <board> -r <revision> -d <device> [-u PKC key file]"
	echo ""
	echo "          sd_blob_name - valid file name"
	echo ""
	echo "          board - Board name. Supported boards are:"
	echo "                  jetson-xavier-nx-devkit"
	echo "                  jetson-agx-xavier-devkit"
	echo "                  jetson-agx-orin-devkit"
	echo "                  jetson-orin-nano-devkit"
	echo "                  jetson-orin-nano-devkit-super"
	echo "                  igx-orin-safety"
	echo "                  tn-tek6100-orin-nx"
	echo "                  tn-tek6040-orin-nano"
	echo "                  tn-tek7000-orin-nx"
	echo "                  tn-tek7000-orin-nano"
	echo ""
	echo "          revision - SKU revision number"
	echo "                  jetson-xavier-nx-devkit: default"
	echo "                  jetson-agx-xavier-devkit: default"
	echo "                  jetson-agx-orin-devkit: default"
	echo "                  jetson-orin-nano-devkit: default"
	echo "                  jetson-orin-nano-devkit-super: default"
	echo "                  igx-orin-safety: default"
	echo "                  tn-tek6100-orin-nx: default"
	echo "                  tn-tek6040-orin-nano: default"
	echo "                  tn-tek7000-orin-nx: default"
	echo "                  tn-tek7000-orin-nano: default"
	echo ""
	echo "          device - Root filesystem device"
	echo "                  jetson-xavier-nx-devkit: SD/USB"
	echo "                  jetson-agx-xavier-devkit: SD/USB"
	echo "                  jetson-agx-orin-devkit: SD/USB"
	echo "                  jetson-orin-nano-devkit: SD/USB"
	echo "                  jetson-orin-nano-devkit-super: SD/USB"
	echo "                  igx-orin-safety: USB"
	echo "                  tn-tek6100-orin-nx: NVMe/USB"
	echo "                  tn-tek6040-orin-nano: NVMe/USB"
	echo "                  tn-tek7000-orin-nx: NVMe/USB"
	echo "                  tn-tek7000-orin-nano: NVMe/USB"
	echo ""
	echo "          PKC file (optional) - Private key used for signing images."
	echo ""
	echo "Examples: ${script_name} -o sep_ist.img -b igx-orin-safety -d SD"
	echo "          ${script_name} -o sd-blob.img -b jetson-xavier-nx-devkit -d SD"
	echo "          ${script_name} -o sd-blob.img -b jetson-agx-orin-devkit -d USB"
	echo "          ${script_name} -o sep_ist.img -b igx-orin-safety -d SD -u ./rsa_privkey.pem"
	echo "          ${script_name} -o tn-nvme.img -b tn-tek7000-orin-nx -d NVME"
	exit 1
}

function cleanup() {
	set +e
	if [ -n "${tmpdir}" ]; then
		umount "${tmpdir}"
		rmdir "${tmpdir}"
	fi

	if [ -n "${loop_dev}" ]; then
		losetup -d "${loop_dev}"
	fi
}
trap cleanup EXIT

function check_device()
{
	case "${board}" in
	jetson-xavier-nx-devkit)
		case "${rootfs_dev}" in
		"SD" | "sd")
			rootfs_dev="mmcblk0p1"
			;;
		"USB" | "usb")
			rootfs_dev="sda1"
			;;
		*)
			usage "Incorrect root filesystem device - Supported devices - SD, USB"
			;;
		esac
		;;
	jetson-agx-xavier-devkit)
		case "${rootfs_dev}" in
		"SD" | "sd")
			rootfs_dev="mmcblk1p1"
			;;
		"USB" | "usb")
			rootfs_dev="sda1"
			;;
		*)
			usage "Incorrect root filesystem device - Supported devices - SD, USB"
			;;
		esac
		;;
	jetson-agx-orin-devkit)
		case "${rootfs_dev}" in
		"SD" | "sd")
			rootfs_dev="mmcblk1p1"
			;;
		"USB" | "usb")
			rootfs_dev="sda1"
			;;
		*)
			usage "Incorrect root filesystem device - Supported devices - SD, USB"
			;;
		esac
		;;
	jetson-orin-nano-devkit)
		case "${rootfs_dev}" in
		"SD" | "sd")
			rootfs_dev="mmcblk0p1"
			;;
		"USB" | "usb")
			rootfs_dev="sda1"
			;;
		*)
			usage "Incorrect root filesystem device - Supported devices - SD, USB"
			;;
		esac
		;;
	jetson-orin-nano-devkit-super)
		case "${rootfs_dev}" in
		"SD" | "sd")
			rootfs_dev="mmcblk0p1"
			;;
		"USB" | "usb")
			rootfs_dev="sda1"
			;;
		*)
			usage "Incorrect root filesystem device - Supported devices - SD, USB"
			;;
		esac
		;;
	igx-orin-safety)
		case "${rootfs_dev}" in
		"SD" | "sd")
			rootfs_dev="mmcblk0p1"
			;;
		*)
			usage "Incorrect root filesystem device - Supported devices - SD"
			;;
		esac
		;;
	tn-tek*)
		is_tek_orin="yes"
		case "${rootfs_dev}" in
		"NVMe" | "nvme")
			rootfs_dev="nvme0n1p1"
			;;
		"USB" | "usb")
			rootfs_dev="sda1"
			;;
		*)
			usage "Incorrect root filesystem device - Supported devices - NVMe, USB"
			;;
		esac
		;;
	esac
}

function check_revision()
{
	if [ -n "${rev}" ]; then
		return
	fi

	case "${board}" in
	jetson-xavier-nx-devkit)
		rev="000"
		;;
	jetson-orin-nano-devkit)
		rev="300"
		;;
	jetson-orin-nano-devkit-super)
		rev="300"
		;;
	jetson-agx-orin-devkit)
		rev="500"
		;;
	esac
}

function check_pre_req()
{
	if [ "$(id -u)" -ne 0 ]; then
		usage "ERROR: This script requires root privilege"
		exit 1
	fi

	while [ -n "${1}" ]; do
		case "${1}" in
		-h | --help)
			usage
			;;
		-b | --board)
			[ -n "${2}" ] || usage "Not enough parameters"
			board="${2}"
			shift 2
			;;
		-o | --outname)
			[ -n "${2}" ] || usage "Not enough parameters"
			sd_blob_name="${2}"
			shift 2
			;;
		-r | --revision)
			[ -n "${2}" ] || usage "Not enough parameters"
			rev="${2}"
			shift 2
			;;
		-d | --device)
			[ -n "${2}" ] || usage "Not enough parameters"
			rootfs_dev="${2}"
			shift 2
			;;
		-u)
			[ -n "${2}" ] || usage "Not enough parameters"
			pkc_file="${2}"
			shift 2
			;;
		*)
			usage "Unknown option: ${1}"
			;;
		esac
	done

	if [ "${board}" == "" ]; then
		echo "ERROR: Invalid board name" > /dev/stderr
		usage
	else
		case "${board}" in
		jetson-xavier-nx-devkit)
			boardid="3668"
			target="jetson-xavier-nx-devkit"
			storage="sdcard"
			;;
		jetson-agx-xavier-devkit)
			boardid="2888"
			target="jetson-agx-xavier-devkit"
			storage="sdmmc_user"
			;;
		jetson-agx-orin-devkit)
			boardid="3701"
			boardsku="0005"
			target="jetson-agx-orin-devkit"
			storage="sdmmc_user"
			;;
		jetson-orin-nano-devkit)
			boardid="3767"
			boardsku="0005"
			target="jetson-orin-nano-devkit"
			storage="sdcard"
			;;
		jetson-orin-nano-devkit-super)
			boardid="3767"
			boardsku="0005"
			target="jetson-orin-nano-devkit-super"
			storage="sdcard"
			;;
		igx-orin-safety)
			target="igx-orin-safety"
			storage="sdmmc_user"
			;;
		tn-tek6100-orin-nx)
			boardid="3767"
			boardsku="0000"
			target="tn-tek6100-orin-nx"
			storage="sdcard"
			;;
		tn-tek6040-orin-nano)
			boardid="3767"
			boardsku="0003"
			target="tn-tek6040-orin-nano"
			storage="sdcard"
			;;
		tn-tek7000-orin-nx)
			boardid="3767"
			boardsku="0000"
			target="tn-tek7000-orin-nx"
			storage="sdcard"
			;;
		tn-tek7000-orin-nano)
			boardid="3767"
			boardsku="0003"
			target="tn-tek7000-orin-nano"
			storage="sdcard"
			;;
		*)
			usage "Unknown board: ${board}"
			;;
		esac
	fi

	check_revision
	check_device

	if [ "${sd_blob_name}" == "" ]; then
		echo "ERROR: Invalid SD blob image name" > /dev/stderr
		usage
	fi

	if [ ! -f "${l4t_dir}/flash.sh" ]; then
		echo "ERROR: ${l4t_dir}/flash.sh is not found" > /dev/stderr
		usage
	fi

	if [ ! -f "${l4t_tools_dir}/nvptparser.py" ]; then
		echo "ERROR: ${l4t_tools_dir}/nvptparser.py is not found" > /dev/stderr
		usage
	fi

	if [ ! -d "${bootloader_dir}" ]; then
		echo "ERROR: ${bootloader_dir} directory not found" > /dev/stderr
		usage
	fi

	if [ ! -d "${rfs_dir}" ]; then
		echo "ERROR: ${rfs_dir} directory not found" > /dev/stderr
		usage
	fi

	if [ -n "${pkc_file}" ] && [ ! -f "${pkc_file}" ] ; then
		usage "ERROR: PKC private key '${pkc_file}' file not found."
	fi
}

function create_raw_image()
{
	# Calulate raw image size by accumulating partition size with 1MB (2048-sector * 512) round up and plus 2MB for GPTs
	sd_blob_size=$("${l4t_tools_dir}/nvptparser.py" "${signed_image_dir}/${signed_cfg}" "${storage}" | awk -F'[=;]' '{sum += (int($6 / (2048 * 512)) + 1)} END {printf "%dM\n", sum + 2}')
	echo "${script_name} - creating ${sd_blob_name} of ${sd_blob_size}..."
	dd if=/dev/zero of="${sd_blob_name}" bs=1 count=0 seek="${sd_blob_size}"
}

function change_nvme_cfg_to_sd()
{
	echo 'EMMC_CFG="flash_t234_qspi_sd.xml";' >> ${target}.conf
	echo 'BOARDSKU="0005"' >> ${target}.conf
}


function restore_nvme_cfg()
{
	sed -i -e '$ d' ${target}.conf
	sed -i -e '$ d' ${target}.conf
}

function create_signed_images()
{
	echo "${script_name} - creating signed images"

	pushd "${l4t_dir}"
	# rootfs size = rfs_dir size + extra 10% for ext4 metadata and safety margin
	rootfs_size=$(du -ms "${rfs_dir}" | awk '{print $1}')
	rootfs_size=$((rootfs_size + (rootfs_size / 10) + 100))

	if [[ ${is_tek_orin} == "yes" ]];then
		change_nvme_cfg_to_sd
	fi
	# Generate signed images
	flash_env_args="BOARDID=${boardid} BOARDSKU=${boardsku} FAB=${rev} BUILD_SD_IMAGE=1 BOOTDEV=${rootfs_dev} "
	flash_cmd_args="--no-flash --sign -S ${rootfs_size}MiB "
	if [ -n "${pkc_file}" ]; then
		flash_cmd_args+="-u ${pkc_file} "
	fi

	flash_cmd="${flash_env_args} ${l4t_dir}/flash.sh ${flash_cmd_args} ${target} ${rootfs_dev}"
	echo -e "${flash_cmd}\r\n"
	if ! eval "${flash_cmd}"; then
		echo "FAILURE: ${flash_cmd}"
		exit 1
	fi
	popd

	if [[ ${is_tek_orin} == "yes" ]];then
		restore_nvme_cfg
	fi

	if [ ! -f "${bootloader_dir}/flashcmd.txt" ]; then
		echo "ERROR: ${bootloader_dir}/flashcmd.txt not found" > /dev/stderr
		exit 1
	fi

	if [ ! -d "${signed_image_dir}" ]; then
		echo "ERROR: ${bootloader_dir}/signed directory not found" > /dev/stderr
		exit 1
	fi

	chipid=$(sed -nr 's/.*chip ([^ ]*).*/\1/p' "${bootloader_dir}/flashcmd.txt")
	if [ "${chipid}" = "0x21" ]; then
		signed_cfg="flash.xml"
	else
		signed_cfg="flash.xml.tmp"
	fi

	if [ ! -f "${signed_image_dir}/${signed_cfg}" ]; then
		echo "ERROR: ${signed_image_dir}/${signed_cfg} not found" > /dev/stderr
		exit 1
	fi
}

function create_partitions()
{
	echo "${script_name} - create partitions"

	partitions=($("${l4t_tools_dir}/nvptparser.py" "${signed_image_dir}/${signed_cfg}" "${storage}"))

	sgdisk -og "${sd_blob_name}"
	for part in "${partitions[@]}"; do
		eval "${part}"
		if [ "${part_name}" = "master_boot_record" ]; then
			continue
		fi
		part_size=$((${part_size} / 512)) # convert to sectors
		sgdisk -n "${part_num}":0:+"${part_size}" \
			-c "${part_num}":"${part_name}" \
			-t "${part_num}":"${part_type}" "${sd_blob_name}"
	done
}

function write_partitions()
{
	echo "${script_name} - write partitions"
	(sleep 1; echo "p")|sudo fdisk "${sd_blob_name}" > fdisk_info.txt

	for part in "${partitions[@]}"; do
		eval "${part}"
		target_file=""
		if [ "${part_name}" = "APP" ]; then
			target_file="${bootloader_dir}/${part_file}.raw"
		elif [ -e "${signed_image_dir}/${part_file}" ]; then
			target_file="${signed_image_dir}/${part_file}"
		elif [ -e "${bootloader_dir}/${part_file}" ]; then
			target_file="${bootloader_dir}/${part_file}"
		fi

		if [ "${part_name}" = "master_boot_record" ]; then
			dd conv=notrunc if="${signed_image_dir}/${part_file}" of="${sd_blob_name}" bs="${part_size}" count=1
			continue
		fi

		if [ "${target_file}" != "" ] && [ "${part_file}" != "" ]; then
			SEEK_NUM=$(cat fdisk_info.txt |tr -s ' '|grep -P ".img${part_num} "| cut -d ' ' -f 2)
			echo "${script_name} - writing ${target_file}", part_num=${part_num}, SEEK_NUM=${SEEK_NUM}
			sudo dd if="${target_file}" of="${sd_blob_name}" bs=512 seek=${SEEK_NUM} conv=notrunc
		fi
	done

	rm fdisk_info.txt
}

boardsku=""
sd_blob_name=""
sd_blob_size=""
script_name="$(basename "${0}")"
l4t_tools_dir="$(cd "$(dirname "${0}")" && pwd)"
l4t_dir="${l4t_tools_dir%/*}"
if [ -z "${ROOTFS_DIR}" ]; then
	rfs_dir="${l4t_dir}/rootfs"
else
	rfs_dir="${ROOTFS_DIR}"
fi
bootloader_dir="${l4t_dir}/bootloader"
signed_image_dir="${bootloader_dir}/signed"
loop_dev=""
tmpdir=""

echo "********************************************"
echo "     Jetson Disk Image Creation Tool     "
echo "********************************************"

check_pre_req "${@}"
create_signed_images
create_raw_image
create_partitions
write_partitions

echo "********************************************"
echo "   Jetson Disk Image Creation Complete   "
echo "********************************************"
