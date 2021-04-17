#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6/7,Debian 8/9,Ubuntu 16+
#	Description: BBRplus
#	Version: 8.8.8
#	Author: AhYuan
#	Blog: 
#=================================================

sh_ver="1.3.2"
github="raw.githubusercontent.com/kanseaveg/vps/master" 

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"


#====================手动调整最新版本=====================#
	new_version="v20200801"
	old_version="v20180909"

#====================From Brook==========================#
filepath=$(cd "$(dirname "$0")"; pwd)
file_1=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
file="/usr/local/brook-pf"
brook_file="/usr/local/brook-pf/brook"
brook_conf="/usr/local/brook-pf/brook.conf"
brook_log="/usr/local/brook-pf/brook.log"
Crontab_file="/usr/bin/crontab"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
check_installed_status(){
	[[ ! -e ${brook_file} ]] && echo -e "${Error} Brook 没有安装，请检查 !" && exit 1
}

check_crontab_installed_status(){
	if [[ ! -e ${Crontab_file} ]]; then
		echo -e "${Error} Crontab 没有安装，开始安装..."
		if [[ ${release} == "centos" ]]; then
			yum install crond -y
		else
			apt-get install cron -y
		fi
		if [[ ! -e ${Crontab_file} ]]; then
			echo -e "${Error} Crontab 安装失败，请检查！" && exit 1
		else
			echo -e "${Info} Crontab 安装成功！"
		fi
	fi
}

check_pid(){
	PID=$(ps -ef| grep "brook relays"| grep -v grep| grep -v ".sh"| grep -v "init.d"| grep -v "service"| awk '{print $2}')
}

check_new_ver(){
	echo && echo -e "最新版本为[v20200801]适合LTE Proxy; 旧版本为[v20180909]适合StarVPN.
	${Green_font_prefix}1.${Font_color_suffix}  选择最新版本
	${Green_font_prefix}2.${Font_color_suffix}  选择旧版本
	" && echo

	read -e -p "请输入数字 [1或2]:" ver_num
	if [[ ${ver_num} == "1" ]]; then
		brook_version=${new_version}
		echo "${brook_version}"
		echo -e "${Info} 开始下载 Brook [ ${brook_version} ] 版本！"
	elif [[ ${ver_num} == "2" ]]; then
		brook_version=${old_version}
		echo -e "${Info} 开始下载 Brook [ ${brook_version} ] 版本！"
	else
		echo -e "${Error} 请输入正确的数字(1或者2)" 
	fi
}

Download_brook(){
	[[ ! -e ${file} ]] && mkdir ${file}
	cd ${file}
	bit=`uname -m`
	if [[ ${bit} == "x86_64" ]]; then
		wget --no-check-certificate -N "https://github.com/txthinking/brook/releases/download/${brook_version}/brook"
	else
		wget --no-check-certificate -N "https://github.com/txthinking/brook/releases/download/${brook_version}/brook_linux_386"
		mv brook_linux_386 brook
	fi
	[[ ! -e "brook" ]] && echo -e "${Error} Brook 下载失败 !" && exit 1
	chmod +x brook
}
# Brook管理脚本
Service_brook(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/kanseaveg/vps/master/service/brook-pf_centos -O /etc/init.d/brook-pf; then
			echo -e "${Error} Brook服务 管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/brook-pf
		chkconfig --add brook-pf
		chkconfig brook-pf on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/kanseaveg/vps/master/service/brook-pf_debian -O /etc/init.d/brook-pf; then
			echo -e "${Error} Brook服务 管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/brook-pf
		update-rc.d -f brook-pf defaults
	fi
	echo -e "${Info} Brook服务 管理脚本下载完成 !"
}
#同步时间 
Installation_dependency(){
	\cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

Read_config(){
	[[ ! -e ${brook_conf} ]] && echo -e "${Error} Brook 配置文件不存在 !" && exit 1
	user_all=$(cat ${brook_conf})
	user_all_num=$(echo "${user_all}"|wc -l)
	[[ -z ${user_all} ]] && echo -e "${Error} Brook 配置文件中用户配置为空 !" && exit 1
}
Set_pf_Enabled(){
	echo -e "立即启用该端口转发，还是禁用？ [Y/n]"
	read -e -p "(默认: Y 启用):" pf_Enabled_un
	[[ -z ${pf_Enabled_un} ]] && pf_Enabled_un="y"
	if [[ ${pf_Enabled_un} == [Yy] ]]; then
		bk_Enabled="1"
	else
		bk_Enabled="0"
	fi
}
Set_port_Modify(){
	while true
		do
		echo -e "请选择并输入要修改的 Brook 端口转发本地监听端口 [1-65535]"
		read -e -p "(默认取消):" bk_port_Modify
		[[ -z "${bk_port_Modify}" ]] && echo "取消..." && exit 1
		echo $((${bk_port_Modify}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${bk_port_Modify} -ge 1 ]] && [[ ${bk_port_Modify} -le 65535 ]]; then
				check_port "${bk_port_Modify}"
				if [[ $? == 0 ]]; then
					break
				else
					echo -e "${Error} 该本地监听端口不存在 [${bk_port_Modify}] !"
				fi
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
	done
}
Set_port(){
	while true
		do
		echo -e "请输入 Brook 本地监听端口 [1-65535]（端口不能重复，避免冲突）"
		read -e -p "(默认取消):" bk_port
		[[ -z "${bk_port}" ]] && echo "已取消..." && exit 1
		echo $((${bk_port}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${bk_port} -ge 1 ]] && [[ ${bk_port} -le 65535 ]]; then
				echo && echo "========================"
				echo -e "	本地监听端口 : ${Red_background_prefix} ${bk_port} ${Font_color_suffix}"
				echo "========================" && echo
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
		done
}
Set_IP_pf(){
	echo "请输入被转发的 IP :"
	read -e -p "(默认回车使用starvpn地址,Lte请手动输入):" bk_ip_pf
	[[ -z "${bk_ip_pf}" ]] && bk_ip_pf="proxy.starhome.io"
	echo && echo "========================"
	echo -e "	被转发IP : ${Red_background_prefix} ${bk_ip_pf} ${Font_color_suffix}"
	echo "========================" && echo
}
Set_port_pf(){
	while true
		do
		echo -e "请输入 Brook 被转发的端口 [1-65535]"
		read -e -p "(默认取消):" bk_port_pf
		[[ -z "${bk_port_pf}" ]] && echo "已取消..." && exit 1
		echo $((${bk_port_pf}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${bk_port_pf} -ge 1 ]] && [[ ${bk_port_pf} -le 65535 ]]; then
				echo && echo "========================"
				echo -e "	被转发端口 : ${Red_background_prefix} ${bk_port_pf} ${Font_color_suffix}"
				echo "========================" && echo
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
		done
}
Set_brook(){
	check_installed_status
	echo && echo -e "你要做什么？
 ${Green_font_prefix}1.${Font_color_suffix}  添加 端口转发
 ${Green_font_prefix}2.${Font_color_suffix}  删除 端口转发
 ${Green_font_prefix}3.${Font_color_suffix}  修改 端口转发
 ${Green_font_prefix}4.${Font_color_suffix}  启用/禁用 端口转发
 
 ${Tip} 本地监听端口不能重复，被转发的IP或端口可重复!" && echo
	read -e -p "(默认: 取消):" bk_modify
	[[ -z "${bk_modify}" ]] && echo "已取消..." && exit 1
	if [[ ${bk_modify} == "1" ]]; then
		Add_pf
	elif [[ ${bk_modify} == "2" ]]; then
		Del_pf
	elif [[ ${bk_modify} == "3" ]]; then
		Modify_pf
	elif [[ ${bk_modify} == "4" ]]; then
		Modify_Enabled_pf
	else
		echo -e "${Error} 请输入正确的数字(1-4)" && exit 1
	fi
}

check_port(){
	check_port_1=$1
	user_all=$(cat ${brook_conf}|sed '1d;/^\s*$/d')
	#[[ -z "${user_all}" ]] && echo -e "${Error} Brook 配置文件中用户配置为空 !" && exit 1
	check_port_statu=$(echo "${user_all}"|awk '{print $1}'|grep -w "${check_port_1}")
	if [[ ! -z "${check_port_statu}" ]]; then
		return 0
	else
		return 1
	fi
}
Check_Proxy_Geo(){
	#安装curl jq 解析网络
	# if [[ ${release} == "centos" ]]; then
	# 		yum install curl jq -y
	# else
	# 		apt-get install curl jq -y
	# fi
	echo -e "====当前已设置Brook转发情况===="
	user_all=$(cat ${brook_conf}|sed '/^\s*$/d')
	if [[ -z "${user_all}" ]]; then
		echo -e "${Info} 目前 Brook 配置文件中用户配置为空。" && exit 1
	else
		user_num=$(echo -e "${user_all}"|wc -l) #端口个数
		for((integer = 1; integer <= ${user_num}; integer++)) 
		do
			user_port=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $1}')
			user_ip_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $2}')
			user_port_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $3}')
			user_Enabled_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $4}')
			raw_json=$(curl -sb -v -x socks5h://localhost:${user_port} https://ipapi.co/json)
			# echo ${raw_json} #set the breakpoint
			cur_ip=$(echo "${raw_json}" | jq -r '.ip')
			cur_country_code=$(echo "${raw_json}" | jq -r '.country_code')
			cur_country_name=$(echo "${raw_json}" | jq -r '.country_name')
			cur_region=$(echo "${raw_json}" | jq -r '.region')
			cur_city=$(echo "${raw_json}" | jq -r '.city')
			cur_timezone=$(echo "${raw_json}" | jq -r '.timezone')
			cur_lanaguage=$(echo "${raw_json}" | jq -r '.languages')

			if [[ ${user_Enabled_pf} == "0" ]]; then
				user_Enabled_pf_1="${Red_font_prefix}禁用${Font_color_suffix}"
			else
				user_Enabled_pf_1="${Green_font_prefix}启用${Font_color_suffix}"
			fi
			user_list_all=${user_list_all}"本地端口: ${Green_font_prefix}"${user_port}"${Font_color_suffix} 被转发IP: ${Green_font_prefix}"${user_ip_pf}"${Font_color_suffix} 被转发端口: ${Green_font_prefix}"${user_port_pf}"${Font_color_suffix} 状态: ${user_Enabled_pf_1} 当前IP：${Green_font_prefix}"${cur_ip}"${Font_color_suffix}  国家代码：${Green_font_prefix}"${cur_country_code}"${Font_color_suffix}  国家：${Green_font_prefix}"${cur_country_name}"${Font_color_suffix} 郡Region：${Green_font_prefix}"${cur_region}"${Font_color_suffix}   城市：${Green_font_prefix}"${cur_city}"${Font_color_suffix}  时区：${Green_font_prefix}"${cur_timezone}"${Font_color_suffix}  语言：${Green_font_prefix}"${cur_lanaguage}"${Font_color_suffix}\n"
			user_IP=""
		done
		echo -e "${user_list_all}"
		echo -e "========================\n"
	fi

}


list_port(){
	#安装curl访问网站
	if [[ ${release} == "centos" ]]; then
			yum install curl jq -y
	else
			apt-get install curl jq -y
	fi
	
	port_Type=$1
	user_all=$(cat ${brook_conf}|sed '/^\s*$/d')
	if [[ -z "${user_all}" ]]; then
		if [[ "${port_Type}" == "ADD" ]]; then
			echo -e "${Info} 目前 Brook 配置文件中用户配置为空。"
		else
			echo -e "${Info} 目前 Brook 配置文件中用户配置为空。" && exit 1
		fi
	else
		user_num=$(echo -e "${user_all}"|wc -l)
		for((integer = 1; integer <= ${user_num}; integer++))
		do
			user_port=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $1}')
			user_ip_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $2}')
			user_port_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $3}')
			user_Enabled_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $4}')
			if [[ ${user_Enabled_pf} == "0" ]]; then
				user_Enabled_pf_1="${Red_font_prefix}禁用${Font_color_suffix}"
			else
				user_Enabled_pf_1="${Green_font_prefix}启用${Font_color_suffix}"
			fi
			user_list_all=${user_list_all}"本地监听端口: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t 被转发IP: ${Green_font_prefix}"${user_ip_pf}"${Font_color_suffix}\t 被转发端口: ${Green_font_prefix}"${user_port_pf}"${Font_color_suffix}\t 状态: ${user_Enabled_pf_1}\n"
			user_IP=""
		done
		ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
			if [[ -z "${ip}" ]]; then
				ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
				if [[ -z "${ip}" ]]; then
					ip="VPS_IP"
				fi
			fi
		fi
		echo -e "当前端口转发总数: ${Green_background_prefix} "${user_num}" ${Font_color_suffix} 当前服务器IP: ${Green_background_prefix} "${ip}" ${Font_color_suffix}"
		echo -e "${user_list_all}"
		echo -e "========================\n"
	fi
}
Add_pf(){
	while true
	do
		list_port "ADD"
		Set_port
		check_port "${bk_port}"
		[[ $? == 0 ]] && echo -e "${Error} 该本地监听端口已使用 [${bk_port}] !" && exit 1
		Set_IP_pf
		Set_port_pf
		Set_pf_Enabled
		echo "${bk_port} ${bk_ip_pf} ${bk_port_pf} ${bk_Enabled}" >> ${brook_conf}
		Add_success=$(cat ${brook_conf}| grep ${bk_port})
		if [[ -z "${Add_success}" ]]; then
			echo -e "${Error} 端口转发 添加失败 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix} "
			break
		else
			Add_iptables
			Save_iptables
			echo -e "${Info} 端口转发 添加成功 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix}\n"
			
			#=======默认添加一个端口立即启动这个转发=============#
			# read -e -p "是否继续 添加端口转发配置？[Y/n]:" addyn
			# [[ -z ${addyn} ]] && addyn="y"
			# if [[ ${addyn} == [Nn] ]]; then
			# 	Restart_brook
			# 	break
			# else
			# 	echo -e "${Info} 继续 添加端口转发配置..."
			# 	user_list_all=""
			# fi
			Restart_brook
			break
		fi
	done
}
Del_pf(){
	while true
	do
		list_port
		Set_port
		check_port "${bk_port}"
		[[ $? == 1 ]] && echo -e "${Error} 该本地监听端口不存在 [${bk_port}] !" && exit 1
		sed -i "/^${bk_port} /d" ${brook_conf}
		Del_success=$(cat ${brook_conf}| grep ${bk_port})
		if [[ ! -z "${Del_success}" ]]; then
			echo -e "${Error} 端口转发 删除失败 ${Green_font_prefix}[端口: ${bk_port}]${Font_color_suffix} "
			break
		else
			port=${bk_port}
			Del_iptables
			Save_iptables
			echo -e "${Info} 端口转发 删除成功 ${Green_font_prefix}[端口: ${bk_port}]${Font_color_suffix}\n"
			port_num=$(cat ${brook_conf}|sed '/^\s*$/d'|wc -l)
			if [[ ${port_num} == 0 ]]; then
				echo -e "${Error} 已无任何端口 !"
				check_pid
				if [[ ! -z ${PID} ]]; then
					Stop_brook
				fi
				break
			else
				read -e -p "是否继续 删除端口转发配置？[Y/n]:" delyn
				[[ -z ${delyn} ]] && delyn="y"
				if [[ ${delyn} == [Nn] ]]; then
					Restart_brook
					break
				else
					echo -e "${Info} 继续 删除端口转发配置..."
					user_list_all=""
				fi
			fi
		fi
	done
}
Modify_pf(){
	list_port
	Set_port_Modify
	echo -e "\n${Info} 开始输入新端口... \n"
	Set_port
	check_port "${bk_port}"
	[[ $? == 0 ]] && echo -e "${Error} 该端口已存在 [${bk_port}] !" && exit 1
	Set_IP_pf
	Set_port_pf
	sed -i "/^${bk_port_Modify} /d" ${brook_conf}
	Set_pf_Enabled
	echo "${bk_port} ${bk_ip_pf} ${bk_port_pf} ${bk_Enabled}" >> ${brook_conf}
	Modify_success=$(cat ${brook_conf}| grep "${bk_port} ${bk_ip_pf} ${bk_port_pf} ${bk_Enabled}")
	if [[ -z "${Modify_success}" ]]; then
		echo -e "${Error} 端口转发 修改失败 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix}"
		exit 1
	else
		port=${bk_port_Modify}
		Del_iptables
		Add_iptables
		Save_iptables
		Restart_brook
		echo -e "${Info} 端口转发 修改成功 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix}\n"
	fi
}
Modify_Enabled_pf(){
	list_port
	Set_port_Modify
	user_pf_text=$(cat ${brook_conf}|sed '/^\s*$/d'|grep "${bk_port_Modify}")
	user_port_text=$(echo ${user_pf_text}|awk '{print $1}')
	user_ip_pf_text=$(echo ${user_pf_text}|awk '{print $2}')
	user_port_pf_text=$(echo ${user_pf_text}|awk '{print $3}')
	user_Enabled_pf_text=$(echo ${user_pf_text}|awk '{print $4}')
	if [[ ${user_Enabled_pf_text} == "0" ]]; then
		echo -e "该端口转发已${Red_font_prefix}禁用${Font_color_suffix}，是否${Green_font_prefix}启用${Font_color_suffix}？ [Y/n]"
		read -e -p "(默认: Y 启用):" user_Enabled_pf_text_un
		[[ -z ${user_Enabled_pf_text_un} ]] && user_Enabled_pf_text_un="y"
		if [[ ${user_Enabled_pf_text_un} == [Yy] ]]; then
			user_Enabled_pf_text_1="1"
			sed -i "/^${bk_port_Modify} /d" ${brook_conf}
			echo "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}" >> ${brook_conf}
			Modify_Enabled_success=$(cat ${brook_conf}| grep "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}")
			if [[ -z "${Modify_Enabled_success}" ]]; then
				echo -e "${Error} 端口转发 启用失败 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}"
				exit 1
			else
				echo -e "${Info} 端口转发 启用成功 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}\n"
				Restart_brook
			fi
		else
			echo "已取消..." && exit 0
		fi
	else
		echo -e "该端口转发已${Green_font_prefix}启用${Font_color_suffix}，是否${Red_font_prefix}禁用${Font_color_suffix}？ [Y/n]"
		read -e -p "(默认: Y 禁用):" user_Enabled_pf_text_un
		[[ -z ${user_Enabled_pf_text_un} ]] && user_Enabled_pf_text_un="y"
		if [[ ${user_Enabled_pf_text_un} == [Yy] ]]; then
			user_Enabled_pf_text_1="0"
			sed -i "/^${bk_port_Modify} /d" ${brook_conf}
			echo "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}" >> ${brook_conf}
			Modify_Enabled_success=$(cat ${brook_conf}| grep "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}")
			if [[ -z "${Modify_Enabled_success}" ]]; then
				echo -e "${Error} 端口转发 禁用失败 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}"
				exit 1
			else
				echo -e "${Info} 端口转发 禁用成功 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}\n"
				Restart_brook
			fi
		else
			echo "已取消..." && exit 0
		fi
	fi
}
Install_brook(){
	check_root
	[[ -e ${brook_file} ]] && echo -e "${Error} 检测到 Brook 已安装 !" && exit 1
	echo -e "${Info} 开始安装/配置 依赖..."
	Installation_dependency
	echo -e "${Info} 开始检测最新版本..."
	check_new_ver
	echo -e "${Info} 开始下载/安装..."
	Download_brook
	echo -e "${Info} 开始下载/安装 服务脚本(init)..."
	Service_brook
	echo -e "${Info} 开始写入 配置文件..."
	echo "" > ${brook_conf}
	echo -e "${Info} 开始设置 iptables防火墙..."
	Set_iptables
	echo -e "${Info} Brook 安装完成！默认配置文件为空，请选择 [9.设置 Brook 端口转发 - 1.添加 端口转发] 来添加端口转发。"
}
Start_brook(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} Brook 正在运行，请检查 !" && exit 1
	/etc/init.d/brook-pf start
}
Stop_brook(){
	check_installed_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} Brook 没有运行，请检查 !" && exit 1
	/etc/init.d/brook-pf stop
}
Restart_brook(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/brook-pf stop
	/etc/init.d/brook-pf start
}
Uninstall_brook(){
	check_installed_status
	echo -e "确定要卸载 Brook ? [y/N]\n"
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z $PID ]] && kill -9 ${PID}
		if [[ -e ${brook_conf} ]]; then
			user_all=$(cat ${brook_conf}|sed '/^\s*$/d')
			user_all_num=$(echo "${user_all}"|wc -l)
			if [[ ! -z ${user_all} ]]; then
				for((integer = 1; integer <= ${user_all_num}; integer++))
				do
					port=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $1}')
					Del_iptables
				done
				Save_iptables
			fi
		fi
		if [[ ! -z $(crontab -l | grep "brook-pf.sh monitor") ]]; then
			crontab_monitor_brook_cron_stop
		fi
		rm -rf ${file}
		if [[ ${release} = "centos" ]]; then
			chkconfig --del brook-pf
		else
			update-rc.d -f brook-pf remove
		fi
		rm -rf /etc/init.d/brook-pf
		echo && echo "Brook 卸载完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
}
View_Log(){
	check_installed_status
	[[ ! -e ${brook_log} ]] && echo -e "${Error} Brook 日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志(正常情况是没有使用日志记录的)" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${brook_log}${Font_color_suffix} 命令。" && echo
	tail -f ${brook_log}
}
Set_crontab_monitor_brook(){
	check_installed_status
	check_crontab_installed_status
	crontab_monitor_brook_status=$(crontab -l|grep "brook-pf.sh monitor")
	if [[ -z "${crontab_monitor_brook_status}" ]]; then
		echo && echo -e "当前监控模式: ${Green_font_prefix}未开启${Font_color_suffix}" && echo
		echo -e "确定要开启 ${Green_font_prefix}Brook 服务端运行状态监控${Font_color_suffix} 功能吗？(当进程关闭则自动启动 Brook 服务端)[Y/n]"
		read -e -p "(默认: y):" crontab_monitor_brook_status_ny
		[[ -z "${crontab_monitor_brook_status_ny}" ]] && crontab_monitor_brook_status_ny="y"
		if [[ ${crontab_monitor_brook_status_ny} == [Yy] ]]; then
			crontab_monitor_brook_cron_start
		else
			echo && echo "	已取消..." && echo
		fi
	else
		echo && echo -e "当前监控模式: ${Green_font_prefix}已开启${Font_color_suffix}" && echo
		echo -e "确定要关闭 ${Green_font_prefix}Brook 服务端运行状态监控${Font_color_suffix} 功能吗？(当进程关闭则自动启动 Brook 服务端)[y/N]"
		read -e -p "(默认: n):" crontab_monitor_brook_status_ny
		[[ -z "${crontab_monitor_brook_status_ny}" ]] && crontab_monitor_brook_status_ny="n"
		if [[ ${crontab_monitor_brook_status_ny} == [Yy] ]]; then
			crontab_monitor_brook_cron_stop
		else
			echo && echo "	已取消..." && echo
		fi
	fi
}
crontab_monitor_brook_cron_start(){
	crontab -l > "$file_1/crontab.bak"
	sed -i "/brook-pf.sh monitor/d" "$file_1/crontab.bak"
	echo -e "\n* * * * * /bin/bash $file_1/brook-pf.sh monitor" >> "$file_1/crontab.bak"
	crontab "$file_1/crontab.bak"
	rm -r "$file_1/crontab.bak"
	cron_config=$(crontab -l | grep "brook-pf.sh monitor")
	if [[ -z ${cron_config} ]]; then
		echo -e "${Error} Brook 服务端运行状态监控功能 启动失败 !" && exit 1
	else
		echo -e "${Info} Brook 服务端运行状态监控功能 启动成功 !"
	fi
}
crontab_monitor_brook_cron_stop(){
	crontab -l > "$file_1/crontab.bak"
	sed -i "/brook-pf.sh monitor/d" "$file_1/crontab.bak"
	crontab "$file_1/crontab.bak"
	rm -r "$file_1/crontab.bak"
	cron_config=$(crontab -l | grep "brook-pf.sh monitor")
	if [[ ! -z ${cron_config} ]]; then
		echo -e "${Error} Brook 服务端运行状态监控功能 停止失败 !" && exit 1
	else
		echo -e "${Info} Brook 服务端运行状态监控功能 停止成功 !"
	fi
}
crontab_monitor_brook(){
	check_installed_status
	check_pid
	echo "${PID}"
	if [[ -z ${PID} ]]; then
		echo -e "${Error} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] 检测到 Brook服务端 未运行 , 开始启动..." | tee -a ${brook_log}
		/etc/init.d/brook-pf start
		sleep 1s
		check_pid
		if [[ -z ${PID} ]]; then
			echo -e "${Error} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] Brook服务端 启动失败..." | tee -a ${brook_log}
		else
			echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] Brook服务端 启动成功..." | tee -a ${brook_log}
		fi
	else
		echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] Brook服务端 进程运行正常..." | tee -a ${brook_log}
	fi
}
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${bk_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${bk_port} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
	else
		iptables-save > /etc/iptables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		chkconfig --level 2345 iptables on
	else
		iptables-save > /etc/iptables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}


#====================From Brook==========================#

#安装BBRplus内核
installbbrplus(){
	kernel_version="4.14.129-bbrplus"
	if [[ "${release}" == "centos" ]]; then
		wget -N --no-check-certificate https://${github}/bbrplus/${release}/${version}/kernel-${kernel_version}.rpm
		yum install -y kernel-${kernel_version}.rpm
		rm -f kernel-${kernel_version}.rpm
		kernel_version="4.14.129_bbrplus" #fix a bug
	elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
		mkdir bbrplus && cd bbrplus
		wget -N --no-check-certificate http://${github}/bbrplus/debian-ubuntu/${bit}/linux-headers-${kernel_version}.deb
		wget -N --no-check-certificate http://${github}/bbrplus/debian-ubuntu/${bit}/linux-image-${kernel_version}.deb
		dpkg -i linux-headers-${kernel_version}.deb
		dpkg -i linux-image-${kernel_version}.deb
		cd .. && rm -rf bbrplus
	fi
	detele_kernel
	BBR_grub
	echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}BBRplus${Font_color_suffix}"
	stty erase '^H' && read -p "需要重启VPS后，才能开启BBRplus，是否现在重启 ? [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info} VPS 重启中..."
		reboot
	fi
}


#启用BBRplus
startbbrplus(){
	remove_all
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbrplus" >> /etc/sysctl.conf
	sysctl -p
	echo -e "${Info}BBRplus启动成功！"
}




#卸载全部加速
remove_all(){
	rm -rf bbrmod
	sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/fs.file-max/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
	sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_recycle/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
	sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
	if [[ -e /appex/bin/lotServer.sh ]]; then
		bash <(wget --no-check-certificate -qO- https://github.com/MoeClub/lotServer/raw/master/Install.sh) uninstall
	fi
	clear
	echo -e "${Info}:清除加速完成。"
	sleep 1s
}

#优化系统配置
optimizing_system(){
	sed -i '/fs.file-max/d' /etc/sysctl.conf
	sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
	echo "fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
# forward ipv4
net.ipv4.ip_forward = 1">>/etc/sysctl.conf
	sysctl -p
	echo "*               soft    nofile           1000000
*               hard    nofile          1000000">/etc/security/limits.conf
	echo "ulimit -SHn 1000000">>/etc/profile
	read -p "需要重启VPS后，才能生效系统优化配置，是否现在重启 ? [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info} VPS 重启中..."
		reboot
	fi
}




#开始菜单
start_menu(){
clear
echo && echo -e " TCP加速 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- 一起搞钱 | AhYuan --
  
———————————— 安装 BBRplus | 加速管理 ————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 BBRplus版内核 
 ${Green_font_prefix}2.${Font_color_suffix} 使用 BBRplus版加速
 ${Green_font_prefix}3.${Font_color_suffix} 卸载 全部加速
 ${Green_font_prefix}4.${Font_color_suffix} 系统配置优化
 
———————————— 安装 Brook | 线路搭建管理 ————————————
${Green_font_prefix} 5.${Font_color_suffix} 安装 Brook
${Green_font_prefix} 6.${Font_color_suffix} 卸载 Brook
${Green_font_prefix} 7.${Font_color_suffix} 启动 Brook
${Green_font_prefix} 8.${Font_color_suffix} 停止 Brook
${Green_font_prefix} 9.${Font_color_suffix} 重启 Brook

———————————— 管理端口加速 | 端口服务管理 ————————————
${Green_font_prefix} 10.${Font_color_suffix} 设置 Brook 端口转发
${Green_font_prefix} 11.${Font_color_suffix} 查看 Brook 端口转发列表
${Green_font_prefix} 12.${Font_color_suffix} 查看 Brook 日志
${Green_font_prefix} 13.${Font_color_suffix} 监控 Brook 运行状态

———————————— 服务商连通性测试 | 代理管理 ————————————
${Green_font_prefix} 14.${Font_color_suffix} 测试跳板机到服务商服务连通性


${Green_font_prefix} 15.${Font_color_suffix} 退出脚本
————————————————————————————————" && echo

	check_status
	if [[ ${kernel_status} == "noinstall" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}未安装${Font_color_suffix} 加速内核 ${Red_font_prefix}请先安装内核${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} ${_font_prefix}${kernel_status}${Font_color_suffix} 加速内核 , ${Green_font_prefix}${run_status}${Font_color_suffix}"
		
	fi
echo
read -e -p " 请输入数字 [1-14]:" service_num
case "$service_num" in
	1)
	check_sys_bbrplus
	;;
	2)
	startbbrplus
	;;
	3)
	remove_all
	;;
	4)
	optimizing_system
	;;
	5)
	Install_brook
	;;
	6)
	Uninstall_brook
	;;
	7)
	Start_brook
	;;
	8)
	Stop_brook
	;;
	9)
	Restart_brook
	;;	
	10)
	Set_brook
	;;
	11)
	check_installed_status  
	list_port
	;;
	12)
	View_Log
	;;
	13)
	Set_crontab_monitor_brook
	;;
	14)
	Check_Proxy_Geo
	;;
	15)
	exit 1
	;;
	*)
	echo "请输入正确数字 [0-13]"
	clear
	sleep 2s
	start_menu
	;;
esac
}





#############内核管理组件#############

#删除多余内核
detele_kernel(){
	if [[ "${release}" == "centos" ]]; then
		rpm_total=`rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | wc -l`
		if [ "${rpm_total}" > "1" ]; then
			echo -e "检测到 ${rpm_total} 个其余内核，开始卸载..."
			for((integer = 1; integer <= ${rpm_total}; integer++)); do
				rpm_del=`rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | head -${integer}`
				echo -e "开始卸载 ${rpm_del} 内核..."
				rpm --nodeps -e ${rpm_del}
				echo -e "卸载 ${rpm_del} 内核卸载完成，继续..."
			done
			echo --nodeps -e "内核卸载完毕，继续..."
		else
			echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
		fi
	elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
		deb_total=`dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | wc -l`
		if [ "${deb_total}" > "1" ]; then
			echo -e "检测到 ${deb_total} 个其余内核，开始卸载..."
			for((integer = 1; integer <= ${deb_total}; integer++)); do
				deb_del=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer}`
				echo -e "开始卸载 ${deb_del} 内核..."
				apt-get purge -y ${deb_del}
				echo -e "卸载 ${deb_del} 内核卸载完成，继续..."
			done
			echo -e "内核卸载完毕，继续..."
		else
			echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
		fi
	fi
}

#更新引导
BBR_grub(){
	if [[ "${release}" == "centos" ]]; then
        if [[ ${version} = "6" ]]; then
            if [ ! -f "/boot/grub/grub.conf" ]; then
                echo -e "${Error} /boot/grub/grub.conf 找不到，请检查."
                exit 1
            fi
            sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        elif [[ ${version} = "7" ]]; then
            if [ ! -f "/boot/grub2/grub.cfg" ]; then
                echo -e "${Error} /boot/grub2/grub.cfg 找不到，请检查."
                exit 1
            fi
            grub2-set-default 0
        fi
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
        /usr/sbin/update-grub
    fi
}

#############内核管理组件#############



#############系统检测组件#############

#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}

#检查Linux版本
check_version(){
	if [[ -s /etc/redhat-release ]]; then
		version=`grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1`
	else
		version=`grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1`
	fi
	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="x64"
	else
		bit="x32"
	fi
}



##检查安装bbrplus的系统要求
check_sys_bbrplus(){
	check_version
	if [[ "${release}" == "centos" ]]; then
		if [[ ${version} -ge "6" ]]; then
			installbbrplus
		else
			echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "debian" ]]; then
		if [[ ${version} -ge "8" ]]; then
			installbbrplus
		else
			echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "ubuntu" ]]; then
		if [[ ${version} -ge "14" ]]; then
			installbbrplus
		else
			echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	else
		echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
	fi
}




check_status(){
	kernel_version=`uname -r | awk -F "-" '{print $1}'`
	kernel_version_full=`uname -r`
	if [[ ${kernel_version_full} = "4.14.129-bbrplus" ]]; then
		kernel_status="BBRplus"
	elif [[ ${kernel_version} = "3.10.0" || ${kernel_version} = "3.16.0" || ${kernel_version} = "3.2.0" || ${kernel_version} = "4.4.0" || ${kernel_version} = "3.13.0"  || ${kernel_version} = "2.6.32" || ${kernel_version} = "4.9.0" ]]; then
		kernel_status="Lotserver"
	else 
		kernel_status="noinstall"
	fi

	if [[ ${kernel_status} == "Lotserver" ]]; then
		if [[ -e /appex/bin/lotServer.sh ]]; then
			run_status=`bash /appex/bin/lotServer.sh status | grep "LotServer" | awk  '{print $3}'`
			if [[ ${run_status} = "running!" ]]; then
				run_status="启动成功"
			else 
				run_status="启动失败"
			fi
		else 
			run_status="未安装加速模块"
		fi
	elif [[ ${kernel_status} == "BBRplus" ]]; then
		run_status=`grep "net.ipv4.tcp_congestion_control" /etc/sysctl.conf | awk -F "=" '{print $2}'`
		if [[ ${run_status} == "bbrplus" ]]; then
			run_status=`lsmod | grep "bbrplus" | awk '{print $1}'`
			if [[ ${run_status} == "tcp_bbrplus" ]]; then
				run_status="BBRplus启动成功"
			else 
				run_status="BBRplus启动失败"
			fi
		else 
			run_status="未安装加速模块"
		fi
	fi
}

#############系统检测组件#############
check_sys
action=$1
check_version
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
if [[ "${action}" == "monitor" ]]; then
	crontab_monitor_brook
else
	start_menu
fi

