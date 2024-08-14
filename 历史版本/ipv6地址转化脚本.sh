#!/bin/bash

# 函数：规范化IPv6地址
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

# 测试
normalize_ipv6 "2a00:7c80:0:243::2"
normalize_ipv6 "2607:fea8:79dd:21c::/64"
