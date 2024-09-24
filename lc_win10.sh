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
						show_pattern+="(sport=$start_port|dport=$start_port)"
						for (( port=start_port+1; port<=end_port; port++ )); do
							show_pattern+="|(sport=$port|dport=$port)"
						done
					else
						show_pattern+="(sport=$show_port|dport=$show_port)|"
					fi
				done
				show_pattern=${show_pattern%|}  # 移除最后的 '|'
				command="$command | grep -E '$show_pattern'"
			fi
			shift  # 移掉选项
			;;
        -P|--Ports)
            if [[ $2 ]]; then
                filter_port_list="$2"
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
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

# 执行基础命令并处理输出
eval $command | while read -r line; do
    # 提取每个字段的原始数据
    protocol=$(echo "$line" | awk '{print $1}')
	src_ip=$(echo "$line" | awk -F'src=' '{print $2}' | awk '{print $1}')
	dst_ip=$(echo "$line" | awk -F'dst=' '{print $2}' | awk '{print $1}')
	src_port=$(echo "$line" | awk -F'sport=' '{print $2}' | awk '{print $1}')
	dst_port=$(echo "$line" | awk -F'dport=' '{print $2}' | awk '{print $1}')
	src2_port=$(echo "$line" | awk -F'sport=' '{print $3}' | awk '{print $1}')  # 提取第二个源端口
	dst2_port=$(echo "$line" | awk -F'dport=' '{print $3}' | awk '{print $1}')  # 提取第二个目标端口
	src_packets=$(echo "$line" | awk -F'packets=' '{print $2}' | awk '{print $1}')
	src_bytes=$(echo "$line" | awk -F'bytes=' '{print $2}' | awk '{print $1}')
	dst_packets=$(echo "$line" | awk -F'packets=' '{print $3}' | awk '{print $1}')
	dst_bytes=$(echo "$line" | awk -F'bytes=' '{print $3}' | awk '{print $1}')
    skip_line=false     # 默认不跳过

    # 如果指定了端口范围或单端口，进行过滤
    if [[ -n $filter_port_list ]]; then
        IFS=',' read -r -a filter_ports <<< "$filter_port_list"
        for filter_port in "${filter_ports[@]}"; do
            if [[ "$filter_port" == *"-"* ]]; then
                # 处理端口范围
                start_port=$(echo "$filter_port" | cut -d'-' -f1)
                end_port=$(echo "$filter_port" | cut -d'-' -f2)
				if [[ "$src_port" -ge "$start_port" && "$src_port" -le "$end_port" ]] || \
				   [[ "$dst_port" -ge "$start_port" && "$dst_port" -le "$end_port" ]] || \
				   [[ "$src2_port" -ge "$start_port" && "$src2_port" -le "$end_port" ]] || \
				   [[ "$dst2_port" -ge "$start_port" && "$dst2_port" -le "$end_port" ]]; then
                    skip_line=true
                    break
                fi
            else
                # 处理单个端口
				if [[ "$src_port" -eq "$filter_port" || "$dst_port" -eq "$filter_port" ]] || \
				   [[ "$src2_port" -eq "$filter_port" || "$dst2_port" -eq "$filter_port" ]]; then
                    skip_line=true
                    break
                fi
            fi
        done
    fi

    # 是否跳过输出行
    if $skip_line; then
        continue    #跳过当前行=不输出
    fi

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

done
