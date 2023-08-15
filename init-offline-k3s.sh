#！/bin/bash
function k3s-init()
{
if [ -d "/mnt/data/deploy/k3s-init" ];then
    cd /mnt/data/deploy/k3s-init
else
    echo "k3s集群初始化目录不存在，请检查，，终止k3s初始化"
    exit
fi
if [ -f "k3s-airgap-images-amd64.tar.gz" ];then
    #使用containerd运行时，需要将镜像包放在指定位置
    #mkdir -p /var/lib/rancher/k3s/agent/images/ && cp ./k3s-airgap-images-amd64.tar.gz /var/lib/rancher/k3s/agent/images/
    #使用docker运行时，需要加载镜像
    docker load -i k3s-airgap-images-amd64.tar
else
    echo "离线镜像文件不存在，请检查，终止k3s初始化"
    exit
fi
if [ -f "k3s" ];then
    cp ./k3s /usr/local/bin && chmod +x /usr/local/bin/k3s
else
    echo "离线k3s文件不存在，请检查，终止k3s初始化"
    exit
fi
if [ -f "install.sh" ];then
    chmod +x install.sh
else
    echo "install.sh文件不存在，请检查，终止k3s初始化"
    exit
fi
#设置变量，表示为离线安装
export INSTALL_K3S_SKIP_DOWNLOAD=true
#设置变量，表示使用docker运行时，如果时containerd，则省略
export INSTALL_K3S_EXEC='--docker' 
./install.sh
kubectl get node -o wide
if [ $? -eq 0 ];then
    echo "k3s集群初始化完成"
else
    echo "k3s集群初始化失败，请检查，终止k3s初始化"
fi
}
k3s-init
