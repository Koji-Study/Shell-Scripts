#!/bin/bash
function send(){
webhook="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=qiyeweixin"
curl -X POST $webhook \
   -H 'Content-Type: application/json' \
   -d '
   {
        "msgtype": "text",
        "text": {
        "content": "Cassandra监测告警\n告警内容: '$1'\n节点信息: '$2'"
        }
   }' > /dev/null 2>&1
}


function check(){
url_list=("1.1.1.1" "2.2.2.2")
i=0
x=0
command_check="/cassandra/apache-cassandra-4.1.0/bin/nodetool -u nodetool -pw passwd version"
command_confirm="/cassandra/apache-cassandra-4.1.0/bin/nodetool -u nodetool -pw passwd status"
while(( i<${#url_list[@]} ))
do
        sshpass -p passwd ssh ubuntu@"${url_list[$i]}" "$command_check" > /dev/null 2>&1
        if [ $? -eq 0 ];then
                result=$(sshpass -p passwd ssh -o StrictHostKeychecking=no ubuntu@"${url_list[$i]}" "$command_confirm" | grep -v "UN.*" | awk '(NR>=6){print $2}')
                ip_list=(${result// /})
                #有状态异常，则重启
                if [ ${#ip_list[*]} -ne 0 ]; then
                        restart ${ip_list[@]}
                fi
                break
        else
                #执行nodetool命令异常
                command_list[$x]=${url_list[$i]}
                let x++
                let i++
        fi
done
if [ $x -gt 1 ];then
        command_list_str=''
        for num in ${command_list[@]};do command_list_str=$command_list_str'★'$num;done
        send "节点无法执行nodetool命令，请检查！" $command_list_str
fi
}

function restart(){
m=0
n=0
j=0
command_restart="cd /cassandra/apache-cassandra-4.1.0/bin && nohup ./cassandra -R > /dev/null 2>&1"
for ip in ${ip_list[@]};
do
        ps_result=$(sshpass -p passwd ssh -o StrictHostKeychecking=no ubuntu@"$ip" "ps -ef |grep -v grep | grep org.apache.cassandra.service.CassandraDaemon")
        if [ -n "$ps_result" ]; then
                process_list[$m]=$ip
                let m++
        else
                nohup sshpass -p passwd ssh -o StrictHostKeychecking=no root@"$ip" "$command_restart"  > /dev/null 2>&1 &
                if [ $? -ne 0 ]; then
                        #echo "重启命令执行失败！！！"
                        restart_failed_list[$n]=$ip
                        let n++
                else
                        #echo "重启命令执行成功！！！"
                        restart_success_list[$j]=$ip
                        let j++
                fi
        fi
done
if [ $m -ge 1 ];then
        echo ${process_list[@]}
        process_list_str=''
        for num in ${process_list[@]};do process_list_str=$process_list_str'★'$num;done
        send "节点状态异常，Cassandra进程依然存在，请检查！" $process_list_str
fi
if [ $n -ge 1 ];then
        restart_failed_list_str=''
        for num in ${restar_failed_list[@]};do restart_failed_list_str=$restart_failed_list_str'★'$num;done
        send "节点状态异常,重启命令执行失败，请检查！" $restart_failed_list_str
fi
if [ $j -ge 1 ];then
        restart_success_list_str=''
        for num in ${restart_success_list[@]};do restart_success_list_str=$restart_success_list_str'★'$num;done
        send "节点状态异常，重启命令执行成功！" $restart_success_list_str
fi
}

check
