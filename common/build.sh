#!/bin/bash

export LC_ALL=C
export LD_LIBRARY_PATH=
unset RK_CFG_TOOLCHAIN

err_handler() {
	ret=$?
	[ "$ret" -eq 0 ] && return

	echo "ERROR: Running ${FUNCNAME[1]} failed!"
	echo "ERROR: exit code $ret from line ${BASH_LINENO[0]}:"
	echo "    $BASH_COMMAND"
	exit $ret
}
trap 'err_handler' ERR
set -eE

function finish_build(){
	echo "Running ${FUNCNAME[1]} succeeded."
	cd $TOP_DIR
}

function check_config(){
	unset missing
	for var in $@; do
		eval [ \$$var ] && continue

		missing="$missing $var"
	done

	[ -z "$missing" ] && return 0

	echo "Skipping ${FUNCNAME[1]} for missing configs: $missing."
	return 1
}

function choose_target_board()
{
	echo
	echo "You're building on Linux"
	echo "Lunch menu...pick a combo:"
	echo ""

	echo "0. default BoardConfig.mk"
	echo ${RK_TARGET_BOARD_ARRAY[@]} | xargs -n 1 | sed "=" | sed "N;s/\n/. /"

	local INDEX
	read -p "Which would you like? [0]: " INDEX
	INDEX=$((${INDEX:-0} - 1))

	if echo $INDEX | grep -vq [^0-9]; then
		RK_BUILD_TARGET_BOARD="${RK_TARGET_BOARD_ARRAY[$INDEX]}"
	else
		echo "Lunching for Default BoardConfig.mk boards..."
		RK_BUILD_TARGET_BOARD=BoardConfig.mk
	fi
}

function build_select_board()
{
	RK_TARGET_BOARD_ARRAY=( $(cd ${TARGET_PRODUCT_DIR}/; ls BoardConfig*.mk | sort) )

	RK_TARGET_BOARD_ARRAY_LEN=${#RK_TARGET_BOARD_ARRAY[@]}
	if [ $RK_TARGET_BOARD_ARRAY_LEN -eq 0 ]; then
		echo "No available Board Config"
		return
	fi

	choose_target_board

	ln -rfs $TARGET_PRODUCT_DIR/$RK_BUILD_TARGET_BOARD device/rockchip/.BoardConfig.mk
	echo "switching to board: `realpath $BOARD_CONFIG`"
}

function unset_board_config_all()
{
	local tmp_file=`mktemp`
	grep -oh "^export.*RK_.*=" `find device -name "Board*.mk"` > $tmp_file
	source $tmp_file
	rm -f $tmp_file
}

CMD=`realpath $0`
COMMON_DIR=`dirname $CMD`
TOP_DIR=$(realpath $COMMON_DIR/../../..)
cd $TOP_DIR

BOARD_CONFIG=$TOP_DIR/device/rockchip/.BoardConfig.mk
TARGET_PRODUCT="$TOP_DIR/device/rockchip/.target_product"
TARGET_PRODUCT_DIR=$(realpath ${TARGET_PRODUCT})

if [ ! -L "$BOARD_CONFIG" -a  "$1" != "lunch" ]; then
	build_select_board
fi
unset_board_config_all
[ -L "$BOARD_CONFIG" ] && source $BOARD_CONFIG

function prebuild_uboot()
{
	UBOOT_COMPILE_COMMANDS="\
			${RK_TRUST_INI_CONFIG:+../rkbin/RKTRUST/$RK_TRUST_INI_CONFIG} \
			${RK_SPL_INI_CONFIG:+../rkbin/RKBOOT/$RK_SPL_INI_CONFIG} \
			${RK_UBOOT_SIZE_CONFIG:+--sz-uboot $RK_UBOOT_SIZE_CONFIG} \
			${RK_TRUST_SIZE_CONFIG:+--sz-trust $RK_TRUST_SIZE_CONFIG}"
	UBOOT_COMPILE_COMMANDS="$(echo $UBOOT_COMPILE_COMMANDS)"

	if [ "$RK_LOADER_UPDATE_SPL" = "true" ]; then
		UBOOT_COMPILE_COMMANDS="--spl-new $UBOOT_COMPILE_COMMANDS"
		UBOOT_COMPILE_COMMANDS="$(echo $UBOOT_COMPILE_COMMANDS)"
	fi

	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		UBOOT_COMPILE_COMMANDS=" \
			$UBOOT_COMPILE_COMMANDS \
			${RK_ROLLBACK_INDEX_BOOT:+--rollback-index-boot $RK_ROLLBACK_INDEX_BOOT} \
			${RK_ROLLBACK_INDEX_UBOOT:+--rollback-index-uboot $RK_ROLLBACK_INDEX_UBOOT} "
	fi
}

function prebuild_security_uboot()
{
	local mode=$1

	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		if [ "$RK_SECURITY_OTP_DEBUG" != "true" ]; then
			UBOOT_COMPILE_COMMANDS="$UBOOT_COMPILE_COMMANDS --burn-key-hash"
		fi

		case "${mode:-normal}" in
			uboot)
				;;
			boot)
				UBOOT_COMPILE_COMMANDS=" \
					--boot_img $TOP_DIR/u-boot/boot.img \
					$UBOOT_COMPILE_COMMANDS "
				;;
			recovery)
				UBOOT_COMPILE_COMMANDS=" \
					--recovery_img $TOP_DIR/u-boot/recovery.img
					$UBOOT_COMPILE_COMMANDS "
				;;
			*)
				UBOOT_COMPILE_COMMANDS=" \
					--boot_img $TOP_DIR/u-boot/boot.img \
					$UBOOT_COMPILE_COMMANDS "
				test -z "${RK_PACKAGE_FILE_AB}" && \
					UBOOT_COMPILE_COMMANDS="$UBOOT_COMPILE_COMMANDS --recovery_img $TOP_DIR/u-boot/recovery.img"
				;;
		esac

		UBOOT_COMPILE_COMMANDS="$(echo $UBOOT_COMPILE_COMMANDS)"
	fi
}

function usagekernel()
{
	check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

	echo "cd kernel"
	echo "make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "make ARCH=$RK_ARCH $RK_KERNEL_DTS.img -j$RK_JOBS"
}


function usage()
{
	echo "Usage: build.sh [OPTIONS]"
	echo "Available options:"
	echo "BoardConfig*.mk    -switch to specified board config"
	echo "lunch              -list current SDK boards and switch to specified board config"
	echo "uboot              -build uboot"
	echo "kernel             -build kernel"
	echo "kerneldeb          -build kernel deb"
	echo "modules            -build kernel modules"
	echo "toolchain          -build toolchain"
	echo "extboot            -build extlinux boot.img, boot from EFI partition"
	echo "rootfs             -build default rootfs"
	echo "ubuntu             -build ubuntu rootfs"
	echo "debian             -build debian rootfs"
	echo "all                -build uboot, kernel, rootfs, recovery image"
	echo "cleanall           -clean uboot, kernel, rootfs, recovery"
	echo "firmware           -pack all the image we need to boot up system"
	echo "updateimg          -pack update image"
	echo "save               -save images, patches, commands used to debug"
	echo "allsave            -build all & firmware & updateimg & save"
	echo "check              -check the environment of building"
	echo "info               -see the current board building information"
	echo ""
	echo ""
	echo "Default option is 'allsave'."
}

function build_info(){
	if [ ! -L $TARGET_PRODUCT_DIR ];then
		echo "No found target product!!!"
	fi
	if [ ! -L $BOARD_CONFIG ];then
		echo "No found target board config!!!"
	fi

	if [ -f .repo/manifest.xml ]; then
		local sdk_ver=""
		sdk_ver=`grep "include name"  .repo/manifest.xml | awk -F\" '{print $2}'`
		sdk_ver=`realpath .repo/manifests/${sdk_ver}`
		echo "Build SDK version: `basename ${sdk_ver}`"
	else
		echo "Not found .repo/manifest.xml [ignore] !!!"
	fi

	echo "Current Building Information:"
	echo "Target Product: $TARGET_PRODUCT_DIR"
	echo "Target BoardConfig: `realpath $BOARD_CONFIG`"
	echo "Target Misc config:"
	echo "`env |grep "^RK_" | grep -v "=$" | sort`"

	local kernel_file_dtb

	if [ "$RK_ARCH" == "arm" ]; then
		kernel_file_dtb="${TOP_DIR}/kernel/arch/arm/boot/dts/${RK_KERNEL_DTS}.dtb"
	else
		kernel_file_dtb="${TOP_DIR}/kernel/arch/arm64/boot/dts/rockchip/${RK_KERNEL_DTS}.dtb"
	fi

	rm -f $kernel_file_dtb

	cd kernel
	make ARCH=$RK_ARCH dtbs -j$RK_JOBS

}

function build_check_cross_compile(){

	case $RK_ARCH in
	arm|armhf)
		if [ -d "$TOP_DIR/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf" ]; then
			CROSS_COMPILE=$(realpath $TOP_DIR)/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
		export CROSS_COMPILE=$CROSS_COMPILE
		fi
		;;
	arm64|aarch64)
		if [ -d "$TOP_DIR/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu" ]; then
			CROSS_COMPILE=$(realpath $TOP_DIR)/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
		export CROSS_COMPILE=$CROSS_COMPILE
		fi
		;;
	*)
		echo "the $RK_ARCH not supported for now, please check it again\n"
		;;
	esac
}

function build_check(){
	local build_depend_cfg="build-depend-tools.txt"
	common_product_build_tools="device/rockchip/common/$build_depend_cfg"
	target_product_build_tools="device/rockchip/$RK_TARGET_PRODUCT/$build_depend_cfg"
	cat $common_product_build_tools $target_product_build_tools 2>/dev/null | while read chk_item
		do
			chk_item=${chk_item###*}
			if [ -z "$chk_item" ]; then
				continue
			fi

			dst=${chk_item%%,*}
			src=${chk_item##*,}
			echo "**************************************"
			if eval $dst &>/dev/null;then
				echo "Check [OK]: $dst"
			else
				echo "Please install ${dst%% *} first"
				echo "    sudo apt-get install $src"
			fi
		done
}


function build_uboot(){
	check_config RK_UBOOT_DEFCONFIG || return 0
	build_check_cross_compile
	prebuild_uboot
	prebuild_security_uboot $@

	echo "============Start building uboot============"
	echo "TARGET_UBOOT_CONFIG=$RK_UBOOT_DEFCONFIG"
	echo "========================================="

	cd u-boot
	rm -f *_loader_*.bin
	if [ "$RK_LOADER_UPDATE_SPL" = "true" ]; then
		rm -f *spl.bin
	fi

	if [ -n "$RK_UBOOT_DEFCONFIG_FRAGMENT" ]; then
		if [ -f "configs/${RK_UBOOT_DEFCONFIG}_defconfig" ]; then
			make ${RK_UBOOT_DEFCONFIG}_defconfig $RK_UBOOT_DEFCONFIG_FRAGMENT
		else
			make ${RK_UBOOT_DEFCONFIG}.config $RK_UBOOT_DEFCONFIG_FRAGMENT
		fi
		./make.sh $UBOOT_COMPILE_COMMANDS
	elif [ -d "$TOP_DIR/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf" ]; then
		./make.sh $RK_UBOOT_DEFCONFIG \
			$UBOOT_COMPILE_COMMANDS CROSS_COMPILE=$CROSS_COMPILE
	elif [ -d "$TOP_DIR/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu" ]; then
		./make.sh $RK_UBOOT_DEFCONFIG \
			$UBOOT_COMPILE_COMMANDS CROSS_COMPILE=$CROSS_COMPILE
	else
		./make.sh $RK_UBOOT_DEFCONFIG \
			$UBOOT_COMPILE_COMMANDS
	fi

	if [ "$RK_IDBLOCK_UPDATE_SPL" = "true" ]; then
		./make.sh --idblock --spl
	fi

	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		ln -rsf $TOP_DIR/u-boot/boot.img $TOP_DIR/rockdev/
		test -z "${RK_PACKAGE_FILE_AB}" && \
			ln -rsf $TOP_DIR/u-boot/recovery.img $TOP_DIR/rockdev/ || true
	fi

	finish_build
}

function build_kernel(){
	check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

	echo "============Start building kernel============"
	echo "TARGET_RK_JOBS       =$RK_JOBS"
	echo "TARGET_ARCH          =$RK_ARCH"
	echo "TARGET_KERNEL_CONFIG =$RK_KERNEL_DEFCONFIG"
	echo "TARGET_KERNEL_DTS    =$RK_KERNEL_DTS"
	echo "TARGET_KERNEL_CONFIG_FRAGMENT =$RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "=========================================="

	build_check_cross_compile

	cd kernel
	make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT
	make ARCH=$RK_ARCH $RK_KERNEL_DTS.img -j$RK_JOBS
	# make ARCH=$RK_ARCH -j$RK_JOBS
	if [ -f "$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_KERNEL_FIT_ITS" ]; then
		$COMMON_DIR/mk-fitimage.sh $TOP_DIR/kernel/$RK_BOOT_IMG \
			$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_KERNEL_FIT_ITS
	fi

	if [ -f "$TOP_DIR/kernel/$RK_BOOT_IMG" ]; then
		mkdir -p $TOP_DIR/rockdev
		ln -sf  $TOP_DIR/kernel/$RK_BOOT_IMG $TOP_DIR/rockdev/boot.img
	fi

	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		cp $TOP_DIR/kernel/$RK_BOOT_IMG \
			$TOP_DIR/u-boot/boot.img
	fi

	# build_check_power_domain

	finish_build
}

function build_kerneldeb(){
	check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

	build_check_cross_compile

	echo "============Start building kernel deb============"
	echo "TARGET_ARCH          =$RK_ARCH"
	echo "TARGET_KERNEL_CONFIG =$RK_KERNEL_DEFCONFIG"
	echo "TARGET_KERNEL_DTS    =$RK_KERNEL_DTS"
	echo "TARGET_KERNEL_CONFIG_FRAGMENT =$RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "=========================================="
	pwd

	rm -f linux-*.buildinfo linux-*.changes
	rm -f linux-headers-*.deb linux-image-*.deb linux-libc-dev*.deb

	cd kernel
	make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT
	make ARCH=$RK_ARCH bindeb-pkg RK_KERNEL_DTS=$RK_KERNEL_DTS -j$RK_JOBS
	finish_build
}

# 编译用于extLinux启动的内核镜像
function build_extboot(){
	# 检查是否配置了RK_KERNEL_DTS和RK_KERNEL_DEFCONFIG，如果没有则返回0
	check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

	# 打印编译内核的相关信息
	echo "============开始编译内核============"
	echo "目标架构          =$RK_ARCH"
	echo "内核配置          =$RK_KERNEL_DEFCONFIG"
	echo "内核设备树        =$RK_KERNEL_DTS"
	echo "内核配置片段      =$RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "====================================="
	
	# 输出当前目录路径
	pwd

	# 检查交叉编译工具链是否可用
	build_check_cross_compile

	# 进入内核目录
	cd kernel
	# 编译内核配置
	make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT
	# 编译设备树镜像，使用并行作业
	make ARCH=$RK_ARCH $RK_KERNEL_DTS.img -j$RK_JOBS
	# 编译设备树文件
	make ARCH=$RK_ARCH dtbs -j$RK_JOBS
	
	echo -e "\e[36m 生成extLinuxBoot镜像开始 \e[0m"

    # 获取内核版本号
    KERNEL_VERSION=$(cat $TOP_DIR/kernel/include/config/kernel.release)

    # 定义extboot镜像和相关目录
    EXTBOOT_IMG=${TOP_DIR}/kernel/extboot.img
    EXTBOOT_DIR=${TOP_DIR}/kernel/extboot
    EXTBOOT_DTB=${EXTBOOT_DIR}/dtb/

    # 清理并创建extboot目录结构
    rm -rf $EXTBOOT_DIR
    mkdir -p $EXTBOOT_DIR
    mkdir -p $EXTBOOT_DTB
	mkdir -p $EXTBOOT_DIR/uEnv
	mkdir -p $EXTBOOT_DIR/kerneldeb

    # 复制内核镜像
    cp ${TOP_DIR}/$RK_KERNEL_IMG $EXTBOOT_DIR/Image-$KERNEL_VERSION

	# 配置extlinux启动项
	mkdir -p $EXTBOOT_DIR/extlinux
	echo -e "label kernel-$KERNEL_VERSION" >> $EXTBOOT_DIR/extlinux/extlinux.conf
	echo -e "\tkernel /Image-$KERNEL_VERSION" >> $EXTBOOT_DIR/extlinux/extlinux.conf
	echo -e "\tfdt /rk-kernel.dtb" >> $EXTBOOT_DIR/extlinux/extlinux.conf
	echo -e "\tappend  root=/dev/mmcblk0p3 earlyprintk console=ttyFIQ0 console=tty1 consoleblank=0 loglevel=7 rootwait rw rootfstype=ext4 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 switolb=1 coherent_pool=1m" >> $EXTBOOT_DIR/extlinux/extlinux.conf

	# 根据架构选择合适的设备树和覆盖文件
	cp ${TOP_DIR}/kernel/arch/${RK_ARCH}/boot/dts/rockchip/*.dtb $EXTBOOT_DTB
	cp ${TOP_DIR}/kernel/arch/${RK_ARCH}/boot/dts/rockchip/uEnv/uEnv*.txt $EXTBOOT_DIR/uEnv
	cp ${TOP_DIR}/kernel/arch/${RK_ARCH}/boot/dts/rockchip/uEnv/boot.cmd $EXTBOOT_DIR/

	# 复制设备树文件
	cp -f $EXTBOOT_DTB/${RK_KERNEL_DTS}.dtb $EXTBOOT_DIR/rk-kernel.dtb
	cp ${TOP_DIR}/kernel/arch/${RK_ARCH}/boot/dts/rockchip/uEnv/uEnv*.txt $EXTBOOT_DIR/uEnv
	cp ${TOP_DIR}/kernel/arch/${RK_ARCH}/boot/dts/rockchip/uEnv/boot.cmd $EXTBOOT_DIR/

	# 如果存在initrd文件，则复制到extboot目录
	cp ${TOP_DIR}/initrd/* $EXTBOOT_DIR/

	# 如果存在boot.cmd文件，则生成boot.scr启动脚本
	if [[ -e $EXTBOOT_DIR/boot.cmd ]]; then
		${TOP_DIR}/u-boot/tools/mkimage -T script -C none -d $EXTBOOT_DIR/boot.cmd $EXTBOOT_DIR/boot.scr
	fi

	# 复制其他内核相关文件
	cp ${TOP_DIR}/kernel/.config $EXTBOOT_DIR/config-$KERNEL_VERSION
	cp ${TOP_DIR}/kernel/System.map $EXTBOOT_DIR/System.map-$KERNEL_VERSION
	cp ${TOP_DIR}/kernel/logo_kernel.bmp $EXTBOOT_DIR/
	cp ${TOP_DIR}/kernel/logo_boot.bmp $EXTBOOT_DIR/logo.bmp

	# 复制生成的Debian包
	cp ${TOP_DIR}/linux-headers-"$KERNEL_VERSION"_"$KERNEL_VERSION"-*.deb $EXTBOOT_DIR/kerneldeb
	cp ${TOP_DIR}/linux-image-"$KERNEL_VERSION"_"$KERNEL_VERSION"-*.deb $EXTBOOT_DIR/kerneldeb
	
	# 清理并生成ext2格式的extboot镜像
	rm -rf $EXTBOOT_IMG && truncate -s 128M $EXTBOOT_IMG
	fakeroot mkfs.ext2 -F -L "boot" -d $EXTBOOT_DIR $EXTBOOT_IMG

	# 完成构建
	finish_build
}

function build_modules(){
	check_config RK_KERNEL_DEFCONFIG || return 0

	echo "============Start building kernel modules============"
	echo "TARGET_RK_JOBS       =$RK_JOBS"
	echo "TARGET_ARCH          =$RK_ARCH"
	echo "TARGET_KERNEL_CONFIG =$RK_KERNEL_DEFCONFIG"
	echo "TARGET_KERNEL_CONFIG_FRAGMENT =$RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "=================================================="

	build_check_cross_compile

	cd kernel
	make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT
	make ARCH=$RK_ARCH modules -j$RK_JOBS

	finish_build
}



function build_ubuntu(){
	ARCH=${RK_UBUNTU_ARCH:-${RK_ARCH}}
	case $ARCH in
		arm|armhf) ARCH=armhf ;;
		*) ARCH=arm64 ;;
	esac

	echo "=========Start building ubuntu for $ARCH========="
	echo "==RK_ROOTFS_DEBUG:$RK_ROOTFS_DEBUG RK_ROOTFS_TARGET:$RK_ROOTFS_TARGET=="
	cd ubuntu


	if [ ! -e ubuntu-$RK_ROOTFS_TARGET-rootfs.img ]; then
		echo "[ No ubuntu-$RK_ROOTFS_TARGET-rootfs.img, Run Make Ubuntu Scripts ]"
		if [ ! -e ubuntu-base-$RK_ROOTFS_TARGET-$ARCH-*.tar.gz ]; then
			ARCH=arm64 TARGET=$RK_ROOTFS_TARGET ./mk-base-ubuntu.sh
		fi

		VERSION=$RK_ROOTFS_DEBUG TARGET=$RK_ROOTFS_TARGET ARCH=$ARCH SOC=$RK_SOC ./mk-ubuntu-rootfs.sh
	else
		echo "[    Already Exists IMG,  Skip Make Ubuntu Scripts    ]"
		echo "[ Delate Ubuntu-$RK_ROOTFS_TARGET-rootfs.img To Rebuild Ubuntu IMG ]"
	fi

	finish_build
}

function build_debian(){
	ARCH=${RK_DEBIAN_ARCH:-${RK_ARCH}}
	case $ARCH in
		arm|armhf) ARCH=armhf ;;
		*) ARCH=arm64 ;;
	esac

	echo "=========Start building debian for $ARCH========="
	echo "RK_DEBIAN_VERSION: $RK_DEBIAN_VERSION"
	echo "RK_ROOTFS_TARGET: $RK_ROOTFS_TARGET"
	echo "RK_ROOTFS_DEBUG: $RK_ROOTFS_DEBUG"
	echo " "

	cd debian

	if [[ "$RK_DEBIAN_VERSION" == "stretch" || "$RK_DEBIAN_VERSION" == "9" ]]; then
		RELEASE='stretch'
	elif [[ "$RK_DEBIAN_VERSION" == "buster" || "$RK_DEBIAN_VERSION" == "10" ]]; then
		RELEASE='buster'
	elif [[ "$RK_DEBIAN_VERSION" == "bullseye" || "$RK_DEBIAN_VERSION" == "11" ]]; then
		RELEASE='bullseye'
	else
		echo -e "\033[36m please input the os type,stretch or buster...... \033[0m"
	fi

	if [ ! -e linaro-$RK_ROOTFS_TARGET-rootfs.img ]; then
		echo "[ No linaro-$RK_ROOTFS_TARGET-rootfs.img, Run Make Debian Scripts ]"
		if [ ! -e linaro-$RELEASE-$RK_ROOTFS_TARGET-alip-*.tar.gz ]; then
			echo "[ build linaro-$RELEASE-$RK_ROOTFS_TARGET-alip-*.tar.gz ]"
			RELEASE=$RELEASE TARGET=$RK_ROOTFS_TARGET ARCH=$ARCH ./mk-base-debian.sh
		fi

		RELEASE=$RELEASE TARGET=$RK_ROOTFS_TARGET VERSION=$RK_ROOTFS_DEBUG SOC=$RK_SOC ARCH=$ARCH ./mk-rootfs.sh
	else
		echo "[    Already Exists IMG,  Skip Make Debian Scripts    ]"
		echo "[ Delate linaro-$RK_ROOTFS_TARGET-rootfs.img To Rebuild Debian IMG ]"
	fi


	finish_build
}

function build_rootfs(){
	check_config RK_ROOTFS_IMG || return 0

	RK_ROOTFS_DIR=.rootfs
	ROOTFS_IMG=${RK_ROOTFS_IMG##*/}

	rm -rf $RK_ROOTFS_IMG $RK_ROOTFS_DIR
	mkdir -p ${RK_ROOTFS_IMG%/*} $RK_ROOTFS_DIR

	case "$1" in
		ubuntu)
			build_ubuntu
			ln -rsf ubuntu/ubuntu-$RK_ROOTFS_TARGET-rootfs.img \
				$RK_ROOTFS_DIR/rootfs.ext4
			;;
		debian)
			build_debian
			ln -rsf debian/linaro-$RK_ROOTFS_TARGET-rootfs.img \
				$RK_ROOTFS_DIR/rootfs.ext4
			;;
	esac

	if [ ! -f "$RK_ROOTFS_DIR/$ROOTFS_IMG" ]; then
		echo "There's no $ROOTFS_IMG generated..."
		exit 1
	fi

	ln -rsf $RK_ROOTFS_DIR/$ROOTFS_IMG $RK_ROOTFS_IMG

	finish_build
}

function defconfig_check() {
	# 1. defconfig 2. fixed config
	echo debug-$1
	for i in $2
	do
		echo "look for $i"
		result=$(cat $1 | grep "${i}=y" -w || echo "No found")
		if [ "$result" = "No found" ]; then
			echo -e "\e[41;1;37mSecurity: No found config ${i} in $1 \e[0m"
			echo "make sure your config include this list"
			echo "---------------------------------------"
			echo "$2"
			echo "---------------------------------------"
			return -1;
		fi
	done
	return 0
}

function find_string_in_config(){
	result=$(cat "$2" | grep "$1" || echo "No found")
	if [ "$result" = "No found" ]; then
		echo "Security: No found string $1 in $2"
		return -1;
	fi
	return 0;
}


function build_all(){
    echo "============================================"
    echo "TARGET_ARCH=$RK_ARCH"
    echo "TARGET_PLATFORM=$RK_TARGET_PRODUCT"
    echo "TARGET_UBOOT_CONFIG=$RK_UBOOT_DEFCONFIG"
    echo "TARGET_SPL_CONFIG=$RK_SPL_DEFCONFIG"
    echo "TARGET_KERNEL_CONFIG=$RK_KERNEL_DEFCONFIG"
    echo "TARGET_KERNEL_DTS=$RK_KERNEL_DTS"
    echo "TARGET_TOOLCHAIN_CONFIG=$RK_CFG_TOOLCHAIN"
    echo "============================================"

    # NOTE: On secure boot-up world, if the images build with fit(flattened image tree)
    #       we will build kernel and ramboot firstly,
    #       and then copy images into u-boot to sign the images.
    if [ "$RK_RAMDISK_SECURITY_BOOTUP" != "true" ]; then
        # note: if build spl, it will delete loader.bin in uboot directory,
        # so can not build uboot and spl at the same time.

        build_uboot

        if [ "$RK_EXTBOOT" = "true" ]; then
            build_kerneldeb
            build_extboot
        else
            build_kernel
        fi
    fi

    build_rootfs ${RK_ROOTFS_SYSTEM:-ubuntu}

    build_uboot

    finish_build
}


function build_cleanall(){
	echo "clean uboot, kernel, rootfs, recovery"

	cd u-boot
	make distclean
	cd -
	cd kernel
	make distclean
	cd -
	rm -rf debian/binary
	rm -rf ubuntu/binary

	finish_build
}

function build_firmware(){
	./mkfirmware.sh $BOARD_CONFIG

	finish_build
}

function build_updateimg(){
	IMAGE_PATH=$TOP_DIR/rockdev
	PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware

	DATE=$(date  +%Y%m%d)
 	TARGET=$(echo $RK_ROOTFS_TARGET | sed -e "s/\b\(.\)/\u\1/g")

	if [ "${RK_ROOTFS_SYSTEM}" != "debian" ];then
		Version="ubuntu"$RK_UBUNTU_VERSION"-"$RK_ROOTFS_TARGET"-"$DATE
	else
		Version="debian"$RK_DEBIAN_VERSION"-"$RK_ROOTFS_TARGET"-"$DATE
	fi

	Device_Name=$RK_PKG_NAME
	ZIP_NAME=$Device_Name"-"$Version

	cd $IMAGE_PATH
	mkdir -p mount-tmp
	echo mount and write build info
	sudo mount rootfs.img mount-tmp/
	sudo sh -c "echo ' * $ZIP_NAME' > mount-tmp/etc/build-release"
	sudo sync 
	sudo umount mount-tmp/
	rm -rf mount-tmp/

	cd $PACK_TOOL_DIR/rockdev


	echo "Make update.img"

	if [ -f "$RK_PACKAGE_FILE" ]; then
		source_package_file_name=`ls -lh package-file | awk -F ' ' '{print $NF}'`
		ln -fs "$RK_PACKAGE_FILE" package-file
		./mkupdate.sh
		ln -fs $source_package_file_name package-file
	else
		./mkupdate.sh
	fi
	mv update.img $IMAGE_PATH

	finish_build
}

function build_save(){
	IMAGE_PATH=$TOP_DIR/rockdev
	DATE=$(date  +%Y%m%d)
 	TARGET=$(echo $RK_ROOTFS_TARGET | sed -e "s/\b\(.\)/\u\1/g")

	if [ "${RK_ROOTFS_SYSTEM}" != "debian" ];then
		Version="ubuntu"$RK_UBUNTU_VERSION"-"$RK_ROOTFS_TARGET"-"$DATE
	else
		Version="debian"$RK_DEBIAN_VERSION"-"$RK_ROOTFS_TARGET"-"$DATE
	fi


	Device_Name=$RK_PKG_NAME
	# Device_Name="$(echo $RK_KERNEL_DTS | tr '[:lower:]' '[:upper:]')"

	ZIP_NAME=$Device_Name"-"$Version
	STUB_PATH=IMAGE/$ZIP_NAME
	export STUB_PATH=$TOP_DIR/$STUB_PATH
	export STUB_PATCH_PATH=$STUB_PATH/PATCHES
	mkdir -p $STUB_PATH

	#Generate patches
	.repo/repo/repo forall -c \
		"$TOP_DIR/device/rockchip/common/gen_patches_body.sh"

	#Copy stubs
	.repo/repo/repo manifest -r -o $STUB_PATH/manifest_${DATE}.xml
	mkdir -p $STUB_PATCH_PATH/kernel
	cp kernel/.config $STUB_PATCH_PATH/kernel
	cp kernel/vmlinux $STUB_PATCH_PATH/kernel
	mkdir -p $STUB_PATH/IMAGES/
	cp $IMAGE_PATH/update.img $STUB_PATH/IMAGES/

	cd $STUB_PATH/IMAGES/
	mv update.img  ${ZIP_NAME}_update.img
	md5sum ${ZIP_NAME}_update.img > md5sum.txt
	# zip -o ../${ZIP_NAME}_update.zip ${ZIP_NAME}_update.img
	7z a ../${ZIP_NAME}_update.7z ${ZIP_NAME}_update.img md5sum.txt
	cd -

	#Save build command info
	echo "UBOOT:  defconfig: $RK_UBOOT_DEFCONFIG" >> $STUB_PATH/build_cmd_info
	echo "KERNEL: defconfig: $RK_KERNEL_DEFCONFIG, dts: $RK_KERNEL_DTS" >> $STUB_PATH/build_cmd_info

	finish_build
}

function build_allsave(){
	rm -fr $TOP_DIR/rockdev
	build_all
	build_firmware
	build_updateimg
	# build_save

	# build_check_power_domain

	finish_build
}

#=========================
# build targets
#=========================

if echo $@|grep -wqE "help|-h"; then
	if [ -n "$2" -a "$(type -t usage$2)" == function ]; then
		echo "###Current SDK Default [ $2 ] Build Command###"
		eval usage$2
	else
		usage
	fi
	exit 0
fi

OPTIONS="${@:-allsave}"

[ -f "device/rockchip/$RK_TARGET_PRODUCT/$RK_BOARD_PRE_BUILD_SCRIPT" ] \
	&& source "device/rockchip/$RK_TARGET_PRODUCT/$RK_BOARD_PRE_BUILD_SCRIPT"  # board hooks

for option in ${OPTIONS}; do
	echo "processing option: $option"
	case $option in
		BoardConfig*.mk)
			option=device/rockchip/$RK_TARGET_PRODUCT/$option
			;&
		*.mk)
			CONF=$(realpath $option)
			echo "switching to board: $CONF"
			if [ ! -f $CONF ]; then
				echo "not exist!"
				exit 1
			fi

			ln -rsf $CONF $BOARD_CONFIG
			;;
		lunch) build_select_board ;;
		all) build_all ;;
		save) build_save ;;
		allsave) build_allsave ;;
		check) build_check ;;
		cleanall) build_cleanall ;;
		firmware) build_firmware ;;
		updateimg) build_updateimg ;;
		uboot) build_uboot ;;
		loader) build_loader ;;
		kernel) build_kernel ;;
		kerneldeb) build_kerneldeb ;;
		extboot) build_extboot ;;
		modules) build_modules ;;
		rootfs|ubuntu|debian) build_rootfs $option ;;
		info) build_info ;;
		*) usage ;;
	esac
done

