#!/bin/bash
#多个参数，使用for循环
function parameters(){
for i in $@;
do
        if [[ $i == "--status" || $i == "-s" ]];then
                echo "查看状态"
        elif [[ $i == "--help" || $i == "-h" ]];then
                echo "查看帮助"
        elif [[ $i == "--check" || $i == "-c" ]];then
                echo "启动检查"
        else
                echo "多参数函数无法识别参数$i,将不做处理"
        fi
done
}

#只有一个参数，使用case
function parameter(){
case $1 in
        "start")
                echo "启动程序"
                ;;
        "status")
                echo "查看状态"
                ;;
        "stop")
                echo "停止程序"
                ;;
        *)
                echo "单参数函数无法识别参数$1，将不做处理"
                ;;
esac
}

parameters "$@"
parameter $1
