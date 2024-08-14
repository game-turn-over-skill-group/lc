#!/bin/bash

# 默认基础命令
command="cat /proc/net/nf_conntrack"
small_output=false
debug_mode=false
min_packets=0
min_bytes=0
port_range=""
# 定义默认路径文件
Default_Path_File="/etc/storage/bmd.txt"

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
                ip_list=$(cat "$ip_file" | sed -E 's/\/[0-9]+$//' | tr '\n' '|')
                ip_list="${ip_list%|}"  # 删除最后一个 "|"
                command="$command | grep -vE '$ip_list'"
            else
                echo "Error: 文件路径无效或文件不存在: $ip_file"
                exit 1
            fi
            shift  # 移掉选项
            if [[ $2 != -* ]]; then
                shift  # 如果 $2 不是另一个选项，就再移掉参数
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
    src_ip=$(echo "$line" | awk '{print $6}' | awk -F'src=' '{print $2}' | awk '{print $1}')
    src_port=$(echo "$line" | awk '{print $8}' | awk -F'sport=' '{print $2}' | awk '{print $1}')
    dst_ip=$(echo "$line" | awk '{print $7}' | awk -F'dst=' '{print $2}' | awk '{print $1}')
    dst_port=$(echo "$line" | awk '{print $9}' | awk -F'dport=' '{print $2}' | awk '{print $1}')
    recv_packets=$(echo "$line" | awk '{print $10}' | awk -F'packets=' '{print $2}' | awk '{print $1}')
    recv_bytes=$(echo "$line" | awk '{print $11}' | awk -F'bytes=' '{print $2}' | awk '{print $1}')
    send_packets=$(echo "$line" | awk '{print $16}' | awk -F'packets=' '{print $2}' | awk '{print $1}')
    send_bytes=$(echo "$line" | awk '{print $17}' | awk -F'bytes=' '{print $2}' | awk '{print $1}')

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
                echo "$src_ip:$src_port -> $dst_ip:$dst_port recv_packets: $recv_packets recv_bytes: $recv_bytes send_packets: $send_packets send_bytes: $send_bytes"
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
