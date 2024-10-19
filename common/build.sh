#!/bin/bash

# 判断是否拥有root权限，如果没有则使用sudo重新运行脚本
if [[ "${EUID}" == "0" ]]; then
		:
else
		echo -e "\033[42;36m 该脚本需要root权限，尝试使用sudo重新运行 \033[0m"
		sudo "${0}" "$@"
		exit $?
fi

trap 'err_handler' ERR # 设置错误捕获，当命令返回错误时调用 err_handler 函数
set -eE # 遇到错误立刻退出，并启用 ERR trap 处理函数

# 导入一些要用的函数
source $(dirname "$(realpath "$BASH_SOURCE")")/general.sh

# 切换到项目的顶层目录
cd $TOP_DIR

# 检查是否第一次运行,如果是第一次运行将安装一些需要的依赖、设置python脚本和交换分区
if [ ! -f "$TOP_DIR/script_run_flag" ]; then
    # 如果是第一次运行,则获取 sudo 权限
    echo -e "\e[31m这是第一次运行脚本，请输入您的用户密码.\e[0m"
    install_package
    # 创建一个标志文件,表示脚本已经运行过一次
    touch "$TOP_DIR/script_run_flag"
    set_python
fi

# 如果 BoardConfig.mk 文件不是符号链接，并且传入的第一个参数不是 "lunch"，则选择目标板
if [ ! -L "$BOARD_CONFIG" -a "$1" != "lunch" ]; then
    build_select_board
fi

# 清除所有和板相关的环境变量
unset_board_config_all

# 如果 BoardConfig.mk 是符号链接，则加载配置文件中的内容
[ -L "$BOARD_CONFIG" ] && source $BOARD_CONFIG


# 如果输入的参数中包含 "help" 或 "-h"，则打印帮助信息并退出
if echo $@ | grep -wqE "help|-h"; then
    # 如果第二个参数存在且相应的函数（usage$2）存在，则打印特定命令的帮助信息
    if [ -n "$2" -a "$(type -t usage$2)" == function ]; then
        echo "### 当前 SDK 默认 [$2] 构建命令 ###"
        eval usage$2  # 调用与第二个参数名称对应的函数，输出帮助信息
    else
        # 如果没有特定的帮助信息，调用通用的 usage 函数
        usage
    fi
    exit 0
fi

# 设置 OPTIONS 变量，如果没有传入任何参数，则默认为 "all"
OPTIONS="${@:-all}"

# 如果板级预构建脚本存在，则加载它
[ -f "device/rockchip/$RK_TARGET_PRODUCT/$RK_BOARD_PRE_BUILD_SCRIPT" ] \
    && source "device/rockchip/$RK_TARGET_PRODUCT/$RK_BOARD_PRE_BUILD_SCRIPT"  # 加载板级 hook 脚本


# 遍历传入的每个选项进行处理
for option in ${OPTIONS}; do
    # 打印当前正在处理的选项
    echo "processing option: $option"

    # 根据不同的选项执行相应的操作
    case $option in
        # 如果选项是以 "BoardConfig" 开头的 .mk 文件
        BoardConfig*.mk)
            # 将选项的路径指向目标产品目录下的对应文件
            option=device/rockchip/$RK_TARGET_PRODUCT/$option
            ;&
        # 如果选项是以 ".mk" 结尾的文件
        *.mk)
            # 获取配置文件的绝对路径
            CONF=$(realpath $option)
            echo "switching to board: $CONF"
            # 检查配置文件是否存在，如果不存在则退出脚本
            if [ ! -f $CONF ]; then
                echo "not exist!"
                exit 1
            fi
            # 创建符号链接，将 BOARD_CONFIG 链接到选定的配置文件
            ln -rsf $CONF $BOARD_CONFIG
            ;;
        lunch) build_select_board ;;
        uboot) build_uboot ;;
        kernel) build_kernel ;;
        kerneldeb) build_kerneldeb ;;
        extboot) build_extboot ;;
        modules) build_modules ;;
        ubuntu|debian) build_rootfs $option ;;
        cleanall) build_cleanall ;;
        firmware) build_firmware ;;
        updateimg) build_updateimg ;;
        all) build_all ;;
        *) usage ;;
    esac
done


