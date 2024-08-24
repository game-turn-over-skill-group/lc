#!/bin/bash

# 定义日志文件路径
LOG_FILE="/tmp/nf_conntrack.log"

# 如果日志文件已经存在，删除它
if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
fi

# 将连接表内容输出到日志文件
cat /proc/net/nf_conntrack > "$LOG_FILE"

# 默认基础命令
command="cat $LOG_FILE"

# 定义初始化变量
small_output=false
debug_mode=false
min_packets=0
min_bytes=0
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
        -p|--port)
            if [[ $2 ]]; then
                command="$command | grep 'dport=$2'"
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
        -P|--ports)
            if [[ $2 ]]; then
                port_range="$2"
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
        -b|-B|--bytes)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                min_bytes=$2
            fi
            shift  # 移掉选项
            shift  # 移掉选项的参数
            ;;
        -s|-S|--packets)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                min_packets=$2
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
	recv_packets=$(echo "$line" | awk -F'packets=' '{print $2}' | awk '{print $1}')
	recv_bytes=$(echo "$line" | awk -F'bytes=' '{print $2}' | awk '{print $1}')
	send_packets=$(echo "$line" | awk -F'packets=' '{print $3}' | awk '{print $1}')
	send_bytes=$(echo "$line" | awk -F'bytes=' '{print $3}' | awk '{print $1}')

    # 如果指定了端口范围，进行过滤
    if [[ -n $port_range ]]; then
        start_port=$(echo "$port_range" | cut -d'-' -f1)
        end_port=$(echo "$port_range" | cut -d'-' -f2)

        if [[ "$src_port" -ge "$start_port" && "$src_port" -le "$end_port" ]] || \
           [[ "$dst_port" -ge "$start_port" && "$dst_port" -le "$end_port" ]]; then
            continue  # 如果 src_port 或 dst_port 在范围内，则跳过这个条目
        fi
    fi

    # 检查packets和bytes是否为有效数字
    if [[ $recv_packets =~ ^[0-9]+$ && $recv_bytes =~ ^[0-9]+$ && $send_packets =~ ^[0-9]+$ && $send_bytes =~ ^[0-9]+$ ]]; then
        # 过滤条件[满足任意数字条件触发匹配输出]
        # (1) -s参数为0/不存在 + 收包数量>=自定义包数量 + 发包数量>=自定义包数量
        # (2) -b参数为0/不存在 + 收包字节>=自定义字节 + 发包字节>=自定义字节
        if (( min_packets == 0 || recv_packets >= min_packets || send_packets >= min_packets )) && (( min_bytes == 0 || recv_bytes >= min_bytes || send_bytes >= min_bytes )); then
            if [ "$small_output" = true ]; then         # 判断是否带有-L参数
                if [[ "$protocol" == "ipv6" ]]; then    # 判断协议为ipv6 给地址加[]括号
                    src_ip="[${src_ip}]"
                    dst_ip="[${dst_ip}]"
                fi
                # -L参数 排版显示
                echo "$src_ip $src_port -> $dst_ip:$dst_port recv_packets: $recv_packets recv_bytes: $recv_bytes send_packets: $send_packets send_bytes: $send_bytes"
            else
                # 正常匹配输出
                echo "$line"
            fi
        fi
    fi

    if [ "$debug_mode" = true ]; then         # 判断是否带有-D参数
        if (( min_packets == 0 || recv_packets >= min_packets || send_packets >= min_packets )) && (( min_bytes == 0 || recv_bytes >= min_bytes || send_bytes >= min_bytes )); then
            # 打印调试信息
            echo "Debug: src_ip=$src_ip src_port=$src_port dst_ip=$dst_ip dst_port=$dst_port recv_packets=$recv_packets recv_bytes=$recv_bytes send_packets=$send_packets send_bytes=$send_bytes min_packets=$min_packets min_bytes=$min_bytes"
        fi
    fi

done
