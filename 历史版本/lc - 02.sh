#!/bin/bash

# 默认基础命令
command="cat /proc/net/nf_conntrack"
small_output=false

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
        command="$command | grep -E 'bytes=[0-9]+' | awk -F 'bytes=' '{print $2}' | awk -v threshold=$2 '$1 >= threshold {print}'"
    fi
    shift
    shift
    ;;
    -s|-S|--packets)
    if [[ $2 =~ ^[0-9]+$ ]]; then
        command="$command | grep -E 'packets=[0-9]+' | awk -F 'packets=' '{print $2}' | awk -v threshold=$2 '$1 >= threshold {print}'"
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
    *)
    shift
    ;;
esac
done

# 执行命令
if [ "$small_output" = true ]; then
    eval $command | awk '{print $1,$3,$6,$8,$7,$9,$10,$11,$16,$17}'
else
    eval $command
fi
