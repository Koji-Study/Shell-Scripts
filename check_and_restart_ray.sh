#!/bin/bash
function send(){
webhook="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=qiyeweixin"
curl -X POST $webhook \
   -H 'Content-Type: application/json' \
   -d '
   {
        "msgtype": "text",
        "text": {
        "content": "RAY集群监测告警\n告警内容: '$1'\n节点信息: '$2'\n重启成功：'$3'\n重启失败：'$4'"
        }
   }' > /dev/null 2>&1
}


function check(){
ray_dev_list=("headip" "nodeip1" "nodeip2" "nodeip3")
ray_dev_pawd=('headpwd' 'nodepwd' 'nodepwd' 'nodepwd')
i=0
x=0
command_check="ps -ef | grep -v grep | grep /home/geovis/miniconda3/lib/python3.9/site-packages/ray/core/src/ray/raylet/raylet"
#command_stop="cd /home/geovis/miniconda3/bin && ray stop"
#commang_start="cgexec -g memory:ray ./workspace/ray/start_ray.sh"
command_stop="ls"
commang_start="ls"
while(( i<${#ray_dev_list[@]} ))
do
        ps_result=$(sshpass -p ${ray_dev_pawd[$i]} ssh -o StrictHostKeychecking=no root@"${ray_dev_list[$i]}" "$command_check")
        echo '查询结果'${#ps_result}
        if [ ${#ps_result} -eq 0 ];then
                down_list[$x]=${ray_dev_list[$i]}
                down_list_pawd[$x]=${ray_dev_pawd[$i]}
                let x++
        fi
        let i++
done
echo 'down node:'${down_list[@]}
if [ $x -gt 0 ]; then
        #head节点down了，需要重启所有节点
        if [ "${down_list[0]}" = "headip" ]; then
                #数组转成字符串传参
                restart "${ray_dev_list[*]}" "${ray_dev_pawd[*]}"
        else
                restart "${down_list[*]}" "${down_list_pawd[*]}"
        fi
fi
}

function restart(){
#传入的字符串转为数组
restart_list=($1)
restart_pawd=($2)
m=0
#停了down的节点的ray
while(( m<${#restart_list[@]} ))
do
        nohup sshpass -p ${restart_pawd[$m]} ssh -o StrictHostKeychecking=no root@"${restart_list[$m]}" "$command_stop"  > /dev/null 2>&1 &
        echo 'stop'$m
        let m++
done
m=0
f=0
s=0
#重新启动down的节点
while(( m<${#restart_list[@]} ))
do
        nohup sshpass -p ${restart_pawd[$m]} ssh -o StrictHostKeychecking=no root@"${restart_list[$m]}" "$command_start" > /dev/null 2>&1 &
        if [ $? -ne 0 ];then
                restart_failed_list[$f]=${restart_list[$m]}
                let f++
        else
                restart_succeed_list[$s]=${restart_list[$m]}
                let s++
        fi
        echo 'start'$m
        let m++
done

echo 'f:'$f 's:'$s

down_list_str=''
for ip in ${restart_list[@]};
do
        down_list_str=$down_list_str'★'$ip;
done
if [ $f -gt 1 ];then
        restart_failed_list_str=''
        for fip in ${restart_failed_list[*]};
        do
                restart_failed_list_str=$restart_failed_list_str'★'$fip;
        done
else
        restart_failed_list_str="NULL"
fi
if [ $s -gt 1 ];then
        restart_succeed_list_str=''
        for sip in ${restart_succeed_list[@]};
        do
                restart_succeed_list_str=$restart_succeed_list_str'★'$sip;
        done
else
        restart_succeed_list_str="NULL"
fi
send "RAY集群节点状态异常" $down_list_str $restart_succeed_list_str $restart_failed_list_str
}

check
