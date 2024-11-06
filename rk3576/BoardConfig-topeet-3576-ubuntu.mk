#!/bin/bash

# Target arch
export RK_ARCH=arm64
# Uboot defconfig
export RK_UBOOT_DEFCONFIG=rk3576
# Uboot image format type: fit(flattened image tree)
export RK_UBOOT_FORMAT_TYPE=fit
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=rockchip_linux_defconfig
# Kernel defconfig fragment
export RK_KERNEL_DEFCONFIG_FRAGMENT=
# Kernel dts
export RK_KERNEL_DTS=topeet-rk3576-linux
# boot image type
export RK_BOOT_IMG=boot.img
# kernel image path
export RK_KERNEL_IMG=kernel/arch/arm64/boot/Image
# kernel image format type: fit(flattened image tree)
export RK_KERNEL_FIT_ITS=boot.its
# parameter for GPT table
export RK_PARAMETER=parameter-ubuntu-fit.txt
# 分区表对应的打包文件
export RK_PACKAGE_FILE=rk3588-package-file-ubuntu
# Buildroot config
export RK_CFG_BUILDROOT=
# Recovery config
export RK_CFG_RECOVERY=
# Recovery image format type: fit(flattened image tree)
export RK_RECOVERY_FIT_ITS=boot4recovery.its
# ramboot config
export RK_CFG_RAMBOOT=
# Pcba config
export RK_CFG_PCBA=
# Build jobs
export RK_JOBS=32
# target chip
export RK_TARGET_PRODUCT=rk3576
# Set rootfs type, including ext2 ext4 squashfs
export RK_ROOTFS_TYPE=ext4
# rootfs image path
export RK_ROOTFS_IMG=rockdev/rootfs.${RK_ROOTFS_TYPE}
# Set ramboot image type
export RK_RAMBOOT_TYPE=
# <dev>:<mount point>:<fs type>:<mount flags>:<source dir>:<image size(M|K|auto)>:[options]
export RK_EXTRA_PARTITIONS=
# OEM build on buildroot
#export RK_OEM_BUILDIN_BUILDROOT=YES
#misc image
export RK_MISC=
#choose enable distro module
export RK_DISTRO_MODULE=
# Define pre-build script for this board
export RK_BOARD_PRE_BUILD_SCRIPT=app-build.sh

# SOC
export RK_SOC=rk3576
# 定义默认rootfs为 ubuntu
export RK_ROOTFS_SYSTEM=ubuntu
# 定义默认rootfs是否为桌面版  desktop :桌面版(可替换为 xfce lxde gnome)  lite ：控制台版
export RK_ROOTFS_TARGET=xfce
# 使用exboot内核分区
export RK_EXTBOOT=true