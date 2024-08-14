#!/bin/bash

# 定义基础命令
CMD="cat /proc/net/nf_conntrack"

# 处理命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -I|-i) CMD="$CMD | grep '$2'"; shift ;;
        -N|-n) CMD="$CMD | grep '$2'"; shift ;;
        -P|-p) CMD="$CMD | grep -vE 'sport=$2|dport=$2'"; shift ;;
        -B|-b) CMD="$CMD | grep -E 'bytes=[1-9][0-9]{5,}'"; shift ;;
        -S|-s) CMD="$CMD | grep -E 'packets=[1-9][0-9]{3,}'"; shift ;;
        -ip) CMD="$CMD | grep '$2'"; shift ;;
        -ips) CMD="$CMD | grep -v -f $2"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 执行命令
eval $CMD | awk '{print $1, $2, $3, $4, $5, $6, $7, $8}'
