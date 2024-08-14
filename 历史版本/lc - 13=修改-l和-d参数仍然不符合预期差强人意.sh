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
    protocol=$(echo "$line" | awk -F'proto=' '{print $2}' | awk '{print $1}')
    src_ip=$(echo "$line" | awk -F'src=' '{print $2}' | awk '{print $1}')
    src_port=$(echo "$line" | awk -F'sport=' '{print $2}' | awk '{print $1}')
    dst_ip=$(echo "$line" | awk -F'dst=' '{print $2}' | awk '{print $1}')
    dst_port=$(echo "$line" | awk -F'dport=' '{print $2}' | awk '{print $1}')
    packets=$(echo "$line" | awk -F'packets=' '{print $2}' | awk '{print $1}')
    bytes=$(echo "$line" | awk -F'bytes=' '{print $2}' | awk '{print $1}')

    # 检查packets和bytes是否为空
    if [[ $packets =~ ^[0-9]+$ && $bytes =~ ^[0-9]+$ ]]; then
        if [ "$small_output" = true ]; then
            # 打印简化输出
            echo "$protocol $src_ip:$src_port -> $dst_ip:$dst_port $packets packets $bytes bytes"
        elif [ "$debug_mode" = true ]; then
            # 打印调试信息
            echo "Debug: src_ip=$src_ip src_port=$src_port dst_ip=$dst_ip dst_port=$dst_port packets=$packets bytes=$bytes min_packets=$min_packets min_bytes=$min_bytes"
        else
            # 过滤条件
            if (( min_packets == 0 || packets >= min_packets )) && (( min_bytes == 0 || bytes >= min_bytes )); then
                echo "$line"
            fi
        fi
    fi
done
