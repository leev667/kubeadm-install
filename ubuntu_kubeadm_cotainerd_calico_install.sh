#!/bin/bash

#install pre-requisite packages https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
apt install curl apt-transport-https vim git wget gnupg2 software-properties-common ca-certificates uidmap wget -y

#turn off swap
swapoff -a

#apply network probes
modprobe overlay
modprobe br_netfilter
cat << EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

#container packages https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd & https://docs.docker.com/engine/install/ubuntu/
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
"deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update &&  apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
containerd config default | tee /etc/containerd/config.toml
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

#kubernetes repo
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt update
apt-get install -y kubeadm=1.26.1-00 kubelet=1.26.1-00 kubectl=1.26.1-00 -y
apt-mark hold kubelet kubeadm kubectl

#cni calico 
wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

#kubeadm config change ip's accordingly
kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=10.0.0.27 | tee kubeadm-init.out

#post install config
exit
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#configure calico
sudo cp /root/calico.yaml .
kubectl apply -f calico.yaml

#bash completion
sudo apt-get install bash-completion -y
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> $HOME/.bashrc
