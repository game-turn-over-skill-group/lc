#!/bin/bash

# 默认基础命令
command="cat /proc/net/nf_conntrack"
small_output=false
debug_mode=false
min_packets=0
min_bytes=0

# 处理参数
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -i|-I|--internet)
    if [[ $2 == "ipv4" || $2 == "ipv6" ]]; then
        command="$command | grep '$2'"
    fi
    shift
    shift
    ;;
    -n|-N|--network)
    if [[ $2 ]]; then
        command="$command | grep '$2'"
    fi
    shift
    shift
    ;;
    -p|--port)
    if [[ $2 ]]; then
        command="$command | grep 'dport=$2'"
    fi
    shift
    shift
    ;;
    -P|--ports)
    if [[ $2 ]]; then
        command="$command | grep -vE 'sport=$2|dport=$2'"
    fi
    shift
    shift
    ;;
    -b|-B|--bytes)
    if [[ $2 =~ ^[0-9]+$ ]]; then
        min_bytes=$2
    fi
    shift
    shift
    ;;
    -s|-S|--packets)
    if [[ $2 =~ ^[0-9]+$ ]]; then
        min_packets=$2
    fi
    shift
    shift
    ;;
    -ip|-IP)
    if [[ $2 ]]; then
        command="$command | grep -a '$2'"
    fi
    shift
    shift
    ;;
    -ips|-IPS)
    if [[ -f $2 ]]; then
        ip_list=$(cat "$2" | tr '\n' '|')
        ip_list="${ip_list%|}"  # 删除最后一个 "|"
        command="$command | grep -vE '$ip_list'"
    fi
    shift
    shift
    ;;
    -l|-L|--small)
    small_output=true
    shift
    ;;
    -d|-D|--debug)
    debug_mode=true
    shift
    ;;
    *)
    shift
    ;;
esac
done

# 执行基础命令并处理输出
eval $command | while read -r line; do
    # 先提取每个字段的原始数据
    protocol=$(echo "$line" | awk '{print $1}' | awk -F'proto=' '{print $2}' | awk '{print $1}')
    src_ip=$(echo "$line" | awk '{print $6}' | awk -F'src=' '{print $2}' | awk '{print $1}')
    src_port=$(echo "$line" | awk '{print $8}' | awk -F'sport=' '{print $2}' | awk '{print $1}')
    dst_ip=$(echo "$line" | awk '{print $7}' | awk -F'dst=' '{print $2}' | awk '{print $1}')
    dst_port=$(echo "$line" | awk '{print $9}' | awk -F'dport=' '{print $2}' | awk '{print $1}')
    recv_packets=$(echo "$line" | awk '{print $10}' | awk -F'packets=' '{print $2}' | awk '{print $1}')
    recv_bytes=$(echo "$line" | awk '{print $11}' | awk -F'bytes=' '{print $2}' | awk '{print $1}')
    send_packets=$(echo "$line" | awk '{print $16}' | awk -F'packets=' '{print $2}' | awk '{print $1}')
    send_bytes=$(echo "$line" | awk '{print $17}' | awk -F'bytes=' '{print $2}' | awk '{print $1}')
    
    # 检查packets和bytes是否为空并进行条件过滤
    if [[ $recv_packets =~ ^[0-9]+$ && $recv_bytes =~ ^[0-9]+$ && $send_packets =~ ^[0-9]+$ && $send_bytes =~ ^[0-9]+$ ]]; then
        if [ "$small_output" = true ]; then
            # 打印简化输出
            if [[ "$protocol" == "ipv6" ]]; then
                src_ip="[${src_ip}]"
                dst_ip="[${dst_ip}]"
            fi
            echo "$src_ip:$src_port -> $dst_ip:$dst_port recv_packets: $recv_packets recv_bytes: $recv_bytes send_packets: $send_packets send_bytes: $send_bytes"
        elif [ "$debug_mode" = true ]; then
            # 打印调试信息
            if (( min_packets == 0 || recv_packets >= min_packets || send_packets >= min_packets )) && (( min_bytes == 0 || recv_bytes >= min_bytes || send_bytes >= min_bytes )); then
                echo "Debug: src_ip=$src_ip src_port=$src_port dst_ip=$dst_ip dst_port=$dst_port recv_packets=$recv_packets recv_bytes=$recv_bytes send_packets=$send_packets send_bytes=$send_bytes min_packets=$min_packets min_bytes=$min_bytes"
            fi
        else
            # 过滤条件
            if (( min_packets == 0 || recv_packets >= min_packets || send_packets >= min_packets )) && (( min_bytes == 0 || recv_bytes >= min_bytes || send_bytes >= min_bytes )); then
                echo "$line"
            fi
        fi
    fi
done
