#!/bin/bash

# 项目地址(project)：https://github.com/game-turn-over-skill-group/lc

# 将连接表内容输出到日志文件(最后将文件下载回系统桌面)
# cat /proc/net/nf_conntrack > /tmp/nf_conntrack.log

# 定义日志文件路径
LOG_FILE="./nf_conntrack.log"

# 默认基础命令
command="cat $LOG_FILE"

# 定义初始化变量
small_output=false
debug_mode=false
cmp_packets=0
cmp_bytes=0
port_range=""

# 定义默认路径文件
Default_Path_File="/etc/storage/bmd.txt"

# 创建函数：规范化IPv6地址
normalize_ipv6() {
    local ipv6=$1

    # 处理CIDR网段
    if [[ $ipv6 == */* ]]; then
        local address=${ipv6%%/*}
        local prefix=${ipv6#*/}

        # 将::替换为完整的0填充
        address=$(echo "$address" | sed -e 's/::/:0000:0000:0000:0000:0000:0000:0000:0000/' | sed -e 's/:/\n/g')

        # 用0填充每一段
        local full_address=""
        for i in $(seq 1 8); do
            local segment=$(echo "$address" | sed -n "${i}p" | sed 's/^0*//')
            if [[ -z "$segment" ]]; then
                segment="0000"
            fi
            full_address+=$(printf "%04x" "$((16#$segment))")
            if [[ $i -lt 8 ]]; then
                full_address+=":"
            fi
        done

        # 加上网络前缀
        echo "$full_address"
    else
        # 处理普通IPv6地址
        # 将::替换为完整的0填充
        local full_address=$(echo "$ipv6" | sed -e 's/::/:0000:0000:0000:0000:0000:0000:0000:0000/' | sed -e 's/:/\n/g')

        # 用0填充每一段
        local result=""
        for i in $(seq 1 8); do
            local segment=$(echo "$full_address" | sed -n "${i}p" | sed 's/^0*//')
            if [[ -z "$segment" ]]; then
                segment="0000"
            fi
            result+=$(printf "%04x" "$((16#$segment))")
            if [[ $i -lt 8 ]]; then
                result+=":"
            fi
        done

        echo "$result"
    fi
}

# 处理参数
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -i|-I|--internet)
            if [[ $2 == "ipv4" || $2 == "ipv6" ]]; then
                command="$command | grep '$2'"
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
        -n|-N|--network)
            if [[ $2 ]]; then
                command="$command | grep '$2'"
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
		-p|--ports)
			if [[ $2 ]]; then
				show_port_list="$2"
				IFS=',' read -r -a show_ports <<< "$show_port_list"
				show_pattern=""
				for show_port in "${show_ports[@]}"; do
					if [[ "$show_port" == *"-"* ]]; then
						# 提取端口范围
						start_port=$(echo "$show_port" | cut -d'-' -f1)
						end_port=$(echo "$show_port" | cut -d'-' -f2)
						show_pattern+="(port=$start_port )"
						for (( port=start_port+1; port<=end_port; port++ )); do
							show_pattern+="|(port=$port )"
						done
					else
						show_pattern+="(port=$show_port )|"
					fi
				done
				show_pattern=${show_pattern%|}  # 移除最后的 ' | '
				command="$command | grep -E '$show_pattern'"
			fi
			shift  # 移掉选项
			;;
		-P|--Ports)
			if [[ $2 ]]; then
				filter_port_list="$2"
				IFS=',' read -r -a filter_ports <<< "$filter_port_list"
				filter_pattern=""
				for filter_port in "${filter_ports[@]}"; do
					if [[ "$filter_port" == *"-"* ]]; then
						# 提取端口范围
						start_port=$(echo "$filter_port" | cut -d'-' -f1)
						end_port=$(echo "$filter_port" | cut -d'-' -f2)
						filter_pattern+="(port=$start_port )"
						for (( port=start_port+1; port<=end_port; port++ )); do
							filter_pattern+="|(port=$port )"
						done
					else
						filter_pattern+="(port=$filter_port )|"
					fi
				done
				filter_pattern=${filter_pattern%|}  # 移除最后的 ' | '
				command="$command | grep -vE '$filter_pattern'"
			fi
			shift  # 移掉选项
			;;
        -b|-B|--bytes)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                cmp_bytes=$2
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
        -s|-S|--packets)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                cmp_packets=$2
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
        -ip|-IP)
            if [[ $2 ]]; then
                command="$command | grep -a '$2'"
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
        -ips|-IPS)
            if [[ -z $2 || $2 == -* ]]; then  # 检查是否传入了路径文件，或下一个参数是一个选项
                ip_file="$Default_Path_File"
            else
                ip_file="$2"
            fi

            if [[ -f $ip_file ]]; then
                ip_list=""
                while IFS= read -r line; do
                    # 处理 IPv4 地址和网段
                    if [[ $line =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})(/[0-9]+)?$ ]]; then
                        if [[ $line =~ /24$ ]]; then
                            prefix=$(echo "$line" | awk -F/ '{print $1}' | awk -F. '{print $1"."$2"."$3}')
                        elif [[ $line =~ /16$ ]]; then
                            prefix=$(echo "$line" | awk -F/ '{print $1}' | awk -F. '{print $1"."$2}')
                        else
                            prefix=$(echo "$line" | awk -F/ '{print $1}')
                        fi
                        ip_list="$ip_list$prefix|"
                    
                    # 处理 IPv6 地址和网段
                    elif [[ $line =~ ^([0-9a-fA-F:]+)(/[0-9]+)?$ ]]; then
                        if [[ $line =~ /64$ ]]; then
                            full_ipv6=$(normalize_ipv6 "$line")
                            prefix="${full_ipv6:0:4}:${full_ipv6:5:4}:${full_ipv6:10:4}:${full_ipv6:15:4}"
                        else
                            full_ipv6=$(normalize_ipv6 "$line")
                            prefix="${full_ipv6:0:4}:${full_ipv6:5:4}:${full_ipv6:10:4}:${full_ipv6:15:4}:${full_ipv6:20:4}:${full_ipv6:25:4}:${full_ipv6:30:4}:${full_ipv6:35:4}"
                        fi
                        ip_list="$ip_list$prefix|"
                    else
                        ip_list="$ip_list$line|"
                    fi
                done < "$ip_file"
                ip_list="${ip_list%|}"  # 删除最后一个 "|"
                command="$command | grep -vE '$ip_list'"
            else
                echo "Error: 文件路径无效或文件不存在: $ip_file"
                exit 1
            fi
			shift  # 移掉选项
			if [[ $2 != -* && -n $2 ]]; then
				shift  # 如果 $2 不是另一个选项，并且存在，则再移掉参数
            fi
            ;;
        -l|-L|--small)
            small_output=true
            shift  # 选项没有参数，所以只需一次 `shift`
            ;;
        -d|-D|--debug)
            debug_mode=true
            shift  # 选项没有参数，所以只需一次 `shift`
            ;;
        *)
            shift
            ;;
    esac
done

# 定义临时文件
temp_file=$(mktemp)
temp_script=$(mktemp)

# 将命令写入临时脚本
echo "$command" > "$temp_script"
# 检查临时脚本是否成功创建并具有内容
if [[ ! -s "$temp_script" ]]; then
    echo "临时脚本为空或未成功创建！"
    exit 1
fi
# 给临时脚本添加执行权限
chmod +x "$temp_script"

# 执行临时脚本并将输出写入临时文件
"$temp_script" > "$temp_file"

# 读取临时文件进行处理
while read -r line; do
	# 使用 Bash 字符串操作 提取每个字段的原始数据
	protocol="${line%% *}"  # 提取协议类型
	# echo "$protocol"
	src_ip___="${line#*src=}"
	src_ip="${src_ip___%% *}"  # 提取第1个源 IP
	# echo "$src_ip"
	dst_ip___="${line#*dst=}"
	dst_ip="${dst_ip___%% *}"  # 提取第1个目标 IP
	# echo "$dst_ip"
	src_port___="${line#*sport=}"
	src_port="${src_port___%% *}"  # 提取第1个源端口
	# echo "$src_port"
	src2_port___="${src_port___#*sport=}"
	src2_port="${src2_port___%% *}"  # 提取第2个源端口
	# echo "$src2_port"
	dst_port___="${line#*dport=}"
	dst_port="${dst_port___%% *}"  # 提取第1个目标端口
	# echo "$dst_port"
	dst2_port___="${dst_port___#*dport=}"
	dst2_port="${dst2_port___%% *}"  # 提取第2个目标端口
	# echo "$dst2_port"
	src_packets___="${line#*packets=}"
	src_packets="${src_packets___%% *}"  # 提取第1个数据包数
	# echo "$src_packets"
	dst_packets___="${src_packets___#*packets=}"
	dst_packets="${dst_packets___%% *}"  # 提取第2个数据包数
	# echo "$dst_packets"
	src_bytes___="${line#*bytes=}"
	src_bytes="${src_bytes___%% *}"  # 提取第1个字节数
	# echo "$src_bytes"
	dst_bytes___="${src_bytes___#*bytes=}"
	dst_bytes="${dst_bytes___%% *}"  # 提取第2个字节数
	# echo "$dst_bytes"

    # 检查packets和bytes是否为有效数字
    if [[ $src_packets =~ ^[0-9]+$ && $src_bytes =~ ^[0-9]+$ && $dst_packets =~ ^[0-9]+$ && $dst_bytes =~ ^[0-9]+$ ]]; then
        # 过滤条件[满足任意数字条件触发匹配输出]
        # (1) -s参数为0/不存在 + 收包数量>=自定义包数量 + 发包数量>=自定义包数量
        # (2) -b参数为0/不存在 + 收包字节>=自定义字节 + 发包字节>=自定义字节
        if (( cmp_packets == 0 || src_packets >= cmp_packets || dst_packets >= cmp_packets )) && (( cmp_bytes == 0 || src_bytes >= cmp_bytes || dst_bytes >= cmp_bytes )); then
            if [ "$small_output" = true ]; then         # 判断是否带有-L参数
                if [[ "$protocol" == "ipv6" ]]; then    # 判断协议为ipv6 给地址加[]括号
                    src_ip="[${src_ip}]"
                    dst_ip="[${dst_ip}]"
                fi
                # -L参数 排版显示
                echo "$src_ip $src_port -> $dst_ip:$dst_port src_packets: $src_packets dst_packets: $dst_packets src_bytes: $src_bytes dst_bytes: $dst_bytes"
            else
                # 正常匹配输出
                echo "$line"
            fi
        fi
    fi

    if [ "$debug_mode" = true ]; then         # 判断是否带有-D参数
        if (( cmp_packets == 0 || src_packets >= cmp_packets || dst_packets >= cmp_packets )) && (( cmp_bytes == 0 || src_bytes >= cmp_bytes || dst_bytes >= cmp_bytes )); then
            # 打印调试信息
            echo "Debug: src_ip=$src_ip src_port=$src_port dst_ip=$dst_ip dst_port=$dst_port src_packets=$src_packets dst_packets=$dst_packets cmp_packets=$cmp_packets cmp_bytes=$cmp_bytes src_bytes=$src_bytes dst_bytes=$dst_bytes"
        fi
    fi

done < "$temp_file"

# 删除临时文件
rm "$temp_file"
rm "$temp_script"
