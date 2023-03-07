#!/bin/bash

function initialization()
{
echo "初始化操作开始..."
#create user named geovis
echo "创建geovis用户，组(geovis)，id(1001), home(/home/geovis)"
if id -u 'geovis' > /dev/null 2>&1 ; then
   echo "geovis用户已经存在"
else
   useradd -d "/home/geovis" -m -u 1001 -p "123456789" -s "/bin/bash" geovis \
   && echo "创建geovis用户成功"
fi

#install docker
echo "docker安装开始..."
if type docker > /dev/null 2>&1 ; then
   echo "docker已经存在"
else
   apt-get update
   echo "Installing docker..."
   echo "Step1: 安装docker"
   apt-get install -y docker.io > /dev/null 2>&1
   echo "Step2: 启动并设置docker开机自启动"
   systemctl start docker \
   && systemctl enable docker
   echo "Step3: 设置docker的存储路径"
   mkdir -p /mnt/data/docker \
   && touch /etc/docker/daemon.json \
   && echo '{' >> /etc/docker/daemon.json \
   && echo '    "data-root":"/mnt/data/docker"' >> /etc/docker/daemon.json \
   && echo '}' >> /etc/docker/daemon.json \
   && systemctl restart docker
   if type docker > /dev/null 2>&1 ; then
        echo "docker安装完成"
   else
        echo "安装docker失败，请检查脚本设置" \
        && exit
   fi
fi

#install docker-compose
echo "docker-compose安装开始..."
if type docker-compose > /dev/null 2>&1 ; then
   echo "docker-compose已经存在"
else
   if type curl > /dev/null 2>&1 ; then
	   apt-get install -y curl
   fi
   echo "Installing docker-compose..." \
   && curl -L https://get.daocloud.io/docker/compose/releases/download/v2.11.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose \
   && chmod +x /usr/local/bin/docker-compose
   if type docker-compose > /dev/null 2>&1 ; then
        echo "docker-compose安装完成"
   else
        echo "安装docker-compose失败，请检查脚本设置"
   fi
fi

#add group named docker
echo "给geovis用户docker权限"
if egrep 'docker' /etc/group > /dev/null 2>&1 ; then
   echo "docker组已经存在"
   if groups geovis | grep docker > /dev/null 2>&1 ; then
        echo "geovis已经存在docker组中"
   else
        gpasswd -a geovis docker > /dev/null 2>&1 \
        && echo "已将geovis用户添加到docker组"
   fi
else
   groupadd docker > /dev/null 2>&1 \
   && gpasswd -a geovis docker > /dev/null 2>&1 \
   && echo "docker组创建完成，已将geovis用户添加到docker组"
fi
echo "初始化操作已经完成！"
}






function etcdsetting()
{
    echo "准备部署etcd..."
    if docker ps | grep etcd > /dev/null 2>&1 ; then
        echo "etcd已经在运行中"
    else
        cd ./services
        tar xvzf etcd.tar.gz > /dev/null 2>&1
        if test -d etcd; then
 		cd etcd
		echo "修改etcd ip"
		ip=`ip addr|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
		m=`echo $ip | awk '{print $1}'`
		ipaddr=${m%/*}
		echo $ipaddr
		sed -i 's#\(ETCD_INITIAL_ADVERTISE_PEER_URLS=http://\)[^:]*#\1'"${ipaddr}"'#' docker-compose.yml
   		sed -i 's#\(ETCD_ADVERTISE_CLIENT_URLS=http://\)[^:]*#\1'"${ipaddr}"'#' docker-compose.yml 
		cd ../	
                cd etcd
		echo "运行docker-compose.yaml文件"
                if test -e "docker-compose.yaml" || test -e "docker-compose.yml" ; then
                        docker-compose up -d
                                if docker-compose ls | grep etcd > /dev/null 2>&1 ; then
                                        echo "etcd部署完成"
				else
					echo "etcd部署出现问题，请检查"
                                fi
                else
                        echo "未找到etcd的yaml配置文件，请检查"
                fi
                cd ../
        else
                echo "未找到etcd的配置文件夹,请检查"
        fi
        cd ../
    fi
 
}




function apisixsetting()
{
    echo "准备部署apisix组合工具..."
    read -p "请输入apisix想连接的etcd集群ip,多个ip请用空格分隔:" name
    echo $name
    OLD_IFS="$IFS" 
    IFS=" " 
    arr=($name) 
    IFS="$OLD_IFS" 
    for s in ${arr[@]} 
    do 
    	echo "想连接的etcd的ip: $s"
        
    done
    echo "Step1: 部署apisix"
    if docker ps | grep apisix_apisix > /dev/null 2>&1 ; then
	echo "apisix已经在运行中"
    else  
    	cd ./services
    	tar xvzf apisix.tar.gz > /dev/null 2>&1
    	if test -d apisix; then
		#修改配置文件
                cd apisix/apisix_conf
		host_line=`grep -n "host:" config.yaml | cut -d ":" -f 1`
		prefix_line=`grep -n "prefix:" config.yaml | cut -d ":" -f 1`
		start_line=$(($host_line+1))
		end_line=$(($prefix_line-1))
		if [ $start_line -lt $prefix_line ];then
			sed -i "${start_line},${end_line}d" config.yaml > /dev/null 2>&1
			echo "删除原配置文件的etcd ip配置"
		fi
		for((i=0;i<${#arr[*]};i++))
                do
                        iparr[i]="\    \- \"http://${arr[i]}:2379\""
                        sed -i "${host_line} a ${iparr[i]}" config.yaml > /dev/null 2>&1
                done
		echo "配置文件etcd ip配置完成"
		cd ../../
		#运行apisix
		cd apisix
                if test -e "docker-compose.yaml" || test -e "docker-compose.yml" ; then
			docker-compose up  -d
				if docker-compose ls | grep apisix > /dev/null 2>&1 ; then
                        		echo "apisix部署完成"
				fi
		else 
			echo "未找到apisix的yaml配置文件，请检查"
		fi
                cd ../
	else
		echo "未找到apisix的配置文件夹"
	fi
	cd ../
    fi

    echo "Step2: 部署apisix-dashboard"
    if docker ps | grep apisix_dashboard > /dev/null 2>&1 ; then
        echo "apisix-dashboard已经在运行中"
    else
        cd ./services
        tar xvzf apisix_dashboard.tar.gz > /dev/null 2>&1
        if test -d apisix_dashboard; then
		cd apisix_dashboard/dashboard_conf
		endpoints_line=`grep -n "endpoints:" conf.yaml | cut -d ":" -f 1`
                mtls_line=`grep -n "mtls:" conf.yaml | cut -d ":" -f 1`
		start_line=$(($endpoints_line+1))
                end_line=$(($mtls_line-1))
		if [ $start_line -lt $prefix_line ];then
                        sed -i "${start_line},${end_line}d" conf.yaml > /dev/null 2>&1
                        echo "删除原配置文件的etcd ip配置"
                fi
                for((i=0;i<${#arr[*]};i++))
                do
                        iparr[i]="\        \- \"http://${arr[i]}:2379\""
                        sed -i "${endpoints_line} a ${iparr[i]}" conf.yaml > /dev/null 2>&1
                done
                echo "配置文件etcd ip配置完成"
		cd ../../
                cd apisix_dashboard
                if test -e "docker-compose.yaml" || test -e "docker-compose.yml" ; then
                        docker-compose up -d
                                if docker-compose ls | grep apisix_dashboard > /dev/null 2>&1 ; then
                                        echo "apixix_dashboard部署完成"
                                fi
                else
                        echo "未找到apisix_dashboard的yaml配置文件，请检查"
                fi
		cd ../
        else
                echo "未找到apisix_dashboard的配置文件夹，请检查"
        fi
	cd ../
    fi
}




function consulseeting()
{
echo "准备部署consul..."
if  type consul > /dev/null 2>&1 ; then
	echo "consul已经在运行中"
else
	cd ./services
	mkdir consul
	cd consul
	if type unzip > /dev/null 2>&1 ; then
        	echo "已经安装unzip"
	else
        	yum -y install unzip > /dev/null 2>&1
        	echo "已经安装unzip"
	fi
	wget https://releases.hashicorp.com/consul/1.12.0/consul_1.12.0_linux_amd64.zip > /dev/null 2>&1 \
	&& unzip consul_1.12.0_linux_amd64.zip > /dev/null 2>&1
	if test -e consul ; then
        	echo "consul文件已经解压成功"
       		cp consul /usr/local/bin
        	if type consul > /dev/null 2>&1 ; then
                	echo "consul部署完成"
        	else
                	echo "consul安装失败，请检查"
        	fi
	else
        	echo "consul文件解压失败"
	fi
	cd ../../
fi
}
 
initialization;
for i in $@
do
        if test $i = "etcd"; then
                etcdsetting
        elif test $i = "apisix"; then
                apisixsetting
	elif test $i = "consul"; then
		consulseeting
        else
                echo "无法识别参数 $i，将不做处理"
        fi
done

