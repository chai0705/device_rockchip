#!/bin/bash
# install_package() 安装编译需要的软件包
# set_python() 设置Python版本
# err_handler() 错误处理函数
# finish_build()  运行完成处理函数
# check_config() 配置检查函数
# choose_target_board() 板级配置文件选择函数
# build_select_board() 板级配置文件选择函数
#  unset_board_config_all() 环境变量清除函数
#  usage() 提示打印函数
# build_check_cross_compile() 编译器检查配置函数
# build_uboot() uboot编译函数
# build_kernel() kernel编译函数
# build_kerneldeb() 编译内核deb包
# build_extboot() 编译用于extLinux启动的内核镜像
# build_modules() 内核驱动模块编译函数
# build_ubuntu() ubuntu编译函数
# build_debian() debian编译函数
# build_rootfs() 文件系统编译函数
# build_all() 编译全部镜像函数
# build_cleanall() 编译清除函数
# build_firmware() 固件配置函数
# build_updateimg() 固件打包函数

# 导入一些必要的环境变量
export LC_ALL=C  # 使用标准的 POSIX 环境
CMD=`realpath $0`  # 获取当前脚本的绝对路径
COMMON_DIR=`dirname $CMD`  # 获取脚本所在目录的路径
TOP_DIR=$(realpath $COMMON_DIR/../../..)  # 获取项目的顶层目录，通常是相对于脚本位置的上三级目录
BOARD_CONFIG=$TOP_DIR/device/rockchip/.BoardConfig.mk   # 定义 BoardConfig.mk 配置文件的路径
TARGET_PRODUCT="$TOP_DIR/device/rockchip/.target_product"  # 定义目标产品文件的路径
TARGET_PRODUCT_DIR=$(realpath ${TARGET_PRODUCT})  # 获取目标产品目录的绝对路径

# 错误处理函数
err_handler() {
	ret=$?  # 获取上一个命令的退出状态

	# 如果返回值等于0，表示上一个命令成功，不执行后续代码，直接返回
	[ "$ret" -eq 0 ] && return

	# 如果返回值不等于0，表示发生了错误，输出错误信息
	echo "ERROR: Running ${FUNCNAME[1]} failed!"
	echo "ERROR: exit code $ret from line ${BASH_LINENO[0]}:"
	echo "    $BASH_COMMAND"

	# 退出脚本，返回原错误码
	exit $ret
}

# 安装编译所需的依赖包
install_package() {
    # 检查网络连接
    HOSTRELEASE=$(grep VERSION_CODENAME /etc/os-release | cut -d"=" -f2)
    echo -e "\e[33m当前运行的系统为 $HOSTRELEASE.\e[0m"
    echo -e "\e[34m正在检查网络连接...\e[0m"
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "\e[32m网络连接正常，开始安装依赖包。\e[0m"

        # 通用必需依赖包列表，适用于内核、Buildroot、U-Boot、设备树等
        COMMON_PACKAGES=(
            whiptail dialog psmisc acl uuid uuid-runtime curl gpg gnupg gawk git
            aptly aria2 bc binfmt-support bison btrfs-progs build-essential
            ca-certificates ccache cpio cryptsetup debian-archive-keyring
            debian-keyring debootstrap device-tree-compiler dirmngr dosfstools
            dwarves f2fs-tools fakeroot flex gcc-arm-linux-gnueabihf gdisk imagemagick
            jq kmod libbison-dev libc6-dev-armhf-cross libelf-dev libfdt-dev
            libfile-fcntllock-perl libfl-dev liblz4-tool libncurses-dev libssl-dev
            libusb-1.0-0-dev linux-base locales lzop ncurses-base ncurses-term
            nfs-kernel-server ntpdate p7zip-full parted patchutils pigz pixz pkg-config
            pv python3-dev qemu-user-static rsync swig systemd-container u-boot-tools
            udev unzip uuid-dev wget zip zlib1g-dev distcc lib32ncurses-dev
            lib32stdc++6 libc6-i386 python3 expect expect-dev cmake vim openssh-server
            net-tools texinfo htop
        )

        # Ubuntu 18.04 特定的依赖包
        UBUNTU_18_PACKAGES=(
            liblz-dev liblzo2-2 liblzo2-dev mtd-utils squashfs-tools schedtool
            g++-multilib lib32z1-dev lib32ncurses5-dev lib32readline-dev gcc-multilib
            patchelf chrpath texinfo diffstat python3-pip subversion sed binutils
            bzip2 patch gzip perl tar file bc tcl android-tools-fsutils openjdk-8-jdk
            libsdl1.2-dev libesd-java libwxgtk3.0-dev repo bzr cvs mercurial pngcrush xsltproc
            gperf libc6-dev
        )

        # Ubuntu 20.04 和 22.04 特定的依赖包
        UBUNTU_20_22_PACKAGES=(
            python2 python3-distutils libpython2.7-dev
        )

        if [ "$HOSTRELEASE" == "bionic" ]; then
            echo -e "\e[33m正在安装 Ubuntu 18.04 编译所需依赖包...\e[0m"
            sudo apt-get update
            sudo apt-get -y upgrade
            sudo apt-get install -y --no-install-recommends "${COMMON_PACKAGES[@]}" "${UBUNTU_18_PACKAGES[@]}"
            echo -e "\e[32m依赖包安装完成。\e[0m"
        elif [ "$HOSTRELEASE" == "focal" ] || [ "$HOSTRELEASE" == "jammy" ]; then
            echo -e "\e[33m正在安装 Ubuntu 20.04 / 22.04 编译所需依赖包...\e[0m"
            sudo apt-get update
            sudo apt-get -y upgrade
            sudo apt-get install -y --no-install-recommends "${COMMON_PACKAGES[@]}" "${UBUNTU_20_22_PACKAGES[@]}"
            echo -e "\e[32m依赖包安装完成。\e[0m"
        elif [ "$HOSTRELEASE" == "noble" ]; then
            echo -e "\e[33m正在安装 Ubuntu 24.04 编译所需依赖包...\e[0m"
            sudo apt-get update
            sudo apt-get -y upgrade
            sudo apt-get install -y --no-install-recommends "${COMMON_PACKAGES[@]}"
            echo -e "\e[32m依赖包安装完成。\e[0m"
        else
            echo -e "\e[33m您的系统不是 Ubuntu 18.04 / 20.04 / 22.04 / 24.04，请自行安装依赖包。\e[0m"
        fi
    else
        # 没有网络连接，提示并退出函数
        echo -e "\e[31m未检测到网络连接，请确保已安装编译所需要的依赖包。\e[0m"
    fi
}

# 设置Python版本
set_python() {
    echo -e "\e[32m正在设置 Python 版本...\e[0m"
    if [ "$HOSTRELEASE" == "bionic" ] || [ "$HOSTRELEASE" == "focal" ] || [ "$HOSTRELEASE" == "jammy" ]; then        sudo ln -fs /usr/bin/python2.7 /usr/bin/python
        sudo ln -fs /usr/bin/python2.7 /usr/bin/python2
        echo -e "\e[32mPython 版本已设置为 Python 2.7。\e[0m"
    elif [ "$HOSTRELEASE" == "noble" ]; then
        sudo ln -fs /usr/bin/python3 /usr/bin/python
        sudo ln -fs /usr/bin/python3 /usr/bin/python2
        echo -e "\e[32mPython 版本已设置为 Python 3。\e[0m"
    else
        echo -e "\e[33m未知系统版本，无法设置 Python 版本。\e[0m"
    fi
}

# 运行完成处理函数
function finish_build(){
	echo "Running ${FUNCNAME[1]} succeeded."
	cd $TOP_DIR
}

# 配置检查函数
function check_config(){
    unset missing

    # 遍历所有传入的参数
    for var in $@; do
        eval [ \$$var ] && continue
        missing="$missing $var"
    done

    # 如果 missing 为空，说明所有参数都已定义，返回 0（表示成功）
    [ -z "$missing" ] && return 0

    # 输出缺少的配置，并返回 1（表示失败）
    echo "Skipping ${FUNCNAME[1]} for missing configs: $missing."
    return 1
}

# 板级配置文件选择函数
function choose_target_board() {
    echo
    echo "You're building on Linux"
    echo "Lunch menu...pick a combo:"
    echo ""

    # 打印所有可用的目标板选项，并为每个选项加上编号
    echo "0. default BoardConfig.mk"
    echo ${RK_TARGET_BOARD_ARRAY[@]} | xargs -n 1 | sed "=" | sed "N;s/\n/. /"

    # 读取用户输入的选项索引
    local INDEX
    read -p "Which would you like? [0]: " INDEX
    INDEX=$((${INDEX:-0} - 1))

    # 设置目标板的配置为用户选择的目标板
    if echo $INDEX | grep -vq [^0-9]; then
        RK_BUILD_TARGET_BOARD="${RK_TARGET_BOARD_ARRAY[$INDEX]}"
    else
        echo "Lunching for Default BoardConfig.mk boards..."
        RK_BUILD_TARGET_BOARD=BoardConfig.mk
    fi
}

# 板级配置文件选择函数
function build_select_board() {
    # 在 TARGET_PRODUCT_DIR 目录下查找以 "BoardConfig" 开头并以 ".mk" 结尾的文件，并对它们进行排序，存入数组 RK_TARGET_BOARD_ARRAY 中
    RK_TARGET_BOARD_ARRAY=( $(cd ${TARGET_PRODUCT_DIR}/; ls BoardConfig*.mk | sort) )
    RK_TARGET_BOARD_ARRAY_LEN=${#RK_TARGET_BOARD_ARRAY[@]}

    # 如果数组长度为 0，表示没有可用的板配置，输出提示并返回
    if [ $RK_TARGET_BOARD_ARRAY_LEN -eq 0 ]; then
        echo "No available Board Config"
        return
    fi

    # 调用 choose_target_board 函数，提示用户选择目标板配置
    choose_target_board

    # 创建软链接，将选择的板配置链接到 device/rockchip/.BoardConfig.mk
    ln -rfs $TARGET_PRODUCT_DIR/$RK_BUILD_TARGET_BOARD device/rockchip/.BoardConfig.mk
    echo "switching to board: `realpath $BOARD_CONFIG`"
}

# 环境变量清除函数
function unset_board_config_all() {
    local tmp_file=`mktemp`

    # 在 device 目录下查找所有以 "Board*.mk" 为名称的文件，提取所有以 "export RK_" 开头的变量定义，写入临时文件
    grep -oh "^export.*RK_.*=" `find device -name "Board*.mk"` > $tmp_file

    # 使用 source 命令来读取临时文件中的内容，取消定义配置变量
    source $tmp_file
    rm -f $tmp_file
}

# 提示打印函数
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
	echo "extboot            -build extlinux boot.img, boot from EFI partition"
	echo "ubuntu             -build ubuntu rootfs"
	echo "debian             -build debian rootfs"
	echo "all                -build uboot, kernel, rootfs, recovery image"
	echo "cleanall           -clean uboot, kernel, rootfs, recovery"
	echo "firmware           -pack all the image we need to boot up system"
	echo "updateimg          -pack update image"
	echo "check              -check the environment of building"
	echo ""
}

# 编译器检查配置函数
function build_check_cross_compile() {
    # 根据 RK_ARCH 变量的值选择交叉编译器
    case $RK_ARCH in
        arm|armhf)
            if [ -d "$TOP_DIR/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf" ]; then
                # 设置 CROSS_COMPILE 变量，指向 ARM 交叉编译器的路径
                CROSS_COMPILE=$(realpath $TOP_DIR)/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
                export CROSS_COMPILE=$CROSS_COMPILE
            fi
            ;;
        arm64|aarch64)
            if [ -d "$TOP_DIR/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu" ]; then
                # 设置 CROSS_COMPILE 变量，指向 ARM64 交叉编译器的路径
                CROSS_COMPILE=$(realpath $TOP_DIR)/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
                export CROSS_COMPILE=$CROSS_COMPILE
            fi
            ;;
        *)
            # 如果 RK_ARCH 的值不符合任何已知架构，输出提示信息
            echo "the $RK_ARCH not supported for now, please check it again\n"
            ;;
    esac
}

# uboot编译函数
function build_uboot() {
    # 检查配置项 RK_UBOOT_DEFCONFIG 是否已定义，如果未定义则返回
    check_config RK_UBOOT_DEFCONFIG || return 0

    # 检查并设置交叉编译器路径
    build_check_cross_compile

    # 输出构建 uboot 的开始信息
    echo "============开始编译uboot============"
    echo "uboot配置文件     =$RK_UBOOT_DEFCONFIG"
    echo "========================================="

    # 进入 u-boot 目录，删除可能存在的旧的 loader 文件
    cd u-boot
    rm -f *_loader_*.bin

    # 执行 make.sh 脚本，传入 uboot 配置和交叉编译器
    ./make.sh $RK_UBOOT_DEFCONFIG $UBOOT_COMPILE_COMMANDS CROSS_COMPILE=$CROSS_COMPILE
    finish_build
}

# kernel编译函数
function build_kernel() {
    # 检查配置项 RK_KERNEL_DTS 和 RK_KERNEL_DEFCONFIG 是否已定义，如果未定义则返回
    check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

    # 输出构建 kernel 的开始信息
    echo "============开始编译内核============"
    echo "线程数            =$RK_JOBS"                   # 输出并发编译的作业数量
    echo "目标架构          =$RK_ARCH"                   # 输出目标架构
    echo "内核配置          =$RK_KERNEL_DEFCONFIG"       # 输出内核配置
    echo "内核设备树        =$RK_KERNEL_DTS"             # 输出内核设备树
    echo "=========================================="

    # 检查并设置交叉编译器路径
    build_check_cross_compile

    # 进入 kernel 目录
    cd kernel

    # 使用指定的架构和内核配置文件进行编译
    make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT

    # 编译内核镜像，使用并发编译
    make ARCH=$RK_ARCH $RK_KERNEL_DTS.img -j$RK_JOBS

    # 如果存在指定的 FIT 设备树文件，则使用 mk-fitimage.sh 生成 FIT 镜像
    if [ -f "$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_KERNEL_FIT_ITS" ]; then
        $COMMON_DIR/mk-fitimage.sh $TOP_DIR/kernel/$RK_BOOT_IMG \
            $TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_KERNEL_FIT_ITS
    fi

    # 如果内核镜像生成成功，将其符号链接到 rockdev 目录下
    if [ -f "$TOP_DIR/kernel/$RK_BOOT_IMG" ]; then
        mkdir -p $TOP_DIR/rockdev                          # 创建 rockdev 目录
        ln -sf  $TOP_DIR/kernel/$RK_BOOT_IMG $TOP_DIR/rockdev/boot.img  # 创建 boot.img 的符号链接
    fi

    # 调用 finish_build 函数，表示构建结束
    finish_build
}

# 编译内核deb包
function build_kerneldeb() {
    # 检查配置项 RK_KERNEL_DTS 和 RK_KERNEL_DEFCONFIG 是否已定义，如果未定义则返回
    check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

    # 检查并设置交叉编译器路径
    build_check_cross_compile

    # 输出构建内核 deb 包的开始信息
    echo "============开始编译内核deb文件============"
    echo "目标架构                  =$RK_ARCH"                  # 输出目标架构
    echo "内核配置                  =$RK_KERNEL_DEFCONFIG"      # 输出内核配置
    echo "内核设备树                =$RK_KERNEL_DTS"            # 输出内核设备树
    echo "=========================================="
    pwd   # 打印当前工作目录

    # 删除之前可能生成的 .buildinfo、.changes 和 deb 包文件
    rm -f linux-*.buildinfo linux-*.changes
    rm -f linux-headers-*.deb linux-image-*.deb linux-libc-dev*.deb

    # 进入 kernel 目录
    cd kernel

    # 使用指定的架构和内核配置文件进行配置
    make ARCH=$RK_ARCH LOCALVERSION= $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT

    # 使用指定架构编译内核并打包成 deb 格式
    make ARCH=$RK_ARCH LOCALVERSION= bindeb-pkg RK_KERNEL_DTS=$RK_KERNEL_DTS -j$RK_JOBS

    # 调用 finish_build 函数，表示构建结束
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

	mkdir -p $EXTBOOT_DTB/overlay
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
	cp ${TOP_DIR}/kernel/arch/${RK_ARCH}/boot/dts/rockchip/overlay/*.dtbo $EXTBOOT_DTB/overlay

	# 复制设备树文件
	cp -f $EXTBOOT_DTB/${RK_KERNEL_DTS}.dtb $EXTBOOT_DIR/rk-kernel.dtb


	# 如果存在initrd文件，则复制到extboot目录
	cp ${TOP_DIR}/initrd/* $EXTBOOT_DIR/

	# 如果存在boot.cmd文件，则生成boot.scr启动脚本
	if [[ -e $EXTBOOT_DIR/boot.cmd ]]; then
		${TOP_DIR}/u-boot/tools/mkimage -T script -C none -d $EXTBOOT_DIR/boot.cmd $EXTBOOT_DIR/boot.scr
	fi

	# 复制其他内核相关文件
	cp ${TOP_DIR}/kernel/.config $EXTBOOT_DIR/config-$KERNEL_VERSION
	cp ${TOP_DIR}/kernel/System.map $EXTBOOT_DIR/System.map-$KERNEL_VERSION

	# 复制生成的Debian包
	cp ${TOP_DIR}/linux-headers-"$KERNEL_VERSION"_"$KERNEL_VERSION"-*.deb $EXTBOOT_DIR/kerneldeb
	cp ${TOP_DIR}/linux-image-"$KERNEL_VERSION"_"$KERNEL_VERSION"-*.deb $EXTBOOT_DIR/kerneldeb

	# 清理并生成ext2格式的extboot镜像
	rm -rf $EXTBOOT_IMG && truncate -s 128M $EXTBOOT_IMG
	fakeroot mkfs.ext2 -F -L "boot" -d $EXTBOOT_DIR $EXTBOOT_IMG
	finish_build
}

# 内核驱动模块编译函数
function build_modules(){
	check_config RK_KERNEL_DEFCONFIG || return 0

	echo "============开始编译内核模块============"
	echo "目标架构          =$RK_ARCH"
	echo "内核配置          =$RK_KERNEL_DEFCONFIG"
	echo "内核设备树        =$RK_KERNEL_DTS"
	echo "=================================================="

	build_check_cross_compile

	cd kernel
	make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT
	make ARCH=$RK_ARCH modules -j$RK_JOBS

	finish_build
}

# ubuntu编译函数
function build_ubuntu(){
	echo "=========开始编译ubuntu:$RK_ROOTFS_TARGE========="
	cd ubuntu

	if [ ! -e ubuntu-$RK_ROOTFS_TARGET-rootfs.img ]; then
		echo "[ 没有 ubuntu-$RK_ROOTFS_TARGET-rootfs.img, 运行ubuntu构建脚本 ]"
		TARGET=$RK_ROOTFS_TARGET SOC=$RK_SOC ARCH=arm64 ./mk-ubuntu-rootfs.sh
	else
		echo "[    已经存在编译完成的ubuntu镜像，跳过ubuntu编译    ]"
		echo "[ 如需编译，请删掉 Ubuntu-$RK_ROOTFS_TARGET-rootfs.img 重新构建ubuntu镜像 ]"
	fi

	finish_build
}

# debian编译函数
function build_debian(){
	echo "=========Start building debian:$RK_ROOTFS_TARGE========="
	cd debian

	if [ ! -e debian-$RK_ROOTFS_TARGET-rootfs.img ]; then
		echo "[ 没有 debian-$RK_ROOTFS_TARGET-rootfs.img, 运行Debian构建脚本 ]"
		TARGET=$RK_ROOTFS_TARGET SOC=$RK_SOC ARCH=arm64 ./mk-debian-rootfs.sh
	else
		echo "[    已经存在编译完成的Debian镜像，跳过Debian编译     ]"
		echo "[ 如需编译，请删掉 Debian-$RK_ROOTFS_TARGET-rootfs.img 重新构建 Debian 镜像 ]"
	fi

	finish_build
}

# 文件系统编译函数
function build_rootfs() {
    # 检查配置项 RK_ROOTFS_IMG 是否已定义，如果未定义则返回
    check_config RK_ROOTFS_IMG || return 0

    # 定义根文件系统目录和根文件系统镜像的名称
    RK_ROOTFS_DIR=.rootfs
    ROOTFS_IMG=${RK_ROOTFS_IMG##*/}

    # 删除之前可能存在的根文件系统镜像和目录
    rm -rf $RK_ROOTFS_IMG $RK_ROOTFS_DIR

    # 创建根文件系统镜像所在的目录和根文件系统目录
    mkdir -p ${RK_ROOTFS_IMG%/*} $RK_ROOTFS_DIR

    # 根据参数选择构建不同的根文件系统
    case "$1" in
        ubuntu)
            # 构建 Ubuntu 根文件系统
            build_ubuntu
            # 创建 Ubuntu 根文件系统镜像的符号链接，链接到 $RK_ROOTFS_DIR/rootfs.ext4
            ln -rsf ubuntu/ubuntu-$RK_ROOTFS_TARGET-rootfs.img \
                $RK_ROOTFS_DIR/rootfs.ext4
            ;;
        debian)
            # 构建 Debian 根文件系统
            build_debian
            # 创建 Debian 根文件系统镜像的符号链接，链接到 $RK_ROOTFS_DIR/rootfs.ext4
            ln -rsf debian/linaro-$RK_ROOTFS_TARGET-rootfs.img \
                $RK_ROOTFS_DIR/rootfs.ext4
            ;;
    esac

    # 检查是否成功生成了根文件系统镜像
    if [ ! -f "$RK_ROOTFS_DIR/$ROOTFS_IMG" ]; then
        echo "There's no $ROOTFS_IMG generated..."
        exit 1
    fi

    # 创建生成的根文件系统镜像的符号链接
    ln -rsf $RK_ROOTFS_DIR/$ROOTFS_IMG $RK_ROOTFS_IMG

    # 调用 finish_build 函数，表示构建结束
    finish_build
}

# 编译全部镜像函数
function build_all(){
    echo "============================================"
    echo "目标架构=$RK_ARCH"
    echo "目标平台=$RK_TARGET_PRODUCT"
    echo "uboot配置文件=$RK_UBOOT_DEFCONFIG"
    echo "内核配置文件=$RK_KERNEL_DEFCONFIG"
    echo "设备树=$RK_KERNEL_DTS"
    echo "============================================"

	build_uboot
	build_kerneldeb
	build_extboot
    build_rootfs ${RK_ROOTFS_SYSTEM:-ubuntu}
    build_firmware
    build_updateimg
    finish_build
}

# 编译清除函数
function build_cleanall(){
	echo "clean uboot, kernel, rootfs"

	cd u-boot
	make distclean
	cd -
	cd kernel
	make distclean
	cd -
	rm -rf debian/binary
	rm -rf debian/*.img
	rm -rf debian/*.*z
	rm -rf ubuntu/binary
	rm -rf ubuntu/*.img
	rm -rf ubuntu/*.*z
    rm -rf rockdev/*
    rm -rf script_run_flag
    rm -rf linux*
	finish_build
}

# 固件配置函数
function build_firmware(){
	./mkfirmware.sh $BOARD_CONFIG

	finish_build
}

# 固件打包函数
function build_updateimg() {
    # 定义镜像路径和打包工具目录
    IMAGE_PATH=$TOP_DIR/rockdev
    PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware

    # 获取当前日期，格式为 YYYYMMDD
    DATE=$(date +%Y%m%d)

    # 获取目标根文件系统的名称，并将首字母转换为大写
    TARGET=$(echo $RK_ROOTFS_TARGET | sed -e "s/\b\(.\)/\u\1/g")

    # 根据系统类型生成版本信息
    if [ "${RK_ROOTFS_SYSTEM}" != "debian" ]; then
        Version="ubuntu"$RK_UBUNTU_VERSION"-"$RK_ROOTFS_TARGET"-"$DATE
    else
        Version="debian"$RK_DEBIAN_VERSION"-"$RK_ROOTFS_TARGET"-"$DATE
    fi

    # 定义设备名称和压缩包名称
    Device_Name=$RK_PKG_NAME
    ZIP_NAME=$Device_Name"-"$Version

    # 进入镜像路径目录
    cd $IMAGE_PATH

    # 创建一个临时挂载目录
    mkdir -p mount-tmp

    # 挂载根文件系统镜像并写入构建信息
    echo mount and write build info
    sudo mount rootfs.img mount-tmp/
    sudo sh -c "echo ' * $ZIP_NAME' > mount-tmp/etc/build-release"
    sudo sync
    sudo umount mount-tmp/
    rm -rf mount-tmp/

    # 进入打包工具目录中的 rockdev 子目录
    cd $PACK_TOOL_DIR/rockdev

    # 打印制作 update.img 的信息
    echo "Make update.img"

    # 检查是否存在打包文件（package-file）
    if [ -f "$RK_PACKAGE_FILE" ]; then
        # 如果存在打包文件，获取原始的 package-file 文件名
        source_package_file_name=`ls -lh package-file | awk -F ' ' '{print $NF}'`
        # 创建符号链接，指向指定的打包文件
        ln -fs "$RK_PACKAGE_FILE" package-file
        # 运行 mkupdate.sh 脚本生成 update.img
        ./mkupdate.sh
        # 重新将 package-file 符号链接指向原始文件
        ln -fs $source_package_file_name package-file
    else
        # 如果没有指定的打包文件，直接运行 mkupdate.sh 生成 update.img
        ./mkupdate.sh
    fi

    # 将生成的 update.img 移动到镜像路径目录
    mv update.img $IMAGE_PATH
    finish_build
}

