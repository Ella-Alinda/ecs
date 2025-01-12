#!/usr/bin/env bash
# by spiritlhl
# from https://github.com/spiritLHLS/ecs

cd /root >/dev/null 2>&1
ver="2023.01.07"
changeLog="融合怪九代目(集合百家之长)(专为测评频道小鸡而生)"
test_area_g=("广州电信" "广州联通" "广州移动")
test_ip_g=("58.60.188.222" "210.21.196.6" "120.196.165.2")
test_area_s=("上海电信" "上海联通" "上海移动")
test_ip_s=("202.96.209.133" "210.22.97.1" "211.136.112.200")
test_area_b=("北京电信" "北京联通" "北京移动")
test_ip_b=("219.141.136.12" "202.106.50.1" "221.179.155.161")
TEMP_FILE='ip.test'
BrowserUA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"
WorkDir="/tmp/.LemonBench"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"
red(){ echo -e "\033[31m\033[01m$1$2\033[0m"; }
green(){ echo -e "\033[32m\033[01m$1$2\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1$2\033[0m"; }
_red() { echo -e "\033[31m\033[01m$@\033[0m"; }
_green() { echo -e "\033[32m\033[01m$@\033[0m"; }
_yellow() { echo -e "\033[33m\033[01m$@\033[0m"; }
_blue() { echo -e "\033[36m\033[01m$@\033[0m"; }
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "arch")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Arch")
PACKAGE_UPDATE=("! apt-get update && apt-get --fix-broken install -y && apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "pacman -Sy")
PACKAGE_INSTALL=("apt-get -y install" "apt-get -y install" "yum -y install" "yum -y install" "yum -y install" "pacman -Sy --noconfirm --needed")
PACKAGE_REMOVE=("apt-get -y remove" "apt-get -y remove" "yum -y remove" "yum -y remove" "yum -y remove" "pacman -Rsc --noconfirm")
PACKAGE_UNINSTALL=("apt-get -y autoremove" "apt-get -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "'pacman -Rs --noconfirm $(pacman -Qdtq)'")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')" "$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)") 
SYS="${CMD[0]}"
[[ -n $SYS ]] || exit 1
for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        [[ -n $SYSTEM ]] && break
    fi
done
apt-get --fix-broken install -y > /dev/null 2>&1

check_cdn() {
  local o_url=$1
  for cdn_url in "${cdn_urls[@]}"; do
    if curl -L -k "$cdn_url$o_url" --max-time 6 | grep -q "success" > /dev/null 2>&1; then
      export cdn_success_url="$cdn_url"
      return
    fi
    sleep 0.5
  done
  export cdn_success_url=""
}

check_cdn_file() {
    check_cdn "https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test"
    if [ -n "$cdn_success_url" ]; then
        yellow "CDN available, using CDN"
    else
        yellow "No CDN available, no use CDN"
    fi
}

# Trap终止信号捕获
_exit() {
    echo -e "\n\n${Msg_Error}Exiting ...\n"
    Global_Exit_Action
    rm_script
    exit 1
}

trap _exit INT QUIT TERM

# 新版JSON解析
PharseJSON() {
    # 使用方法: PharseJSON "要解析的原JSON文本" "要解析的键值"
    # Example: PharseJSON ""Value":"123456"" "Value" [返回结果: 123456]
    echo -n $1 | jq -r .$2
}

Global_StartupInit_Action() {
    Function_CheckTracemode
    # 清理残留, 为新一次的运行做好准备
    echo -e "${Msg_Info}Initializing Running Enviorment, Please wait ..."
    rm -rf "$WorkDir"
    rm -rf /.tmp_LBench/
    mkdir "$WorkDir"/
    echo -e "${Msg_Info}Checking Dependency ..."
    Check_Virtwhat
    Check_JSONQuery
    Check_SysBench
    echo -e "${Msg_Info}Starting Test ..."
}

Global_Exit_Action() {
    rm -rf ${WorkDir}/
    rm -rf /.tmp_LBench/
}

_exists() {
    local cmd="$1"
    if eval type type > /dev/null 2>&1; then
        eval type "$cmd" > /dev/null 2>&1
    elif command > /dev/null 2>&1; then
        command -v "$cmd" > /dev/null 2>&1
    else
        which "$cmd" > /dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

_exit() {
    _red "\n检测到退出操作，脚本终止！\n"
    # clean up
    rm -fr speedtest.tgz speedtest-cli benchtest_*
    exit 1
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() {
    printf "%-70s\n" "-" | sed 's/\s/-/g'
}

Function_CheckTracemode() {
    if [ "$Flag_TracerouteModeisSet" = "1" ]; then
        if [ "$GlobalVar_TracerouteMode" = "icmp" ]; then
            printf "%sTraceroute/BestTrace Tracemode is set to: %sICMP Mode%s\n" "$Msg_Info" "$Font_SkyBlue" "$Font_Suffix"
        elif [ "$GlobalVar_TracerouteMode" = "tcp" ]; then
            printf "%sTraceroute/BestTrace Tracemode is set to: %sTCP Mode%s\n" "$Msg_Info" "$Font_SkyBlue" "$Font_Suffix"
        fi
    else
        GlobalVar_TracerouteMode="tcp"
    fi
}

# =============== 检查 Virt-what 组件 ===============
Check_Virtwhat() {
    if [ ! -f "/usr/sbin/virt-what" ]; then
        SystemInfo_GetOSRelease
        if [[ "${Var_OSRelease}" =~ ^(centos|rhel|almalinux|arch)$ ]]; then
            echo -e "${Msg_Warning}Virt-What Module not found, Installing ..."
            yum -y install virt-what
        elif [[ "${Var_OSRelease}" =~ ^(ubuntu|debian)$ ]]; then
            echo -e "${Msg_Warning}Virt-What Module not found, Installing ..."
            ! apt-get update && apt-get --fix-broken install -y && apt-get update
            ! apt-get install -y dmidecode && apt-get --fix-broken install -y && apt-get install -y dmidecode
            ! apt-get install -y virt-what && apt-get --fix-broken install -y && apt-get install -y virt-what
        elif [ "${Var_OSRelease}" = "fedora" ]; then
            echo -e "${Msg_Warning}Virt-What Module not found, Installing ..."
            dnf -y install virt-what
        elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
            echo -e "${Msg_Warning}Virt-What Module not found, Installing ..."
            apk update
            apk add virt-what
        elif [ "${Var_OSRelease}" = "arch" ]; then
            echo -e "${Msg_Warning}Virt-What Module not found, Installing ..."
            pacman -Sy --needed --noconfirm virt-what
        else
            echo -e "${Msg_Warning}Virt-What Module not found, but we could not find the os's release ..."
        fi
    fi
    # 二次检测
    if [ ! -f "/usr/sbin/virt-what" ]; then
        echo -e "Virt-What Moudle install Failure! Try Restart Bench or Manually install it! (/usr/sbin/virt-what)"
        exit 1
    fi
}

# =============== 检查 JSON Query 组件 ===============
Check_JSONQuery() {
    # 判断 jq 命令是否存在
    if ! command -v jq > /dev/null; then
        # 获取系统位数
        SystemInfo_GetSystemBit
        # 获取操作系统版本
        SystemInfo_GetOSRelease
        # 根据系统位数设置下载地址
        local DownloadSrc
        if [ -z "${LBench_Result_SystemBit_Short}" ] || [ "${LBench_Result_SystemBit_Short}" != "amd64" ] || [ "${LBench_Result_SystemBit_Short}" != "i386" ]; then
            DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/JSONQuery/jq-i386.tar.gz"
        else
            DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/JSONQuery/jq-${LBench_Result_SystemBit_Short}.tar.gz"
            # local DownloadSrc="https://raw.githubusercontent.com/LemonBench/LemonBench/master/Resources/JSONQuery/jq-amd64.tar.gz"
            # local DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/jq/1.6/amd64/jq.tar.gz"
            # local DownloadSrc="https://raw.githubusercontent.com/LemonBench/LemonBench/master/Resources/JSONQuery/jq-i386.tar.gz"
            # local DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/jq/1.6/i386/jq.tar.gz"
        fi
        mkdir -p ${WorkDir}/
        echo -e "${Msg_Warning}JSON Query Module not found, Installing ..."
        echo -e "${Msg_Info}Installing Dependency ..."
        if [[ "${Var_OSRelease}" =~ ^(centos|rhel|almalinux)$ ]]; then
            yum install -y epel-release
            if [ $? -ne 0 ]; then
                cd /etc/yum.repos.d/
                sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
                sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
                yum makecache
                if [ $? -ne 0 ]; then
                    yum -y update && yum install -y epel-release
                fi
            fi
            yum install -y tar
            yum install -y jq
        elif [[ "${Var_OSRelease}" =~ ^(ubuntu|debian)$ ]]; then
            ! apt-get update && apt-get --fix-broken install -y && apt-get update
            ! apt-get install -y jq && apt-get --fix-broken install -y && apt-get install -y jq
        elif [ "${Var_OSRelease}" = "fedora" ]; then
            dnf install -y jq
        elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
            apk update
            apk add jq
        elif [ "${Var_OSRelease}" = "arch" ]; then
            pacman -Sy --needed --noconfirm jq
        else
            apk update
            apk add wget unzip curl
            echo -e "${Msg_Info}Downloading Json Query Module ..."
            curl --user-agent "${UA_LemonBench}" ${DownloadSrc} -o ${WorkDir}/jq.tar.gz
            echo -e "${Msg_Info}Installing JSON Query Module ..."
            tar xvf ${WorkDir}/jq.tar.gz
            mv ${WorkDir}/jq /usr/bin/jq
            chmod +x /usr/bin/jq
            echo -e "${Msg_Info}Cleaning up ..."
            rm -rf ${WorkDir}/jq.tar.gz
        fi
    fi
    # 二次检测
    if [ ! -f "/usr/bin/jq" ]; then
        echo -e "JSON Query Moudle install Failure! Try Restart Bench or Manually install it! (/usr/bin/jq)"
        exit 1
    fi
}

checkroot(){
	[[ $EUID -ne 0 ]] && echo -e "${RED}请使用 root 用户运行本脚本！${PLAIN}" && exit 1
}

checksystem() {
	if [ -f /etc/redhat-release ]; then
	    release="centos"
	elif cat /etc/issue | grep -Eqi "debian"; then
	    release="debian"
	elif cat /etc/issue | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	elif cat /proc/version | grep -Eqi "debian"; then
	    release="debian"
	elif cat /proc/version | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
    elif cat /proc/version | grep -Eqi "arch"; then
        release="arch"
	fi
}

checkupdate(){
	    yellow "Updating package management sources"
		${PACKAGE_UPDATE[int]} > /dev/null 2>&1
        ${PACKAGE_INSTALL[int]} dmidecode > /dev/null 2>&1
}

checkpython() {
	if  [ ! -e '/usr/bin/python3' ]; then
            yellow "Installing python3"
	            if [ "${release}" == "arch" ]; then
	                    pacman -S --noconfirm --needed python > /dev/null 2>&1 
                    else
	                    ${PACKAGE_INSTALL[int]} python3 > /dev/null 2>&1
	                fi
    fi
	if  [ ! -e '/usr/bin/python3-pip' ]; then
            yellow "Installing python3-pip"
	            if [ "${release}" == "arch" ]; then
	                    pacman -S --noconfirm --needed python-pip > /dev/null 2>&1
                        pip3 install requests > /dev/null 2>&1
                    else
	                    ${PACKAGE_INSTALL[int]} python3-pip > /dev/null 2>&1
                        pip3 install requests > /dev/null 2>&1
	                fi
    fi
    sleep 0.5
}

checkmagic(){
    pip3 install magic_google
    sleep 0.4
}

checkdnsutils() {
	if  [ ! -e '/usr/bin/dnsutils' ]; then
            yellow "Installing dnsutils"
	            if [ "${release}" == "centos" ]; then
	                    yum -y install dnsutils > /dev/null 2>&1
                        yum -y install bind-utils > /dev/null 2>&1
	                elif [ "${release}" == "arch" ]; then
                        pacman -S --noconfirm --needed bind > /dev/null 2>&1
                    else
	                    ${PACKAGE_INSTALL[int]} dnsutils > /dev/null 2>&1
	                fi

	fi
}

checkcurl() {
	if  [ ! -e '/usr/bin/curl' ]; then
            yellow "Installing curl"
	        ${PACKAGE_INSTALL[int]} curl > /dev/null 2>&1
	fi
}

checkwget() {
	if  [ ! -e '/usr/bin/wget' ]; then
            yellow "Installing wget"
	        ${PACKAGE_INSTALL[int]} wget > /dev/null 2>&1
	fi
}

checkssh() {
	for i in "${CMD[@]}"; do
		SYS="$i" && [[ -n $SYS ]] && break
	done
	for ((int=0; int<${#REGEX[@]}; int++)); do
		[[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
	done
	echo "开启22端口中，以便于测试IP是否被阻断"
	sshport=22
	[[ ! -f /etc/ssh/sshd_config ]] && sudo ${PACKAGE_UPDATE[int]} && sudo ${PACKAGE_INSTALL[int]} openssh-server
	[[ -z $(type -P curl) ]] && sudo ${PACKAGE_UPDATE[int]} && sudo ${PACKAGE_INSTALL[int]} curl
	sudo sed -i "s/^#\?Port.*/Port $sshport/g" /etc/ssh/sshd_config;
	sudo service ssh restart >/dev/null 2>&1  # 某些VPS系统的ssh服务名称为ssh，以防无法重启服务导致无法立刻使用密码登录
    sudo systemctl restart sshd >/dev/null 2>&1 # Arch Linux没有使用init.d
    sudo systemctl restart ssh >/dev/null 2>&1
	sudo service sshd restart >/dev/null 2>&1
	echo "开启22端口完毕"
}

checkspeedtest() {
	if  [ ! -e './speedtest-cli/speedtest' ]; then
        yellow "Installing Speedtest-cli"
                arch=$(uname -m)
                if [ "${arch}" == "i686" ]; then
                    arch="i386"
                fi
		wget --no-check-certificate -qO speedtest.tgz https://cdn.jsdelivr.net/gh/oooldking/script@1.1.7/speedtest_cli/ookla-speedtest-1.0.0-${arch}-linux.tgz > /dev/null 2>&1
		# wget --no-check-certificate -qO speedtest.tgz https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-${arch}-linux.tgz > /dev/null 2>&1
	fi
	mkdir -p speedtest-cli && tar zxvf speedtest.tgz -C ./speedtest-cli/ > /dev/null 2>&1 && chmod a+rx ./speedtest-cli/speedtest
}

download_speedtest_file() {
    local sys_bit="$1"
    local url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.1.1-linux-${sys_bit}.tgz"
    local url2="https://dl.lamp.sh/files/ookla-speedtest-1.1.1-linux-${sys_bit}.tgz"
    curl --fail -s -m 10 -o speedtest.tgz "${url1}" || curl --fail -s -m 10 -o speedtest.tgz "${url2}"
}

install_speedtest() {
    if [ ! -e "./speedtest-cli/speedtest" ]; then
        sys_bit=""
        local sysarch="$(uname -p)"
        case "${sysarch}" in
            "x86_64") sys_bit="x86_64";;
            "i686") sys_bit="i386";;
            *) _red "Error: Unsupported system architecture (${sysarch}).\n" && return 1;;
        esac
        if ! download_speedtest_file "${sys_bit}"; then
            _red "Error: Failed to download speedtest-cli.\n"
            return 1
        fi
        tar -zxf speedtest.tgz -C ./speedtest-cli
        rm -f speedtest.tgz
    fi
}

SystemInfo_GetOSRelease() {
    if [ -f "/etc/centos-release" ]; then # CentOS
        Var_OSRelease="centos"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        if [ "$(rpm -qa | grep -o el6 | sort -u)" = "el6" ]; then
            Var_CentOSELRepoVersion="6"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $3}')"
        elif [ "$(rpm -qa | grep -o el7 | sort -u)" = "el7" ]; then
            Var_CentOSELRepoVersion="7"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $4}')"
        elif [ "$(rpm -qa | grep -o el8 | sort -u)" = "el8" ]; then
            Var_CentOSELRepoVersion="8"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $4}')"
        else
            local Var_CentOSELRepoVersion="unknown"
            local Var_OSReleaseVersion="<Unknown Release>"
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/redhat-release" ]; then # RedHat
        Var_OSRelease="rhel"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        if [ "$(rpm -qa | grep -o el6 | sort -u)" = "el6" ]; then
            Var_RedHatELRepoVersion="6"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $3}')"
        elif [ "$(rpm -qa | grep -o el7 | sort -u)" = "el7" ]; then
            Var_RedHatELRepoVersion="7"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $4}')"
        elif [ "$(rpm -qa | grep -o el8 | sort -u)" = "el8" ]; then
            Var_RedHatELRepoVersion="8"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $4}')"
        else
            local Var_RedHatELRepoVersion="unknown"
            local Var_OSReleaseVersion="<Unknown Release>"
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/fedora-release" ]; then # Fedora
        Var_OSRelease="fedora"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3}')"
        local Var_OSReleaseVersion="$(cat /etc/fedora-release | awk '{print $3,$4,$5,$6,$7}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/lsb-release" ]; then # Ubuntu
        Var_OSRelease="ubuntu"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/NAME/{print $3}' | head -n1)"
        local Var_OSReleaseVersion="$(cat /etc/os-release | awk -F '[= "]' '/VERSION/{print $3,$4,$5,$6,$7}' | head -n1)"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
        Var_OSReleaseVersion_Short="$(cat /etc/lsb-release | awk -F '[= "]' '/DISTRIB_RELEASE/{print $2}')"
    elif [ -f "/etc/debian_version" ]; then # Debian
        Var_OSRelease="debian"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        local Var_OSReleaseVersion="$(cat /etc/debian_version | awk '{print $1}')"
        local Var_OSReleaseVersionShort="$(cat /etc/debian_version | awk '{printf "%d\n",$1}')"
        if [ "${Var_OSReleaseVersionShort}" = "7" ]; then
            Var_OSReleaseVersion_Short="7"
            Var_OSReleaseVersion_Codename="wheezy"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Wheezy\""
        elif [ "${Var_OSReleaseVersionShort}" = "8" ]; then
            Var_OSReleaseVersion_Short="8"
            Var_OSReleaseVersion_Codename="jessie"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Jessie\""
        elif [ "${Var_OSReleaseVersionShort}" = "9" ]; then
            Var_OSReleaseVersion_Short="9"
            Var_OSReleaseVersion_Codename="stretch"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Stretch\""
        elif [ "${Var_OSReleaseVersionShort}" = "10" ]; then
            Var_OSReleaseVersion_Short="10"
            Var_OSReleaseVersion_Codename="buster"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Buster\""
        else
            Var_OSReleaseVersion_Short="sid"
            Var_OSReleaseVersion_Codename="sid"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Sid (Testing)\""
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/alpine-release" ]; then # Alpine Linux
        Var_OSRelease="alpinelinux"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/NAME/{print $3,$4}' | head -n1)"
        local Var_OSReleaseVersion="$(cat /etc/alpine-release | awk '{print $1}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/almalinux-release" ]; then # almalinux
        Var_OSRelease="almalinux"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3}')"
        local Var_OSReleaseVersion="$(cat /etc/almalinux-release | awk '{print $3,$4,$5,$6,$7}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/arch-release" ]; then # archlinux
        Var_OSRelease="arch"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3}')"
        local Var_OSReleaseArch="$(uname -m)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName ($Var_OSReleaseArch)" # 滚动发行版 不存在版本号
    else
        Var_OSRelease="unknown" # 未知系统分支
        LBench_Result_OSReleaseFullName="[Error: Unknown Linux Branch !]"
    fi
}

# =============== 检查 SysBench 组件 ===============
GetOSRelease() {
  local OS_TYPE
  SystemInfo_GetOSRelease
  case "${Var_OSRelease}" in
    centos|rhel|almalinux) OS_TYPE="redhat";;
    ubuntu) OS_TYPE="ubuntu";;
    debian) OS_TYPE="debian";;
    fedora) OS_TYPE="fedora";;
    alpinelinux) OS_TYPE="alpinelinux";;
    arch) OS_TYPE="arch";;
    *) OS_TYPE="unknown";;
  esac
  echo "${OS_TYPE}"
}

InstallSysbench() {
  local os_release=$1
  case "$os_release" in
    redhat) yum -y install epel-release && yum -y install sysbench ;;
    ubuntu) ! apt-get install sysbench -y && apt-get --fix-broken install -y && apt-get install sysbench -y ;;
    debian)
      local mirrorbase="https://raindrop.ilemonrain.com/LemonBench"
      local componentname="Sysbench"
      local version="1.0.19-1"
      local arch="debian"
      local codename="${Var_OSReleaseVersion_Codename}"
      local bit="${LBench_Result_SystemBit_Full}"
      local filenamebase="sysbench"
      local filename="${filenamebase}_${version}_${bit}.deb"
      local downurl="${mirrorbase}/include/${componentname}/${version}/${arch}/${codename}/${filename}"
      mkdir -p ${WorkDir}/download/
      pushd ${WorkDir}/download/ >/dev/null
      wget -U "${UA_LemonBench}" -O ${filenamebase}_${version}_${bit}.deb ${downurl}
      dpkg -i ./${filename}
      ! apt-get install sysbench -y && apt-get --fix-broken install -y && apt-get install sysbench -y
      popd
      if [ ! -f "/usr/bin/sysbench" ] && [ ! -f "/usr/local/bin/sysbench" ]; then
        echo -e "${Msg_Warning}Sysbench Module Install Failed!"
      fi ;;
    fedora) dnf -y install sysbench ;;
    arch) pacman -S --needed --noconfirm sysbench ;;
    alpinelinux) echo -e "${Msg_Warning}Sysbench Module not found, installing ..." && echo -e "${Msg_Warning}SysBench Current not support Alpine Linux, Skipping..." && Var_Skip_SysBench="1" ;;
    *) echo "Error: Unknown OS release: $os_release" && exit 1 ;;
  esac
}

Check_SysBench() {
  if [ ! -f "/usr/bin/sysbench" ] && [ ! -f "/usr/local/bin/sysbench" ]; then
    local os_release=$(GetOSRelease)
    if [ "$os_release" = "alpinelinux" ]; then
      Var_Skip_SysBench="1"
    else
      InstallSysbench "$os_release"
    fi
  fi
  # 垂死挣扎 (尝试编译安装)
  if [ ! -f "/usr/bin/sysbench" ] && [ ! -f "/usr/local/bin/sysbench" ]; then
    echo -e "${Msg_Warning}Sysbench Module install Failure, trying compile modules ..."
    Check_Sysbench_InstantBuild
  fi
  # 最终检测
  if [ ! -f "/usr/bin/sysbench" ] && [ ! -f "/usr/local/bin/sysbench" ]; then
    echo -e "${Msg_Error}SysBench Moudle install Failure! Try Restart Bench or Manually install it! (/usr/bin/sysbench)"
    exit 1
  fi
}

Check_Sysbench_InstantBuild() {
    SystemInfo_GetOSRelease
    SystemInfo_GetCPUInfo
    if [ "${Var_OSRelease}" = "centos" ] || [ "${Var_OSRelease}" = "rhel" ] || [ "${Var_OSRelease}" = "almalinux" ] || [ "${Var_OSRelease}" = "ubuntu" ] || [ "${Var_OSRelease}" = "debian" ] || [ "${Var_OSRelease}" = "fedora" ] || [ "${Var_OSRelease}" = "arch" ]; then
        echo -e "${Msg_Info}Release Detected: ${Var_OSRelease}"
        echo -e "${Msg_Info}Preparing compile enviorment ..."
        prepare_compile_env "${Var_OSRelease}"
        echo -e "${Msg_Info}Downloading Source code (Version 1.0.17)..."
        mkdir -p /tmp/_LBench/src/
        wget -U "${UA_LemonBench}" -O /tmp/_LBench/src/sysbench.zip "${cdn_success_url}https://github.com/akopytov/sysbench/archive/1.0.17.zip"
        echo -e "${Msg_Info}Compiling Sysbench Module ..."
        cd /tmp/_LBench/src/
        unzip sysbench.zip && cd sysbench-1.0.17
        ./autogen.sh && ./configure --without-mysql && make -j8 && make install
        echo -e "${Msg_Info}Cleaning up ..."
        cd /tmp && rm -rf /tmp/_LBench/src/sysbench*
    else
        echo -e "${Msg_Warning}Unsupported operating system: ${Var_OSRelease}"
    fi
}

prepare_compile_env() {
    local system="$1"
    if [ "${system}" = "centos" ] || [ "${system}" = "rhel" ] || [ "${system}" = "almalinux" ]; then
        yum install -y epel-release
        yum install -y wget curl make gcc gcc-c++ make automake libtool pkgconfig libaio-devel
    elif [ "${system}" = "ubuntu" ] || [ "${system}" = "debian" ]; then
        ! apt-get update &&  apt-get --fix-broken install -y && apt-get update
        ! apt-get -y install --no-install-recommends curl wget make automake libtool pkg-config libaio-dev unzip && apt-get --fix-broken install -y && apt-get -y install --no-install-recommends curl wget make automake libtool pkg-config libaio-dev unzip
    elif [ "${system}" = "fedora" ]; then
        dnf install -y wget curl gcc gcc-c++ make automake libtool pkgconfig libaio-devel
    elif [ "${system}" = "arch" ]; then
        pacman -S --needed --noconfirm wget curl gcc gcc make automake libtool pkgconfig libaio lib32-libaio
    else
        echo -e "${Msg_Warning}Unsupported operating system: ${system}"
    fi
}

# =============== SysBench - CPU性能 部分 ===============
Run_SysBench_CPU() {
    # 调用方式: Run_SysBench_CPU "线程数" "测试时长(s)" "测试遍数" "说明"
    # 变量初始化
    mkdir -p ${WorkDir}/SysBench/CPU/ >/dev/null 2>&1
    maxtestcount="$3"
    local count="1"
    local TestScore="0"
    local TotalScore="0"
    # 运行测试
    while [ $count -le $maxtestcount ]; do
        echo -e "\r ${Font_Yellow}$4: ${Font_Suffix}\t\t$count/$maxtestcount \c"
        local TestResult="$(sysbench --test=cpu --num-threads=$1 --cpu-max-prime=10000 --max-requests=1000000 --max-time=$2 run 2>&1)"
        local TestScore="$(echo ${TestResult} | grep -oE "events per second: [0-9]+" | grep -oE "[0-9]+")"
        local TotalScore="$(echo "${TotalScore} ${TestScore}" | awk '{printf "%d",$1+$2}')"
        let count=count+1
        local TestResult=""
        local TestScore="0"
    done
    local ResultScore="$(echo "${TotalScore} ${maxtestcount}" | awk '{printf "%d",$1/$2}')"
    if [ "$1" = "1" ]; then
        echo -e "\r ${Font_Yellow}$4: ${Font_Suffix}\t\t${Font_SkyBlue}${ResultScore}${Font_Suffix} ${Font_Yellow}Scores${Font_Suffix}"
        echo -e " $4:\t\t\t${ResultScore} Scores" >>${WorkDir}/SysBench/CPU/result.txt
    elif [ "$1" -ge "2" ]; then
        echo -e "\r ${Font_Yellow}$4: ${Font_Suffix}\t\t${Font_SkyBlue}${ResultScore}${Font_Suffix} ${Font_Yellow}Scores${Font_Suffix}"
        echo -e " $4:\t\t${ResultScore} Scores" >>${WorkDir}/SysBench/CPU/result.txt
    fi
}

Function_SysBench_CPU_Fast() {
    cd /root >/dev/null 2>&1
    mkdir -p ${WorkDir}/SysBench/CPU/ >/dev/null 2>&1
    echo -e " ${Font_Yellow}-> CPU 测试中 (Fast Mode, 1-Pass @ 5sec)${Font_Suffix}"
    echo -e " -> CPU 测试中 (Fast Mode, 1-Pass @ 5sec)\n" >>${WorkDir}/SysBench/CPU/result.txt
    Run_SysBench_CPU "1" "5" "1" "1 线程测试(1核)得分"
    sleep 1
    if [ "${LBench_Result_CPUThreadNumber}" -ge "2" ]; then
        Run_SysBench_CPU "${LBench_Result_CPUThreadNumber}" "5" "1" "${LBench_Result_CPUThreadNumber} 线程测试(多核)得分"
    elif [ "${LBench_Result_CPUProcessorNumber}" -ge "2" ]; then
        Run_SysBench_CPU "${LBench_Result_CPUProcessorNumber}" "5" "1" "${LBench_Result_CPUProcessorNumber} 线程测试(多核)得分"
    fi
    # 完成FLAG
    LBench_Flag_FinishSysBenchCPUFast="1"
}

# =============== SystemInfo模块 部分 ===============
SystemInfo_GetCPUInfo() {
    mkdir -p ${WorkDir}/data >/dev/null 2>&1
    cat /proc/cpuinfo >${WorkDir}/data/cpuinfo
    local ReadCPUInfo="cat ${WorkDir}/data/cpuinfo"
    LBench_Result_CPUModelName="$($ReadCPUInfo | awk -F ': ' '/model name/{print $2}' | sort -u)"
    local CPUFreqCount="$($ReadCPUInfo | awk -F ': ' '/cpu MHz/{print $2}' | sort -run | wc -l)"
    if [ "${CPUFreqCount}" -ge "2" ]; then
        local CPUFreqArray="$(cat /proc/cpuinfo | awk -F ': ' '/cpu MHz/{print $2}' | sort -run)"
        local CPUFreq_Min="$(echo "$CPUFreqArray" | grep -oE '[0-9]+.[0-9]{3}' | awk 'BEGIN {min = 2147483647} {if ($1+0 < min+0) min=$1} END {print min}')"
        local CPUFreq_Max="$(echo "$CPUFreqArray" | grep -oE '[0-9]+.[0-9]{3}' | awk 'BEGIN {max = 0} {if ($1+0 > max+0) max=$1} END {print max}')"
        LBench_Result_CPUFreqMinGHz="$(echo $CPUFreq_Min | awk '{printf "%.2f\n",$1/1000}')"
        LBench_Result_CPUFreqMaxGHz="$(echo $CPUFreq_Max | awk '{printf "%.2f\n",$1/1000}')"
        Flag_DymanicCPUFreqDetected="1"
    else
        LBench_Result_CPUFreqMHz="$($ReadCPUInfo | awk -F ': ' '/cpu MHz/{print $2}' | sort -u)"
        LBench_Result_CPUFreqGHz="$(echo $LBench_Result_CPUFreqMHz | awk '{printf "%.2f\n",$1/1000}')"
        Flag_DymanicCPUFreqDetected="0"
    fi
    LBench_Result_CPUCacheSize="$($ReadCPUInfo | awk -F ': ' '/cache size/{print $2}' | sort -u)"
    LBench_Result_CPUPhysicalNumber="$($ReadCPUInfo | awk -F ': ' '/physical id/{print $2}' | sort -u | wc -l)"
    LBench_Result_CPUCoreNumber="$($ReadCPUInfo | awk -F ': ' '/cpu cores/{print $2}' | sort -u)"
    LBench_Result_CPUThreadNumber="$($ReadCPUInfo | awk -F ': ' '/cores/{print $2}' | wc -l)"
    LBench_Result_CPUProcessorNumber="$($ReadCPUInfo | awk -F ': ' '/processor/{print $2}' | wc -l)"
    LBench_Result_CPUSiblingsNumber="$($ReadCPUInfo | awk -F ': ' '/siblings/{print $2}' | sort -u)"
    LBench_Result_CPUTotalCoreNumber="$($ReadCPUInfo | awk -F ': ' '/physical id/&&/0/{print $2}' | wc -l)"
    
    # 虚拟化能力检测
    SystemInfo_GetVirtType
    if [ "${Var_VirtType}" = "dedicated" ] || [ "${Var_VirtType}" = "wsl" ]; then
        LBench_Result_CPUIsPhysical="1"
        local VirtCheck="$(cat /proc/cpuinfo | grep -oE 'vmx|svm' | uniq)"
        if [ "${VirtCheck}" != "" ]; then
            LBench_Result_CPUVirtualization="1"
            local VirtualizationType="$(lscpu | awk /Virtualization:/'{print $2}')"
            LBench_Result_CPUVirtualizationType="${VirtualizationType}"
        else
            LBench_Result_CPUVirtualization="0"
        fi
    elif [ "${Var_VirtType}" = "kvm" ] || [ "${Var_VirtType}" = "hyperv" ] || [ "${Var_VirtType}" = "microsoft" ] || [ "${Var_VirtType}" = "vmware" ]; then
        LBench_Result_CPUIsPhysical="0"
        local VirtCheck="$(cat /proc/cpuinfo | grep -oE 'vmx|svm' | uniq)"
        if [ "${VirtCheck}" = "vmx" ] || [ "${VirtCheck}" = "svm" ]; then
            LBench_Result_CPUVirtualization="2"
            local VirtualizationType="$(lscpu | awk /Virtualization:/'{print $2}')"
            LBench_Result_CPUVirtualizationType="${VirtualizationType}"
        else
            LBench_Result_CPUVirtualization="0"
        fi        
    else
        LBench_Result_CPUIsPhysical="0"
    fi
}

Function_ReadCPUStat() {
    if [ "$1" == "" ]; then
        echo -n "nil"
    else
        local result="$(echo $1 | grep -oE "[0-9]{1,2}.[0-9]{1} $2" | awk '{print $1}')"
        echo $result
    fi
}

DownloadFiles() {
    curl -L -k "${cdn_success_url}https://github.com/sjlleo/VerifyDisneyPlus/releases/download/1.01/dp_1.01_linux_${LBench_Result_SystemBit_Full}" -o dp && chmod +x dp
    sleep 0.5
    curl -L -k "${cdn_success_url}https://github.com/sjlleo/netflix-verify/releases/download/v3.1.0/nf_linux_${LBench_Result_SystemBit_Full}" -o nf && chmod +x nf
    sleep 0.5
    curl -L -k "${cdn_success_url}https://github.com/sjlleo/TubeCheck/releases/download/1.0Beta/tubecheck_1.0beta_linux_${LBench_Result_SystemBit_Full}" -o tubecheck && chmod +x tubecheck
    sleep 0.5
}

SystemInfo_GetSystemBit() {
    local sysarch="$(uname -m)"
    if [ "${sysarch}" = "unknown" ] || [ "${sysarch}" = "" ]; then
        local sysarch="$(arch)"
    fi
    # 根据架构信息设置系统位数并下载文件
    case "${sysarch}" in
        "x86_64")
            LBench_Result_SystemBit_Short="64"
            LBench_Result_SystemBit_Full="amd64"
            DownloadFiles
            ;;
        "i386" | "i686")
            LBench_Result_SystemBit_Short="32"
            LBench_Result_SystemBit_Full="i386"
            DownloadFiles
            ;;
        "armv7l" | "armv8" | "armv8l" | "aarch64")
            LBench_Result_SystemBit_Short="arm"
            LBench_Result_SystemBit_Full="arm"
            DownloadFiles
            ;;
        *)
            LBench_Result_SystemBit_Short="64"
            LBench_Result_SystemBit_Full="amd64"
            DownloadFiles
            ;;
    esac
}

SystemInfo_GetVirtType() {
    if [ -f "/usr/bin/systemd-detect-virt" ]; then
        Var_VirtType="$(/usr/bin/systemd-detect-virt)"
        # 虚拟机检测
        case "${Var_VirtType}" in
            "*qemu*") LBench_Result_VirtType="QEMU" ;;
            "*kvm*") LBench_Result_VirtType="KVM" ;;
            "*zvm*") LBench_Result_VirtType="S390 Z/VM" ;;
            "*vmware*") LBench_Result_VirtType="VMware" ;;
            "*microsoft*") LBench_Result_VirtType="Microsoft Hyper-V" ;;
            "*xen*") LBench_Result_VirtType="Xen Hypervisor" ;;
            "*bochs*") LBench_Result_VirtType="BOCHS" ;;
            "*uml*") LBench_Result_VirtType="User-mode Linux" ;;
            "*parallels*") LBench_Result_VirtType="Parallels" ;;
            "*bhyve*") LBench_Result_VirtType="FreeBSD Hypervisor" ;;
            "*openvz*") LBench_Result_VirtType="OpenVZ" ;;
            "lxc") LBench_Result_VirtType="LXC" ;;
            "lxc-libvirt") LBench_Result_VirtType="LXC (libvirt)" ;;
            "*systemd-nspawn*") LBench_Result_VirtType="Systemd nspawn" ;;
            "*docker*") LBench_Result_VirtType="Docker" ;;
            "*rkt*") LBench_Result_VirtType="RKT" ;;
            "none")
                sleep 1
                Var_VirtType="$(/usr/bin/systemd-detect-virt)"
                LBench_Result_VirtType="None"
                local Var_BIOSVendor="$(dmidecode -s bios-vendor)"
                if [ "${Var_BIOSVendor}" = "SeaBIOS" ]; then
                    Var_VirtType="Unknown"
                    LBench_Result_VirtType="Unknown with SeaBIOS BIOS"
                else
                    Var_VirtType="dedicated"
                    LBench_Result_VirtType="Dedicated with ${Var_BIOSVendor} BIOS"
                fi
                ;;
            *)
                if [ -c "/dev/lxss" ]; then
                    Var_VirtType="wsl"
                    LBench_Result_VirtType="Windows Subsystem for Linux (WSL)"
                fi
                ;;
        esac
    elif [ ! -f "/usr/sbin/virt-what" ]; then
        Var_VirtType="Unknown"
        LBench_Result_VirtType="[Error: virt-what not found !]"
    elif [ -f "/.dockerenv" ]; then # 处理Docker虚拟化
        Var_VirtType="docker"
        LBench_Result_VirtType="Docker"
    elif [ -c "/dev/lxss" ]; then # 处理WSL虚拟化
        Var_VirtType="wsl"
        LBench_Result_VirtType="Windows Subsystem for Linux (WSL)"
    else # 正常判断流程
        Var_VirtType="$(virt-what | xargs)"
        local Var_VirtTypeCount="$(echo $Var_VirtTypeCount | wc -l)"
        if [ "${Var_VirtTypeCount}" -gt "1" ]; then # 处理嵌套虚拟化
            LBench_Result_VirtType="echo ${Var_VirtType}"
            Var_VirtType="$(echo ${Var_VirtType} | head -n1)" # 使用检测到的第一种虚拟化继续做判断
        elif [ "${Var_VirtTypeCount}" -eq "1" ] && [ "${Var_VirtType}" != "" ]; then # 只有一种虚拟化
            LBench_Result_VirtType="${Var_VirtType}"
        else
            local Var_BIOSVendor="$(dmidecode -s bios-vendor)"
            if [ "${Var_BIOSVendor}" = "SeaBIOS" ]; then
                Var_VirtType="Unknown"
                LBench_Result_VirtType="Unknown with SeaBIOS BIOS"
            else
                Var_VirtType="dedicated"
                LBench_Result_VirtType="Dedicated with ${Var_BIOSVendor} BIOS"
            fi
        fi
    fi
}

Entrance_SysBench_CPU_Fast() {
    Check_SysBench > /dev/null 2>&1
    SystemInfo_GetCPUInfo > /dev/null 2>&1
    Function_SysBench_CPU_Fast
    sleep 1
}

speed_test(){
	speedLog="./speedtest.log"
	true > $speedLog
		speedtest-cli/speedtest -p no -s $1 --accept-license > $speedLog 2>&1
		is_upload=$(cat $speedLog | grep 'Upload')
		if [[ ${is_upload} ]]; then
	        local REDownload=$(cat $speedLog | awk -F ' ' '/Download/{print $3}')
	        local reupload=$(cat $speedLog | awk -F ' ' '/Upload/{print $3}')
	        local relatency=$(cat $speedLog | awk -F ' ' '/Latency/{print $2}')
			local nodeID=$1
			local nodeLocation=$2
			local nodeISP=$3
			strnodeLocation="${nodeLocation}　　　　　　"
			LANG=C
			#echo $LANG
			temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
	        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
	       		echo -e "${strnodeLocation:0:20}\t ${reupload}Mbps\t ${REDownload}Mbps\t ${relatency}ms"
			fi
		else
	        local cerror="ERROR"
		fi
}

speed_test2() {
    local nodeName="$2"
    [ -z "$1" ] && ./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr > ./speedtest-cli/speedtest.log 2>&1 || \
    ./speedtest-cli/speedtest --progress=no --server-id=$1 --accept-license --accept-gdpr > ./speedtest-cli/speedtest.log 2>&1
    if [ $? -eq 0 ]; then
        local dl_speed=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        local up_speed=$(awk '/Upload/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        local latency=$(awk '/Latency/{print $2" "$3}' ./speedtest-cli/speedtest.log)
        if [[ -n "${dl_speed}" && -n "${up_speed}" && -n "${latency}" ]]; then
            echo -e "${nodeName}\t ${up_speed}\t ${dl_speed}\t ${latency}"
        fi
    fi
}

speed() {
    # https://raw.githubusercontent.com/zq/superspeed/master/superspeed.sh
    speed_test2 '' 'Speedtest.net' # 为了美观浅改一下（x
    speed_test '21541' '洛杉矶\t'
    speed_test '13623' '新加坡\t'
    speed_test '44988' '日本东京'
    speed_test '16176' '中国香港'
    speed_test '3633' '电信上海' '电信'
    speed_test '27594' '电信广东广州5G' '电信'
#    speed_test '5396' '电信江苏苏州5G' '电信'
    speed_test '24447' '联通上海' '联通'
    speed_test '4870' '联通湖南长沙' '联通'
#    speed_test '4870' '联通湖南长沙' '联通'
#    speed_test '25637' '移动上海5G' '移动'
#    speed_test '16398' '移动贵州贵阳' '移动'
#    speed_test '6715' '移动浙江宁波' '移动'
     speed_test '3356' '移动广西南宁' '移动'
     speed_test '26940' '移动宁夏银川' '移动'
}

speed2() {
    # https://raw.githubusercontent.com/zq/superspeed/master/superspeed.sh
    speed_test2 '' 'Speedtest.net'
    speed_test '3633' '电信上海' '电信'
    speed_test '24447' '联通上海' '联通'
    # speed_test '25637' '移动上海5G' '移动'
    # speed_test '595' '电信上海' '电信'
    # speed_test '5135' '联通上海5G' '联通'
    speed_test '3356' '移动广西南宁' '移动'
}

# =============== 磁盘测试 部分 ===============
Run_DiskTest_DD() {
    # 调用方式: Run_DiskTest_DD "测试文件名" "块大小" "写入次数" "测试项目名称"
    mkdir -p ${WorkDir}/DiskTest/ >/dev/null 2>&1
    SystemInfo_GetVirtType
    mkdir -p /.tmp_LBench/DiskTest >/dev/null 2>&1
    mkdir -p ${WorkDir}/data >/dev/null 2>&1
    local Var_DiskTestResultFile="${WorkDir}/data/disktest_result"
    # 将先测试读, 后测试写
    echo -n -e " $4\t\t->\c"
    # 清理缓存, 避免影响测试结果
    sync
    if [ "${Var_VirtType}" != "docker" ] && [ "${Var_VirtType}" != "openvz" ] && [ "${Var_VirtType}" != "lxc" ] && [ "${Var_VirtType}" != "wsl" ]; then
        echo 3 >/proc/sys/vm/drop_caches > /dev/null 2>&1
    fi
    # 避免磁盘压力过高, 启动测试前暂停1s
    sleep 1
    # 正式写测试
    dd if=/dev/zero of=/.tmp_LBench/DiskTest/$1 bs=$2 count=$3 oflag=direct 2>${Var_DiskTestResultFile}
    local DiskTest_WriteSpeed_ResultRAW="$(cat ${Var_DiskTestResultFile} | grep -oE "[0-9]{1,4} kB/s|[0-9]{1,4}.[0-9]{1,2} kB/s|[0-9]{1,4} KB/s|[0-9]{1,4}.[0-9]{1,2} KB/s|[0-9]{1,4} MB/s|[0-9]{1,4}.[0-9]{1,2} MB/s|[0-9]{1,4} GB/s|[0-9]{1,4}.[0-9]{1,2} GB/s|[0-9]{1,4} TB/s|[0-9]{1,4}.[0-9]{1,2} TB/s|[0-9]{1,4} kB/秒|[0-9]{1,4}.[0-9]{1,2} kB/秒|[0-9]{1,4} KB/秒|[0-9]{1,4}.[0-9]{1,2} KB/秒|[0-9]{1,4} MB/秒|[0-9]{1,4}.[0-9]{1,2} MB/秒|[0-9]{1,4} GB/秒|[0-9]{1,4}.[0-9]{1,2} GB/秒|[0-9]{1,4} TB/秒|[0-9]{1,4}.[0-9]{1,2} TB/秒")"
    DiskTest_WriteSpeed="$(echo "${DiskTest_WriteSpeed_ResultRAW}" | sed "s/秒/s/")"
    local DiskTest_WriteTime_ResultRAW="$(cat ${Var_DiskTestResultFile} | grep -oE "[0-9]{1,}.[0-9]{1,} s|[0-9]{1,}.[0-9]{1,} s|[0-9]{1,}.[0-9]{1,} 秒|[0-9]{1,}.[0-9]{1,} 秒")"
    DiskTest_WriteTime="$(echo ${DiskTest_WriteTime_ResultRAW} | awk '{print $1}')"
    DiskTest_WriteIOPS="$(echo ${DiskTest_WriteTime} $3 | awk '{printf "%d\n",$2/$1}')"
    DiskTest_WritePastTime="$(echo ${DiskTest_WriteTime} | awk '{printf "%.2f\n",$1}')"
    if [ "${DiskTest_WriteIOPS}" -ge "10000" ]; then
        DiskTest_WriteIOPS="$(echo ${DiskTest_WriteIOPS} 1000 | awk '{printf "%.2f\n",$2/$1}')"
        echo -n -e "\r $4\t\t${Font_SkyBlue}${DiskTest_WriteSpeed} (${DiskTest_WriteIOPS}K IOPS, ${DiskTest_WritePastTime}s)${Font_Suffix}\t\t->\c"
    else
        echo -n -e "\r $4\t\t${Font_SkyBlue}${DiskTest_WriteSpeed} (${DiskTest_WriteIOPS} IOPS, ${DiskTest_WritePastTime}s)${Font_Suffix}\t\t->\c"
    fi
    # 清理结果文件, 准备下一次测试
    rm -f ${Var_DiskTestResultFile}
    # 清理缓存, 避免影响测试结果
    sync
    if [ "${Var_VirtType}" != "docker" ] && [ "${Var_VirtType}" != "wsl" ]; then
        if [ -w /proc/sys/vm/drop_caches ]; then
            echo 3 >/proc/sys/vm/drop_caches > /dev/null 2>&1
        fi
    fi
    sleep 0.5
    # 正式读测试
    dd if=/.tmp_LBench/DiskTest/$1 of=/dev/null bs=$2 count=$3 iflag=direct 2>${Var_DiskTestResultFile}
    local DiskTest_ReadSpeed_ResultRAW="$(cat ${Var_DiskTestResultFile} | grep -oE "[0-9]{1,4} kB/s|[0-9]{1,4}.[0-9]{1,2} kB/s|[0-9]{1,4} KB/s|[0-9]{1,4}.[0-9]{1,2} KB/s|[0-9]{1,4} MB/s|[0-9]{1,4}.[0-9]{1,2} MB/s|[0-9]{1,4} GB/s|[0-9]{1,4}.[0-9]{1,2} GB/s|[0-9]{1,4} TB/s|[0-9]{1,4}.[0-9]{1,2} TB/s|[0-9]{1,4} kB/秒|[0-9]{1,4}.[0-9]{1,2} kB/秒|[0-9]{1,4} KB/秒|[0-9]{1,4}.[0-9]{1,2} KB/秒|[0-9]{1,4} MB/秒|[0-9]{1,4}.[0-9]{1,2} MB/秒|[0-9]{1,4} GB/秒|[0-9]{1,4}.[0-9]{1,2} GB/秒|[0-9]{1,4} TB/秒|[0-9]{1,4}.[0-9]{1,2} TB/秒")"
    DiskTest_ReadSpeed="$(echo "${DiskTest_ReadSpeed_ResultRAW}" | sed "s/s/s/")"
    local DiskTest_ReadTime_ResultRAW="$(cat ${Var_DiskTestResultFile} | grep -oE "[0-9]{1,}.[0-9]{1,} s|[0-9]{1,}.[0-9]{1,} s|[0-9]{1,}.[0-9]{1,} 秒|[0-9]{1,}.[0-9]{1,} 秒")"
    DiskTest_ReadTime="$(echo ${DiskTest_ReadTime_ResultRAW} | awk '{print $1}')"
    DiskTest_ReadIOPS="$(echo ${DiskTest_ReadTime} $3 | awk '{printf "%d\n",$2/$1}')"
    DiskTest_ReadPastTime="$(echo ${DiskTest_ReadTime} | awk '{printf "%.2f\n",$1}')"
    rm -f ${Var_DiskTestResultFile}
    # 输出结果
    echo -n -e "\r $4\t\t${Font_SkyBlue}${DiskTest_WriteSpeed} (${DiskTest_WriteIOPS} IOPS, ${DiskTest_WritePastTime}s)${Font_Suffix}\t\t${Font_SkyBlue}${DiskTest_ReadSpeed} (${DiskTest_ReadIOPS} IOPS, ${DiskTest_ReadPastTime}s)${Font_Suffix}\n"
    echo -e " $4\t\t${DiskTest_WriteSpeed} (${DiskTest_WriteIOPS} IOPS, ${DiskTest_WritePastTime} s)\t\t${DiskTest_ReadSpeed} (${DiskTest_ReadIOPS} IOPS, ${DiskTest_ReadPastTime} s)" >>${WorkDir}/DiskTest/result.txt
    rm -rf /.tmp_LBench/DiskTest/
}

Function_DiskTest_Fast() {
    mkdir -p ${WorkDir}/DiskTest/ >/dev/null 2>&1
    echo -e " ${Font_Yellow}-> 磁盘IO测试中 (4K Block/1M Block, Direct Mode)${Font_Suffix}"
    echo -e " -> 磁盘IO测试中 (4K Block/1M Block, Direct Mode)\n" >>${WorkDir}/DiskTest/result.txt
    SystemInfo_GetVirtType
    SystemInfo_GetOSRelease
    if [ "${Var_VirtType}" = "docker" ] || [ "${Var_VirtType}" = "wsl" ]; then
        echo -e " ${Msg_Warning}Due to virt architecture limit, the result may affect by the cache !\n"
    fi
    echo -e " ${Font_Yellow}测试操作\t\t写速度\t\t\t\t\t读速度${Font_Suffix}"
    echo -e " Test Name\t\tWrite Speed\t\t\t\tRead Speed" >>${WorkDir}/DiskTest/result.txt
    Run_DiskTest_DD "100MB.test" "4k" "25600" "100MB-4K Block"
    Run_DiskTest_DD "1GB.test" "1M" "1000" "1GB-1M Block"
    # 执行完成, 标记FLAG
    LBench_Flag_FinishDiskTestFast="1"
    sleep 0.5
}

# =============== SysBench - 内存性能 部分 ===============
Run_SysBench_Memory() {
    # 调用方式: Run_SysBench_Memory "线程数" "测试时长(s)" "测试遍数" "测试模式(读/写)" "读写方式(顺序/随机)" "说明"
    # 变量初始化
    mkdir -p ${WorkDir}/SysBench/Memory/ >/dev/null 2>&1
    maxtestcount="$3"
    local count="1"
    local TestScore="0.00"
    local TestSpeed="0.00"
    local TotalScore="0.00"
    local TotalSpeed="0.00"
    if [ "$1" -ge "2" ]; then
        MultiThread_Flag="1"
    else
        MultiThread_Flag="0"
    fi
    # 运行测试
    while [ $count -le $maxtestcount ]; do
        if [ "$1" -ge "2" ] && [ "$4" = "write" ]; then
            echo -e "\r ${Font_Yellow}$6:${Font_Suffix}\t$count/$maxtestcount \c"
        else
            echo -e "\r ${Font_Yellow}$6:${Font_Suffix}\t\t$count/$maxtestcount \c"
        fi
        local TestResult="$(sysbench --test=memory --num-threads=$1 --memory-block-size=1M --memory-total-size=102400G --memory-oper=$4 --max-time=$2 --memory-access-mode=$5 run 2>&1)"
        # 判断是MB还是MiB
        echo "${TestResult}" | grep -oE "MiB" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            local MiB_Flag="1"
        else
            local MiB_Flag="0"
        fi
        local TestScore="$(echo "${TestResult}" | grep -oE "[0-9]{1,}.[0-9]{1,2} ops/sec|[0-9]{1,}.[0-9]{1,2} per second" | grep -oE "[0-9]{1,}.[0-9]{1,2}")"
        local TestSpeed="$(echo "${TestResult}" | grep -oE "[0-9]{1,}.[0-9]{1,2} MB/sec|[0-9]{1,}.[0-9]{1,2} MiB/sec" | grep -oE "[0-9]{1,}.[0-9]{1,2}")"
        local TotalScore="$(echo "${TotalScore} ${TestScore}" | awk '{printf "%.2f",$1+$2}')"
        local TotalSpeed="$(echo "${TotalSpeed} ${TestSpeed}" | awk '{printf "%.2f",$1+$2}')"
        let count=count+1
        local TestResult=""
        local TestScore="0.00"
        local TestSpeed="0.00"
    done
    ResultScore="$(echo "${TotalScore} ${maxtestcount} 1000" | awk '{printf "%.2f",$1/$2/$3}')"
    if [ "${MiB_Flag}" = "1" ]; then
        # MiB to MB
        ResultSpeed="$(echo "${TotalSpeed} ${maxtestcount} 1048576 1000000" | awk '{printf "%.2f",$1/$2/$3*$4}')"
    else
        # 直接输出
        ResultSpeed="$(echo "${TotalSpeed} ${maxtestcount}" | awk '{printf "%.2f",$1/$2}')"
    fi
    # 1线程的测试结果写入临时变量，方便与后续的多线程变量做对比
    if [ "$1" = "1" ] && [ "$4" = "read" ]; then
        LBench_Result_MemoryReadSpeedSingle="${ResultSpeed}"
    elif [ "$1" = "1" ] &&[ "$4" = "write" ]; then
        LBench_Result_MemoryWriteSpeedSingle="${ResultSpeed}"
    fi
    if [ "${MultiThread_Flag}" = "1" ]; then
        # 如果是多线程测试，输出与1线程测试对比的倍率
        if [ "$1" -ge "2" ] && [ "$4" = "read" ]; then
            LBench_Result_MemoryReadSpeedMulti="${ResultSpeed}"
            local readmultiple="$(echo "${LBench_Result_MemoryReadSpeedMulti} ${LBench_Result_MemoryReadSpeedSingle}" | awk '{printf "%.2f", $1/$2}')"
            echo -e "\r ${Font_Yellow}$6:${Font_Suffix}\t\t${Font_SkyBlue}${LBench_Result_MemoryReadSpeedMulti}${Font_Suffix} ${Font_Yellow}MB/s${Font_Suffix} (${readmultiple} x)"
        elif [ "$1" -ge "2" ] && [ "$4" = "write" ]; then
            LBench_Result_MemoryWriteSpeedMulti="${ResultSpeed}"
            local writemultiple="$(echo "${LBench_Result_MemoryWriteSpeedMulti} ${LBench_Result_MemoryWriteSpeedSingle}" | awk '{printf "%.2f", $1/$2}')"
            echo -e "\r ${Font_Yellow}$6:${Font_Suffix}\t\t${Font_SkyBlue}${LBench_Result_MemoryWriteSpeedMulti}${Font_Suffix} ${Font_Yellow}MB/s${Font_Suffix} (${writemultiple} x)"
        fi
    else
        if [ "$4" = "read" ]; then
            echo -e "\r ${Font_Yellow}$6:${Font_Suffix}\t\t${Font_SkyBlue}${ResultSpeed}${Font_Suffix} ${Font_Yellow}MB/s${Font_Suffix}"
        elif [ "$4" = "write" ]; then
            echo -e "\r ${Font_Yellow}$6:${Font_Suffix}\t\t${Font_SkyBlue}${ResultSpeed}${Font_Suffix} ${Font_Yellow}MB/s${Font_Suffix}"
        fi
    fi
    # Fix
    if [ "$1" -ge "2" ] && [ "$4" = "write" ]; then
        echo -e " $6:\t${ResultSpeed} MB/s" >>${WorkDir}/SysBench/Memory/result.txt
    else
        echo -e " $6:\t\t${ResultSpeed} MB/s" >>${WorkDir}/SysBench/Memory/result.txt
    fi
    sleep 0.5
    
}

Function_SysBench_Memory_Fast() {
    mkdir -p ${WorkDir}/SysBench/Memory/ >/dev/null 2>&1
    echo -e " ${Font_Yellow}-> 内存测试 Test (Fast Mode, 1-Pass @ 5sec)${Font_Suffix}"
    echo -e " -> 内存测试 (Fast Mode, 1-Pass @ 5sec)\n" >>${WorkDir}/SysBench/Memory/result.txt
    Run_SysBench_Memory "1" "5" "1" "read" "seq" "单线程读测试"
    Run_SysBench_Memory "1" "5" "1" "write" "seq" "单线程写测试"
    sleep 0.5
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "K" ] && size=0
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

check_virt(){
    _exists "dmesg" && virtualx="$(dmesg 2>/dev/null)"
    if _exists "dmidecode"; then
        output="$(dmidecode -s system-manufacturer -s system-product-name -s system-version 2>/dev/null)"
        sys_manu="$(echo "$output" | sed -n 1p)"
        sys_product="$(echo "$output" | sed -n 2p)"
        sys_ver="$(echo "$output" | sed -n 3p)"
    else
        sys_manu=""
        sys_product=""
        sys_ver=""
    fi
    if grep -qa docker /proc/1/cgroup || grep -qa lxc /proc/1/cgroup || grep -qa container=lxc /proc/1/environ; then
        virt="LXC"
    elif [[ -f /proc/user_beancounters ]]; then
        virt="OpenVZ"
    elif [[ "${virtualx}" == *kvm-clock* ]]; then
        virt="KVM"
    elif [[ "${cname}" == *KVM* ]] || [[ "${cname}" == *QEMU* ]]; then
        virt="KVM"
    elif [[ "${virtualx}" == *"VMware Virtual Platform"* ]]; then
        virt="VMware"
    elif [[ "${virtualx}" == *"Parallels Software International"* ]]; then
        virt="Parallels"
    elif [[ "${virtualx}" == *VirtualBox* ]]; then
        virt="VirtualBox"
    elif [[ -e /proc/xen ]]; then
        if grep -q "control_d" "/proc/xen/capabilities" 2>/dev/null; then
            virt="Xen-Dom0"
        else
            virt="Xen-DomU"
        fi
    elif [[ -f "/sys/hypervisor/type" ]] && grep -q "xen" "/sys/hypervisor/type"; then
        virt="Xen"
    elif [[ "${sys_manu}" == *"Microsoft Corporation"* ]] && [[ "${sys_product}" == *"Virtual Machine"* ]]; then
        if [[ "${sys_ver}" == *"7.0"* || "${sys_ver}" == *"Hyper-V" ]]; then
            virt="Hyper-V"
        else
            virt="Microsoft Virtual Machine"
        fi
    else
        SystemInfo_GetVirtType
        virt="${Var_VirtType}"
    fi
}

ipv4_info() {
    local org="$(wget -q -T10 -O- ipinfo.io/org)"
    local city="$(wget -q -T10 -O- ipinfo.io/city)"
    local country="$(wget -q -T10 -O- ipinfo.io/country)"
    local region="$(wget -q -T10 -O- ipinfo.io/region)"
    if [[ -n "$org" ]]; then
        echo " ASN组织           : $(_blue "$org")"
    fi
    if [[ -n "$city" && -n "$country" ]]; then
        echo " 位置              : $(_blue "$city / $country")"
    fi
    if [[ -n "$region" ]]; then
        echo " 地区              : $(_yellow "$region")"
    fi
    if [[ -z "$org" ]]; then
        echo " 地区              : $(_red "无法获取ISP信息")"
    fi
}

print_intro() {
    echo "-------------------- A Bench Script By spiritlhl ---------------------"
    echo "                   测评频道: https://t.me/vps_reviews                    "
    echo "版本：$ver"
    echo "更新日志：$changeLog"
}

get_system_info() {
    cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    cores=$( awk -F: '/processor/ {core++} END {print core}' /proc/cpuinfo )
    freq=$( awk -F'[ :]' '/cpu MHz/ {print $4;exit}' /proc/cpuinfo )
    ccache=$( awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    tram=$( LANG=C; free -m | awk '/Mem/ {print $2}' )
    uram=$( LANG=C; free -m | awk '/Mem/ {print $3}' )
    swap=$( LANG=C; free -m | awk '/Swap/ {print $2}' )
    uswap=$( LANG=C; free -m | awk '/Swap/ {print $3}' )
    up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime )
    if _exists "w"; then
        load=$( LANG=C; w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    elif _exists "uptime"; then
        load=$( LANG=C; uptime | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    fi
    opsy=$( get_opsy )
    arch=$( uname -m )
    if _exists "getconf"; then
        lbit=$( getconf LONG_BIT )
    else
        echo ${arch} | grep -q "64" && lbit="64" || lbit="32"
    fi
    kern=$( uname -r )
    disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker|snapd' | awk '{print $2}' ))
    disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker|snapd' | awk '{print $3}' ))
    disk_total_size=$( calc_disk "${disk_size1[@]}" )
    disk_used_size=$( calc_disk "${disk_size2[@]}" )
    if [ ! -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        echo "未设置TCP拥塞控制算法"
    else
        if [ -f "/usr/sbin/sysctl" ]; then
            tcpctrl=$( /usr/sbin/sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )
        elif [ -f "/sbin/sysctl" ]; then
            tcpctrl=$( /sbin/sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )
        else
            tcpctrl=$( sysctl net.ipv4.tcp_congestion_control 2> /dev/null | awk -F ' ' '{print $3}' )
            if [ $? -ne 0 ]; then
                tcpctrl="None"
            fi
        fi
    fi
}

isvalidipv4()
{
    local ipaddr=$1
    local stat=1
    if [[ $ipaddr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ipaddr=($ipaddr)
        IFS=$OIFS
        [[ ${ipaddr[0]} -le 255 && ${ipaddr[1]} -le 255 \
            && ${ipaddr[2]} -le 255 && ${ipaddr[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

cnlatency() {    
    ipaddr=$(getent ahostsv4 $1 | grep STREAM | head -n 1 | cut -d ' ' -f 1)
	if isvalidipv4 "$ipaddr"; then
		host=$2
		retry=1
		rtt=999	
		while [[ "$retry" < 4 ]] ; do
			echo -en "\r\033[0K [$3 of $4] : $host ($ipaddr) attemp #$retry"
			rtt=$(ping -c1 -w1 $ipaddr | sed -nE 's/.*time=([0-9.]+).*/\1/p')				
			if [[ -z "$rtt" ]]; then
				rtt=999
				retry=$((retry+1))
				continue
			fi
			[[ "$rtt" < 1 ]] && rtt=1
			int=${rtt%.*}
			if [[ "$int" -gt 999 || "$int" -eq 0 ]]; then
				rtt=999
				break
			fi
			rtt=$(printf "%.0f" $rtt)
			rtt=$(printf "%03d" $rtt)
			break
		done
		result="${rtt}ms : $host , $ipaddr"
		CHINALIST[${#CHINALIST[@]}]=$result		
	fi
}

# https://github.com/xsidc/zbench/blob/master/ZPing-CN.py
# https://ipasn.com/bench.sh
chinaping() {
    # start=$(date +%s)
    # echostyle "++ China Latency Test"
    echo "-------------------延迟测试--感谢ipasn开源本人整理---------------------" | tee -a $LOG
    declare -a LIST
    LIST[${#LIST[@]}]="ec2.cn-north-1.amazonaws.com.cn•北京, Amazon Cloud"
    LIST[${#LIST[@]}]="ec2.cn-northwest-1.amazonaws.com.cn•宁夏, Amazon Cloud"
    LIST[${#LIST[@]}]="bss.bd.baidubce.com•河北保定, Baidu Cloud"
    LIST[${#LIST[@]}]="bss.bj.baidubce.com•北京, Baidu Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs-1251417183.cos-website.ap-beijing.myqcloud.com•北京, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs-1251417183.cos-website.ap-chengdu.myqcloud.com•四川成都, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs-1251417183.cos-website.ap-chongqing.myqcloud.com•重庆, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs-1251417183.cos-website.ap-guangzhou.myqcloud.com•广东广州, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs-1251417183.cos-website.ap-nanjing.myqcloud.com•江苏南京, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs-1251417183.cos-website.ap-shanghai.myqcloud.com•上海, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs-fsi-1251417183.cos-website.ap-beijing-fsi.myqcloud.com•北京金融, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-bjs.cn-bj.ufileos.com•北京, UCloud"
    LIST[${#LIST[@]}]="feitsui-can.cn-gd.ufileos.com•广东广州, UCloud"
    LIST[${#LIST[@]}]="feitsui-can.obs-website.cn-south-1.myhuaweicloud.com•广东广州, Huawei Cloud"
    LIST[${#LIST[@]}]="bss.gz.baidubce.com•广东广州, Baidu Cloud"
    LIST[${#LIST[@]}]="feitsui-kwe1.obs-website.cn-southwest-2.myhuaweicloud.com•贵州贵阳, Huawei Cloud"
    LIST[${#LIST[@]}]="feitsui-pek1.obs-website.cn-north-1.myhuaweicloud.com•北京1, Huawei Cloud"
    LIST[${#LIST[@]}]="feitsui-pek4.obs-website.cn-north-4.myhuaweicloud.com•北京2, Huawei Cloud"
    LIST[${#LIST[@]}]="feitsui-sha-fsi-1251417183.cos-website.ap-shanghai-fsi.myqcloud.com•上海金融, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-sha1.obs-website.cn-east-3.myhuaweicloud.com•上海1, Huawei Cloud"
    LIST[${#LIST[@]}]="feitsui-sha2.cn-sh2.ufileos.com•上海2, UCloud"
    LIST[${#LIST[@]}]="feitsui-sha2.obs-website.cn-east-2.myhuaweicloud.com•上海2, Huawei Cloud"
    LIST[${#LIST[@]}]="bss.fsh.baidubce.com•上海, Baidu Cloud"
    LIST[${#LIST[@]}]="bss.su.baidubce.com•江苏苏州, Baidu Cloud"
    LIST[${#LIST[@]}]="feitsui-szx-fsi-1251417183.cos-website.ap-shenzhen-fsi.myqcloud.com•广东深圳金融, Tencent Cloud"
    LIST[${#LIST[@]}]="feitsui-ucb.obs-website.cn-north-9.myhuaweicloud.com•内蒙古乌兰察布, Huawei Cloud"
    LIST[${#LIST[@]}]="bss.fwh.baidubce.com•湖北武汉, Baidu Cloud"
    LIST[${#LIST[@]}]="ks3-cn-beijing.ksyuncs.com•北京, Kingsoft Cloud"
    LIST[${#LIST[@]}]="ks3-cn-guangzhou.ksyuncs.com•广东广州, Kingsoft Cloud"
    LIST[${#LIST[@]}]="ks3-cn-shanghai.ksyuncs.com•上海, Kingsoft Cloud"
    LIST[${#LIST[@]}]="ks3-gov-beijing.ksyuncs.com•北京政府, Kingsoft Cloud"
    LIST[${#LIST[@]}]="ks3-jr-beijing.ksyuncs.com•北京金融, Kingsoft Cloud"
    LIST[${#LIST[@]}]="ks3-jr-shanghai.ksyuncs.com•上海金融, Kingsoft Cloud"
    LIST[${#LIST[@]}]="oss-cn-beijing.aliyuncs.com•北京, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-chengdu.aliyuncs.com•四川成都, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-guangzhou.aliyuncs.com•广东广州, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-hangzhou.aliyuncs.com•浙江杭州, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-heyuan.aliyuncs.com•广东河源, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-huhehaote.aliyuncs.com•内蒙古呼和浩特, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-nanjing.aliyuncs.com•江苏南京, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-qingdao.aliyuncs.com•山东青岛, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-shanghai.aliyuncs.com•上海, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-shenzhen.aliyuncs.com•广东深圳, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-wulanchabu.aliyuncs.com•内蒙古乌兰察布, Alibaba Cloud"
    LIST[${#LIST[@]}]="oss-cn-zhangjiakou.aliyuncs.com•河北张家口, Alibaba Cloud"
    IFS=$'\n' LIST=($(shuf <<<"${LIST[*]}"))
    unset IFS
    INDEX=0
    TOTAL=${#LIST[@]}
    for arr in "${LIST[@]}"
    do
        INDEX=$(( $INDEX + 1 ))
		param1=$( awk '{split($0, val, "•"); print val[1]}' <<< $arr )
		param2=$( awk '{split($0, val, "•"); print val[2]}' <<< $arr )
        cnlatency "$param1" "$param2" "${INDEX}" "${TOTAL}"
    done
    IFS=$'\n' SORTED=($(sort <<<"${CHINALIST[*]}"))
    unset IFS
    echo -e "\r\033[0K"
    for arr in "${SORTED[@]}"
    do
        echo " $arr" | tee -a $LOG
    done
}

print_system_info() {
    if [ -n "$cname" ]; then
        echo " CPU 型号          : $(_blue "$cname")"
    else
        echo " CPU 型号          : $(_blue "无法检测到CPU型号")"
    fi
    echo " CPU 核心数        : $(_blue "$cores")"
    if [ -n "$freq" ]; then
        echo " CPU 频率          : $(_blue "$freq MHz")"
    fi
    if [ -n "$ccache" ]; then
        echo " CPU 缓存          : $(_blue "$ccache")"
    fi
    echo " 硬盘空间          : $(_yellow "$disk_total_size GB") $(_blue "($disk_used_size GB 已用)")"
    echo " 内存              : $(_yellow "$tram MB") $(_blue "($uram MB 已用)")"
    echo " Swap              : $(_blue "$swap MB ($uswap MB 已用)")"
    echo " 系统在线时间      : $(_blue "$up")"
    echo " 负载              : $(_blue "$load")"
    DISTRO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d '"' -f 2 )
    echo " 系统              : $(_blue "$DISTRO")"  
    # $(_blue "$opsy")"
    CPU_AES=$(cat /proc/cpuinfo | grep aes)
    [[ -z "$CPU_AES" ]] && CPU_AES="\xE2\x9D\x8C Disabled" || CPU_AES="\xE2\x9C\x94 Enabled"
    echo " AES-NI指令集      : $(_blue "$CPU_AES")"  
    CPU_VIRT=$(cat /proc/cpuinfo | grep 'vmx\|svm')
    [[ -z "$CPU_VIRT" ]] && CPU_VIRT="\xE2\x9D\x8C Disabled" || CPU_VIRT="\xE2\x9C\x94 Enabled"
    echo " VM-x/AMD-V支持    : $(_blue "$CPU_VIRT")"  
    echo " 架构              : $(_blue "$arch ($lbit Bit)")"
    echo " 内核              : $(_blue "$kern")"
    echo " TCP加速方式       : $(_yellow "$tcpctrl")"
    echo " 虚拟化架构        : $(_blue "$virt")"
}

print_end_time() {
    end_time=$(date +%s)
    time=$(( ${end_time} - ${start_time} ))
    if [ ${time} -gt 60 ]; then
        min=$(expr $time / 60)
        sec=$(expr $time % 60)
        echo " 总共花费        : ${min} 分 ${sec} 秒"
    else
        echo " 总共花费        : ${time} 秒"
    fi
    date_time=$(date)
    # date_time=$(date +%Y-%m-%d" "%H:%M:%S)
    echo " 时间          : $date_time"
}

geekbench() {
    cd /root >/dev/null 2>&1
    echo -e "----------------Geekbenh得分--感谢supeerbench的开源--------------------"
	echo -e " Geekbench v${GeekbenchVer} Test    :" | tee -a $log
	if test -f "geekbench.license"; then
		./geekbench/geekbench$GeekbenchVer --unlock `cat geekbench.license` > /dev/null 2>&1
	fi
	GEEKBENCH_TEST=$(./geekbench/geekbench$GeekbenchVer --upload 2>/dev/null | grep "https://browser")
	if [[ -z "$GEEKBENCH_TEST" ]]; then
		echo -e " ${RED}Geekbench v${GeekbenchVer} test failed. Run manually to determine cause.${PLAIN}" | tee -a $log
		GEEKBENCH_URL=''
		if [[ $GeekbenchVer == *5* && $ARCH != *aarch64* && $ARCH != *arm* ]]; then
			rm -rf geekbench
			download_geekbench4;
			echo -n -e "\r" | tee -a $log
			GeekbenchVer=4;
			geekbench;
		fi
	else
		GEEKBENCH_URL=$(echo -e $GEEKBENCH_TEST | head -1)
		GEEKBENCH_URL_CLAIM=$(echo $GEEKBENCH_URL | awk '{ print $2 }')
		GEEKBENCH_URL=$(echo $GEEKBENCH_URL | awk '{ print $1 }')
		sleep 20
		[[ $GeekbenchVer == *5* ]] && GEEKBENCH_SCORES=$(curl -s $GEEKBENCH_URL | grep "div class='score'") || GEEKBENCH_SCORES=$(curl -s $GEEKBENCH_URL | grep "span class='score'")
		GEEKBENCH_SCORES_SINGLE=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $3 }')
		GEEKBENCH_SCORES_MULTI=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $7 }')
		echo -e "       Single Core    : ${YELLOW}$GEEKBENCH_SCORES_SINGLE  $grank${PLAIN}"  | tee -a $log
		echo -e "        Multi Core    : ${YELLOW}$GEEKBENCH_SCORES_MULTI${PLAIN}" | tee -a $log
		[ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
	fi
	rm -rf geekbench
}

download_geekbench4(){
	if [[ ! -d ./geekbench ]]; then
		mkdir geekbench
	fi
	if [[ ! -d ./geekbench/geekbench4 ]]; then
		echo -n -e " Installing Geekbench 4..."
		wget -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-4.4.4-Linux.tar.gz | tar xz --strip-components=1 -C ./geekbench &>/dev/null
	fi
	chmod +x ./geekbench/geekbench4
}

geekbench_script(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    cd /root >/dev/null 2>&1
    ARCH=$(uname -m)
    if [[ ! -e './geekbench' ]]; then
			mkdir geekbench
    fi
    GeekbenchVer=5
    if [[ $ARCH = *x86* ]]; then
        download_geekbench4;
        $GeekbenchVer=4
    elif [[ $ARCH != *aarch64* && $ARCH != *arm* ]]; then
        if [ ! -e './geekbench/geekbench5' ]; then
            echo " Installing Geekbench 5..."
            wget -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-5.4.4-Linux.tar.gz  | tar xz --strip-components=1 -C ./geekbench &>/dev/null
        fi
        chmod +x ./geekbench/geekbench5
    else
        if [ ! -e './geekbench/geekbench5' ]; then
            echo " Installing Geekbench 5..."
            wget -qO- https://down.vpsaff.net/linux/geekbench/Geekbench-5.4.4-LinuxARMPreview.tar.gz  | tar xz --strip-components=1 -C ./geekbench &>/dev/null
        fi
        chmod +x ./geekbench/geekbench5
    fi
    sleep 1
    check_virt
    start_time=$(date +%s)
    clear
    print_intro
    geekbench
    end_script
}

python_all_script(){
    checkpython
    checkmagic
    export PYTHONIOENCODING=utf-8
    curl -L -k "${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/ecs/main/qzcheck_ecs.py" -o qzcheck_ecs.py 
    curl -L -k "${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/ecs/main/googlesearchcheck.py" -o googlesearchcheck.py
    # curl -L -k "${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/ecs/main/tkcheck.py" -o tk.py
    sleep 0.5
    python3 googlesearchcheck.py
}

check_lmc_script(){
    checkpython
    export PYTHONIOENCODING=utf-8
    # curl -L -k "${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/ecs/main/tkcheck.py" -o tk.py
    curl -L -k "${cdn_success_url}https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh" -o media_lmc_check.sh
    chmod 777 media_lmc_check.sh
    sleep 0.5
}

python_gd_script(){
    checkpython
    checkmagic
    export PYTHONIOENCODING=utf-8
    curl -L -k "${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/ecs/main/qzcheck_ecs.py" -o qzcheck_ecs.py 
    curl -L -k "${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/ecs/main/googlesearchcheck.py" -o googlesearchcheck.py
    sleep 0.5
    python3 googlesearchcheck.py
}

cdn_urls=("https://ghproxy.com/" "https://cdn.spiritlhl.workers.dev/" "https://shrill-pond-3e81.hunsh.workers.dev/" "http://104.168.128.181:7823/" "https://gh.api.99988866.xyz/")

pre_check(){
    checkupdate
    checkroot
    checkwget
    checksystem
    checkcurl
    check_cdn_file
    Global_StartupInit_Action
    cd /root >/dev/null 2>&1
    curl -L -k https://gitlab.com/spiritysdx/za/-/raw/main/yabsiotest.sh -o yabsiotest.sh && chmod +x yabsiotest.sh  >/dev/null 2>&1
    ! _exists "wget" && _red "Error: wget command not found.\n" && exit 1
    ! _exists "free" && _red "Error: free command not found.\n" && exit 1
}

sjlleo_script(){
    cd /root >/dev/null 2>&1
    echo "--------------------流媒体解锁--感谢sjlleo开源------------------------"
    yellow "以下测试的解锁地区是准确的，但是不是完整解锁的判断可能有误，这方面仅作参考使用"
    yellow "Youtube"
    ./tubecheck | sed "/@sjlleo/d"
    sleep 0.5
    yellow "Netflix"
    ./nf | sed "/@sjlleo/d;/^$/d"
    sleep 0.5
    yellow "DisneyPlus"
    ./dp | sed "/@sjlleo/d"
    sleep 0.5
    yellow "解锁Youtube，Netflix，DisneyPlus上面和下面进行比较，不同之处自行判断"
}

basic_script(){
    echo "-----------------感谢teddysun和misakabench和yabs开源------------------"
    print_system_info
    ipv4_info
    cd /root >/dev/null 2>&1
    sleep 1
    echo "-------------------CPU测试--感谢lemonbench开源------------------------"
    Entrance_SysBench_CPU_Fast
    cd /root >/dev/null 2>&1
    sleep 1
    echo "-------------------内存测试--感谢lemonbench开源-----------------------"
    Function_SysBench_Memory_Fast
}

io1_script(){
    cd /root >/dev/null 2>&1
    sleep 1
    echo "----------------磁盘IO读写测试--感谢lemonbench开源--------------------"
    Function_DiskTest_Fast
    Global_Exit_Action >/dev/null 2>&1
}

io2_script(){
    cd /root >/dev/null 2>&1
    echo "-------------------磁盘IO读写测试--感谢yabs开源-----------------------"
    bash ./yabsiotest.sh 
    rm -rf yabsiotest.sh
}

RegionRestrictionCheck_script(){
    echo -e "---------------流媒体解锁--感谢RegionRestrictionCheck开源-------------"
    yellow " 以下为IPV4网络测试，若无IPV4网络则无输出"
    echo 0 | bash media_lmc_check.sh -M 4 | grep -A999999 '============\[ Multination \]============' | sed '/=======================================/q'
    yellow " 以下为IPV6网络测试，若无IPV6网络则无输出"
    echo 0 | bash media_lmc_check.sh -M 6 | grep -A999999 '============\[ Multination \]============' | sed '/=======================================/q'
}

function UnlockTiktokTest() {
    cd /root >/dev/null 2>&1
    echo -e "----------------TikTok解锁--感谢superbench的开源脚本------------------"
	local result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://www.tiktok.com/" 2>&1);
    if [[ "$result" != "curl"* ]]; then
        result="$(echo ${result} | grep 'region' | awk -F 'region":"' '{print $2}' | awk -F '"' '{print $1}')";
		if [ -n "$result" ]; then
			if [[ "$result" == "The #TikTokTraditions"* ]] || [[ "$result" == "This LIVE isn't available"* ]]; then
				echo -e " TikTok               : ${RED}No${PLAIN}" | tee -a $log
			else
				echo -e " TikTok               : ${GREEN}Yes (Region: ${result})${PLAIN}" | tee -a $log
			fi
		else
			echo -e " TikTok               : ${RED}Failed${PLAIN}" | tee -a $log
			return
		fi
    else
		echo -e " TikTok               : ${RED}Network connection failed${PLAIN}" | tee -a $log
	fi
}

spiritlhl_script(){
    cd /root >/dev/null 2>&1
    echo -e "-----------------欺诈分数以及IP质量检测--本频道原创-------------------"
    yellow "得分仅作参考，不代表100%准确，IP类型如果不一致请手动查询多个数据库比对"
    if ! python3 qzcheck_ecs.py 2> /dev/null ; then
        if ! python3 qzcheck_ecs.py 2> /dev/null ; then
            echo "执行失败，可能是Python版本过低，也可能是安装失败"
        fi
    fi
}

backtrace_script(){
    echo -e "-----------------三网回程--感谢zhanghanyun/backtrace开源--------------"
    curl -k "${cdn_success_url}https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh" -sSf | sh
}

fscarmen_route_g_script(){
    echo -e "------------------回程路由--感谢fscarmen开源及PR----------------------"
    rm -f $TEMP_FILE
    IP_4=$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip) &&
    WAN_4=$(expr "$IP_4" : '.*ip\":[ ]*\"\([^"]*\).*') &&
    ASNORG_4=$(expr "$IP_4" : '.*isp\":[ ]*\"\([^"]*\).*') &&
    _blue " IPv4 ASN: $ASNORG_4" >> $TEMP_FILE
    IP_6=$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip) &&
    WAN_6=$(expr "$IP_6" : '.*ip\":[ ]*\"\([^"]*\).*') &&
    ASNORG_6=$(expr "$IP_6" : '.*isp\":[ ]*\"\([^"]*\).*') &&
    _blue " IPv6 ASN: $ASNORG_6" >> $TEMP_FILE
    local ARCHITECTURE="$(uname -m)"
      case $ARCHITECTURE in
        x86_64 )  local FILE=besttrace;;
        aarch64 ) local FILE=besttracearm;;
        i386 )    local FILE=besttracemac;;
        * ) red " 只支持 AMD64、ARM64、Mac 使用，问题反馈:[https://github.com/fscarmen/tools/issues] " && return;;
      esac
    curl -s -L -k "${cdn_success_url}https://github.com/fscarmen/tools/raw/main/besttrace/${FILE}" -o $FILE && chmod +x $FILE &>/dev/null
    _green "依次测试电信，联通，移动经过的地区及线路，核心程序来由: ipip.net ，请知悉!" >> $TEMP_FILE
    for ((a=0;a<${#test_area_g[@]};a++)); do
    _yellow "${test_area_g[a]} ${test_ip_g[a]}" >> $TEMP_FILE
    ./"$FILE" "${test_ip_g[a]}" -g cn | sed "s/^[ ]//g" | sed "/^[ ]/d" | sed '/ms/!d' | sed "s#.* \([0-9.]\+ ms.*\)#\1#g" >> $TEMP_FILE
    done
    cat $TEMP_FILE
    rm -f $TEMP_FILE
}

fscarmen_route_s_script(){
    echo -e "------------------回程路由--感谢fscarmen开源及PR----------------------"
    rm -f $TEMP_FILE
    IP_4=$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip) &&
    WAN_4=$(expr "$IP_4" : '.*ip\":[ ]*\"\([^"]*\).*') &&
    ASNORG_4=$(expr "$IP_4" : '.*isp\":[ ]*\"\([^"]*\).*') &&
    _blue " IPv4 ASN: $ASNORG_4" >> $TEMP_FILE
    IP_6=$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip) &&
    WAN_6=$(expr "$IP_6" : '.*ip\":[ ]*\"\([^"]*\).*') &&
    ASNORG_6=$(expr "$IP_6" : '.*isp\":[ ]*\"\([^"]*\).*') &&
    _blue " IPv6 ASN: $ASNORG_6" >> $TEMP_FILE
    local ARCHITECTURE="$(arch)"
      case $ARCHITECTURE in
        x86_64 )  local FILE=besttrace;;
        aarch64 ) local FILE=besttracearm;;
        i386 )    local FILE=besttracemac;;
        * ) red " 只支持 AMD64、ARM64、Mac 使用，问题反馈:[https://github.com/fscarmen/tools/issues] " && return;;
      esac
    _green "依次测试电信，联通，移动经过的地区及线路，核心程序来由: ipip.net ，请知悉!" >> $TEMP_FILE
    curl -s -L -k "${cdn_success_url}https://github.com/fscarmen/tools/raw/main/besttrace/${FILE}" -o $FILE && chmod +x $FILE &>/dev/null
    for ((a=0;a<${#test_area_s[@]};a++)); do
    _yellow "${test_area_s[a]} ${test_ip_g[a]}" >> $TEMP_FILE
    ./"$FILE" "${test_ip_s[a]}" -g cn | sed "s/^[ ]//g" | sed "/^[ ]/d" | sed '/ms/!d' | sed "s#.* \([0-9.]\+ ms.*\)#\1#g" >> $TEMP_FILE
    done
    cat $TEMP_FILE
    rm -f $TEMP_FILE
}

fscarmen_route_b_script(){
    echo -e "------------------回程路由--感谢fscarmen开源及PR----------------------"
    rm -f $TEMP_FILE
    IP_4=$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip) &&
    WAN_4=$(expr "$IP_4" : '.*ip\":[ ]*\"\([^"]*\).*') &&
    ASNORG_4=$(expr "$IP_4" : '.*isp\":[ ]*\"\([^"]*\).*') &&
    _blue " IPv4 ASN: $ASNORG_4" >> $TEMP_FILE
    IP_6=$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip) &&
    WAN_6=$(expr "$IP_6" : '.*ip\":[ ]*\"\([^"]*\).*') &&
    ASNORG_6=$(expr "$IP_6" : '.*isp\":[ ]*\"\([^"]*\).*') &&
    _blue " IPv6 \t ASN: $ASNORG_6" >> $TEMP_FILE
    local ARCHITECTURE="$(arch)"
      case $ARCHITECTURE in
        x86_64 )  local FILE=besttrace;;
        aarch64 ) local FILE=besttracearm;;
        i386 )    local FILE=besttracemac;;
        * ) red " 只支持 AMD64、ARM64、Mac 使用，问题反馈:[https://github.com/fscarmen/tools/issues] " && return;;
      esac
    [[ ! -e $FILE ]] && wget -q "${cdn_success_url}https://github.com/fscarmen/tools/raw/main/besttrace/${FILE}" >/dev/null 2>&1
    chmod 777 $FILE >/dev/null 2>&1
    _green "依次测试电信，联通，移动经过的地区及线路，核心程序来由: ipip.net ，请知悉!" >> $TEMP_FILE
    for ((a=0;a<${#test_area_b[@]};a++)); do
    _yellow "${test_area_b[a]} ${test_ip_g[a]}" >> $TEMP_FILE
    ./"$FILE" "${test_ip_b[a]}" -g cn | sed "s/^[ ]//g" | sed "/^[ ]/d" | sed '/ms/!d' | sed "s#.* \([0-9.]\+ ms.*\)#\1#g" >> $TEMP_FILE
    done
    cat $TEMP_FILE
    rm -f $TEMP_FILE
}

superspeed_all_script(){
    cd /root >/dev/null 2>&1
    echo "--------网络测速--由teddysun和superspeed开源及spiritlhls整理----------"
    sleep 0.5
    echo -e "测速点位置\t 上传速度\t 下载速度\t 延迟"
    speed && rm -fr speedtest-cli
}

superspeed_minal_script(){
    cd /root >/dev/null 2>&1
    echo "--------网络测速--由teddysun和superspeed开源及spiritlhls整理----------"
    sleep 0.5
    echo -e "测速点位置\t 上传速度\t 下载速度\t 延迟"
    speed2 && rm -fr speedtest-cli
}

end_script(){
    next
    print_end_time
    next
}

all_script(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    check_virt
    # checkssh
    checkdnsutils
    python_all_script
    checkspeedtest
    install_speedtest
    check_lmc_script
    start_time=$(date +%s)
    clear
    print_intro
    basic_script
    io1_script
    sleep 1
    io2_script
    sjlleo_script
    RegionRestrictionCheck_script
    UnlockTiktokTest
    spiritlhl_script
    backtrace_script
    fscarmen_route_g_script
    # fscarmen_port_script
    superspeed_all_script
    end_script
}

minal_script(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    check_virt
    checkspeedtest
    install_speedtest
    start_time=$(date +%s)
    clear
    print_intro
    basic_script
    io2_script
    superspeed_minal_script
    end_script
}

minal_plus(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    check_virt
    check_lmc_script
    checkdnsutils
    checkspeedtest
    install_speedtest
    start_time=$(date +%s)
    clear
    print_intro
    basic_script
    io2_script
    sjlleo_script
    RegionRestrictionCheck_script
    UnlockTiktokTest
    backtrace_script
    fscarmen_route_g_script
    superspeed_minal_script
    end_script
}

minal_plus_network(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    check_virt
    checkspeedtest
    install_speedtest
    start_time=$(date +%s)
    clear
    print_intro
    basic_script
    io2_script
    backtrace_script
    fscarmen_route_g_script
    superspeed_minal_script
    end_script
}

minal_plus_media(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    check_virt
    checkdnsutils
    check_lmc_script
    checkspeedtest
    install_speedtest
    start_time=$(date +%s)
    clear
    print_intro
    basic_script
    io2_script
    sjlleo_script
    RegionRestrictionCheck_script
    UnlockTiktokTest
    superspeed_minal_script
    end_script
}

network_script(){
    pre_check
    python_gd_script
    checkspeedtest
    install_speedtest
    start_time=$(date +%s)
    clear
    print_intro
    spiritlhl_script
    backtrace_script
    fscarmen_route_g_script
    # fscarmen_port_script
    superspeed_all_script
    end_script
}

media_script(){
    pre_check
    SystemInfo_GetSystemBit
    checkdnsutils
    check_lmc_script
    start_time=$(date +%s)
    clear
    print_intro
    sjlleo_script
    RegionRestrictionCheck_script
    UnlockTiktokTest
    end_script
}

hardware_script(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    check_virt
    start_time=$(date +%s)
    clear
    print_intro
    basic_script
    io1_script
    io2_script
    end_script
}

port_script(){
    pre_check
    SystemInfo_GetSystemBit
    get_system_info >/dev/null 2>&1
    check_virt
    # checkssh
    start_time=$(date +%s)
    clear
    print_intro
    # fscarmen_port_script
    end_script
}

ping_script(){
    pre_check
    start_time=$(date +%s)
    clear
    print_intro
    chinaping
    end_script
}

sw_script(){
    pre_check
    start_time=$(date +%s)
    clear
    print_intro
    backtrace_script
    fscarmen_route_g_script
    end_script
}

network_g_script(){
    pre_check
    start_time=$(date +%s)
    clear
    print_intro
    fscarmen_route_g_script
    end_script
}

network_s_script(){
    pre_check
    start_time=$(date +%s)
    clear
    print_intro
    fscarmen_route_s_script
    end_script
}

network_b_script(){
    pre_check
    start_time=$(date +%s)
    clear
    print_intro
    fscarmen_route_b_script
    end_script
}

rm_script(){
    rm -rf return.sh
    rm -rf speedtest.tgz*
    rm -rf wget-log*
    rm -rf media_lmc_check.sh*
    rm -rf check.py*
    rm -rf qzcheck_ecs.py*
    rm -rf dp
    rm -rf nf
    rm -rf tubecheck
    rm -rf besttrace
    rm -rf LemonBench.Result.txt*
    rm -rf speedtest.log*
    rm -rf ecs.sh*
    rm -rf googlesearchcheck.py*
    rm -rf gdlog*
    rm -rf test
    rm -rf $TEMP_FILE
}

Jinjian_script(){
    head_script
    yellow "融合怪的精简脚本如下"
    echo -e "${GREEN}1.${PLAIN} 极简版(基础系统信息+CPU+内存+磁盘IO+测速节点4个)(平均运行3分钟不到)"
    echo -e "${GREEN}2.${PLAIN} 精简版(基础系统信息+CPU+内存+磁盘IO+御三家解锁+常用流媒体解锁+TikTok解锁+回程+路由+测速节点4个)(平均运行4分钟左右)"
    echo -e "${GREEN}3.${PLAIN} 精简网络版(基础系统信息+CPU+内存+磁盘IO+回程+路由+测速节点4个)(平均运行不到4分钟)"
    echo -e "${GREEN}4.${PLAIN} 精简解锁版(基础系统信息+CPU+内存+磁盘IO+御三家解锁+常用流媒体解锁+TikTok解锁+测速节点4个)(平均运行4分钟左右)"
    echo " -------------"
    echo -e "${GREEN}0.${PLAIN} 回到主菜单"
    echo ""
    read -rp "请输入选项:" StartInput1
	case $StartInput1 in
        1) minal_script ;;
        2) minal_plus ;;
        3) minal_plus_network ;;
        4) minal_plus_media ;;
        0) Start_script ;;
    esac
}

Danxiang_script(){
    head_script
    yellow "融合怪拆分的单项测试脚本如下"
    echo -e "${GREEN}1.${PLAIN} 网络方面(简化的IP质量检测+三网回程+三网路由与延迟+测速节点11个)(平均运行7分钟左右)"
    echo -e "${GREEN}2.${PLAIN} 解锁方面(御三家解锁+常用流媒体解锁+TikTok解锁)(平均运行30~60秒)"
    echo -e "${GREEN}3.${PLAIN} 硬件方面(基础系统信息+CPU+内存+双重磁盘IO测试)(平均运行1分半钟)"
    echo -e "${GREEN}4.${PLAIN} 完整的IP质量检测(平均运行10~20秒)"
    echo -e "${GREEN}5.${PLAIN} 常用端口开通情况(是否有阻断)(平均运行1分钟左右)(暂时有bug未修复)"
    echo -e "${GREEN}6.${PLAIN} 测三网回程+三网路由与延迟(平均运行1分钟)"
    echo -e "${GREEN}7.${PLAIN} 全国网络延迟测试(平均运行1分钟)"
    echo " -------------"
    echo -e "${GREEN}0.${PLAIN} 回到主菜单"
    echo ""
    read -rp "请输入选项:" StartInput2
	case $StartInput2 in
        1) network_script;;
        2) media_script;;
        3) hardware_script;;
        4) bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/qzcheck.sh);;
        5) port_script ;;
        6) sw_script ;;
        7) ping_script ;;
        0) Start_script ;;
    esac
}

Yuanshi_script(){
    head_script
    yellow "融合怪借鉴的脚本以及部分竞品脚本如下"
    echo -e "${GREEN}1.${PLAIN} misakabench VPS测试脚本"
    echo -e "${GREEN}2.${PLAIN} lemonbench VPS测试脚本"
    echo -e "${GREEN}3.${PLAIN} superbench VPS测试脚本"
    echo -e "${GREEN}4.${PLAIN} YABS VPS测试脚本"
    echo -e "${GREEN}5.${PLAIN} sjlleo的NetFlix解锁检测脚本 "
    echo -e "${GREEN}6.${PLAIN} sjlleo的Youtube地域信息检测脚本"
    echo -e "${GREEN}7.${PLAIN} sjlleo的DisneyPlus解锁区域检测脚本"
    echo -e "${GREEN}8.${PLAIN} lmc999的流媒体检测脚本"
    echo -e "${GREEN}9.${PLAIN} supeerbench的TikTok解锁区域检测脚本"
    echo -e "${GREEN}10.${PLAIN} zhanghanyun的backtrace三网回程线路检测脚本"
    echo -e "${GREEN}11.${PLAIN} zhucaidan的mtr_trace三网回程检线路测脚本"
    echo -e "${GREEN}12.${PLAIN} superspeed的三网测速脚本"
    echo -e "${GREEN}13.${PLAIN} hyperspeed的三网测速脚本"
    echo -e "${GREEN}14.${PLAIN} supeerbench的Geekbench5得分查询"
    echo " -------------"
    echo -e "${GREEN}0.${PLAIN} 回到主菜单"
    echo ""
    read -rp "请输入选项:" StartInput3
	case $StartInput3 in
        1) bash <(curl -L -Lso- https://cdn.jsdelivr.net/gh/misaka-gh/misakabench@master/misakabench.sh) ;;
        2) curl -fsL https://ilemonra.in/LemonBenchIntl | bash -s fast ;;
        3) wget -qO- --no-check-certificate https://cdn.spiritlhl.workers.dev/https://raw.githubusercontent.com/oooldking/script/master/superbench.sh | bash ;;
        4) curl -sL yabs.sh | bash ;;
        5) wget -O nf https://cdn.spiritlhl.workers.dev/https://github.com/sjlleo/netflix-verify/releases/download/v3.1.0/nf_linux_amd64 && chmod +x nf && ./nf ;;
        6) wget -O tubecheck https://cdn.jsdelivr.net/gh/sjlleo/TubeCheck/CDN/tubecheck_1.0beta_linux_amd64 && chmod +x tubecheck && clear && ./tubecheck ;;
        7) wget -O dp https://cdn.spiritlhl.workers.dev/https://github.com/sjlleo/VerifyDisneyPlus/releases/download/1.01/dp_1.01_linux_amd64 && chmod +x dp && clear && ./dp ;;
        8) bash <(curl -L -s check.unlock.media) ;;
        9) UnlockTiktokTest ;;
        # curl -fsL -o ./t.sh.x https://github.com/lmc999/TikTokCheck/raw/main/t.sh.x && chmod +x ./t.sh.x && ./t.sh.x && rm ./t.sh.x ;;
        10) curl https://cdn.spiritlhl.workers.dev/https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh -sSf | sh ;;
        11) curl https://cdn.spiritlhl.workers.dev/https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh|bash ;;
        12) bash <(curl -L -Lso- https://git.io/superspeed.sh) ;;
        13) bash <(curl -L -Lso- https://bench.im/hyperspeed) ;;
        14) geekbench_script ;;
        0) Start_script ;;
    esac
}

Yuanchuang_script(){
    head_script
    yellow "频道有原创成分的脚本如下"
    echo -e "${GREEN}1.${PLAIN} 完整的本机IP的质量检测(平均运行10~20秒)"
    echo -e "${GREEN}2.${PLAIN} 三网回程路由测试(预设广州)(平均运行1分钟)"
    echo -e "${GREEN}3.${PLAIN} 三网回程路由测试(预设上海)(平均运行1分钟)"
    echo -e "${GREEN}4.${PLAIN} 三网回程路由测试(预设北京)(平均运行1分钟)"
    echo -e "${GREEN}5.${PLAIN} 自定义IP的回程路由测试(自定义IP，需自行输入IP)"
    echo -e "${GREEN}6.${PLAIN} 自定义IP的质量检测(自定义IP，需自行输入IP)"
    echo " -------------"
    echo -e "${GREEN}0.${PLAIN} 回到主菜单"
    echo ""
    read -rp "请输入选项:" StartInput4
	case $StartInput4 in
        1) bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/qzcheck.sh);;
        2) network_g_script ;;
        3) network_s_script ;;
        4) network_b_script ;;
        5) bash <(curl -sSL https://cdn.spiritlhl.workers.dev/https://raw.githubusercontent.com/fscarmen/tools/main/return.sh) ;;
        6) bash <(curl -sSL https://cdn.spiritlhl.workers.dev/https://github.com/spiritLHLS/ecs/raw/main/customizeqzcheck.sh) ;;
        0) Start_script ;;
    esac
}

head_script(){
    clear
    echo "#############################################################"
    echo -e "#                     ${YELLOW}融合怪测评脚本${PLAIN}                        #"
    echo "# 版本：$ver                                          #"
    echo "# 更新日志：$changeLog#"
    echo -e "# ${GREEN}作者${PLAIN}: spiritlhl                                           #"
   # echo -e "# ${GREEN}测评站点${PLAIN}: https://vps.spiritysdx.top                      #"
    echo -e "# ${GREEN}TG频道${PLAIN}: https://t.me/vps_reviews                          #"
    echo -e "# ${GREEN}GitHub${PLAIN}: https://github.com/spiritLHLS                     #"
    echo -e "# ${GREEN}GitLab${PLAIN}: https://gitlab.com/spiritysdx                     #"
    echo "#############################################################"
    echo ""
    green "请选择你接下来测评的组合或单项"
}

Start_script(){
    head_script
    echo -e "${GREEN}1.${PLAIN} 完全体(所有项目都测试)(平均运行8分钟以上)"
    echo -e "${GREEN}2.${PLAIN} 精简区(融合怪的各种精简版并含单项测试精简版)"
    echo -e "${GREEN}3.${PLAIN} 单项区(融合怪的单项测试完整版)"
    echo -e "${GREEN}4.${PLAIN} 第三方脚本(借鉴脚本的原始脚本)"
    echo -e "${GREEN}5.${PLAIN} 原创脚本"
    echo " -------------"
    echo -e "${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp "请输入选项:" StartInput
	case $StartInput in
        1) all_script | tee -i test_result.txt ;;
        2) Jinjian_script ;;
        3) Danxiang_script ;;
        4) Yuanshi_script ;;
        5) Yuanchuang_script ;;
        0) exit 1 ;;
    esac
}

Start_script
rm_script
