# SaltStack自动化部署Kubernetes
- SaltStack自动化部署Kubernetes v1.13.3版本（支持TLS双向认证、RBAC授权、Flannel网络、ETCD集群、Kuber-Proxy使用LVS等）。

## 版本明细：Release-v1.13.3
- 测试通过系统：CentOS 7.6
- salt-ssh:     2019.2.0
- Kubernetes：  v1.13.3
- Etcd:         v3.3.12
- Docker:       18.9.3-ce
- Flannel：     v0.10.0
- CNI-Plugins： v0.7.4
建议部署节点：最少三个节点，请配置好主机名解析（必备）

## 架构介绍
1. 使用Salt Grains进行角色定义，增加灵活性。
2. 使用Salt Pillar进行配置项管理，保证安全性。
3. 使用Salt SSH执行状态，不需要安装Agent，保证通用性。
4. 使用Kubernetes当前稳定版本v1.13.3，保证稳定性。

## 技术交流QQ群（加群请备注来源于Github）：
- Docker&Kubernetes：796163694


## 0.系统初始化(必备)
1. 设置主机名！！！
```
[root@k8s-master ~]# cat /etc/hostname
k8s-master

[root@k8s-node1 ~]# cat /etc/hostname
k8s-node1

[root@k8s-node2 ~]# cat /etc/hostname
k8s-node2

```
2. 设置/etc/hosts保证主机名能够解析
```
[root@k8s-master ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.16.40.80 k8s-master
172.16.40.81 k8s-node1
172.16.40.82 k8s-node2

```
3. 初始化系统配置以适合docker和k8s运行

<table border="0">
    <tr>
        <td><a href="docs/update-kernel.md">升级内核</a></td>
    </tr>
</table>

4. 以上必备条件必须严格检查，否则，一定不会部署成功！


## 1.设置部署节点到其它所有节点的SSH免密码登录（包括本机）
```bash
[root@k8s-master ~]# ssh-keygen -t rsa
[root@k8s-master ~]# ssh-copy-id k8s-master
[root@k8s-master ~]# ssh-copy-id k8s-node1
[root@k8s-master ~]# ssh-copy-id k8s-node2
```

## 2.安装Salt-SSH并克隆本项目代码。

2.1 安装Salt SSH（注意：老版本的Salt SSH不支持Roster定义Grains，需要2017.7.4以上版本）
```
[root@k8s-master ~]# yum install -y salt-ssh git unzip
```

2.2 获取本项目代码，并放置在/srv目录
```
[root@k8s-master ~]# git clone https://github.com/sky-daiji/salt-kubernetes.git
[root@k8s-master ~]# cd salt-kubernetes/
[root@k8s-master ~]# mv * /srv/
[root@k8s-master srv]# /bin/cp /srv/roster /etc/salt/roster
[root@k8s-master srv]# /bin/cp /srv/master /etc/salt/master
```

2.4 下载二进制文件，也可以自行官方下载，为了方便国内用户访问，请在百度云盘下载,下载k8s-v1.13.3-auto.zip。
下载完成后，将文件移动到/srv/salt/k8s/目录下，并解压
Kubernetes二进制文件下载地址： https://pan.baidu.com/s/1A2cb3fI7fu3r3oC1G-S7CA   提取码:qgc9

```
[root@k8s-master ~]# cd /srv/salt/k8s/
[root@k8s-master k8s]# unzip k8s-v1.13.3-auto.zip
[root@k8s-master k8s]# cd k8s-v1.13.3-auto/
[root@k8s-master k8s-v1.13.3-auto]# mv files/ /srv/salt/k8s/
[root@k8s-master k8s-v1.13.3-auto]# cd ..
[root@k8s-master k8s]# rm -rf k8s-v1.13.3-auto*
[root@k8s-master k8s]# ls -l files/
total 0
drwxr-xr-x. 2 root root  94 Jun  3 19:12 cfssl-1.2
drwxr-xr-x. 2 root root 195 Jun  3 19:12 cni-plugins-amd64-v0.7.4
drwxr-xr-x. 2 root root  33 Jun  3 19:12 etcd-v3.3.12-linux-amd64
drwxr-xr-x. 2 root root  47 Jun  3 19:12 flannel-v0.10.0-linux-amd64
drwxr-xr-x. 3 root root  17 Jun  3 19:12 k8s-v1.13.3

```

## 3.Salt SSH管理的机器以及角色分配

- k8s-role: 用来设置K8S的角色
- etcd-role: 用来设置etcd的角色，如果只需要部署一个etcd，只需要在一台机器上设置即可
- etcd-name: 如果对一台机器设置了etcd-role就必须设置etcd-name

```
[root@k8s-master ~]# vim /etc/salt/roster
k8s-master:
  host: 172.16.40.80
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node1

k8s-node1:
  host: 172.16.40.81
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
      etcd-role: node
      etcd-name: etcd-node2

k8s-node2:
  host: 172.16.40.82
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
      etcd-role: node
      etcd-name: etcd-node3
```

## 4.修改对应的配置参数，本项目使用Salt Pillar保存配置
```
[root@k8s-master ~]# vim /srv/pillar/k8s.sls
#设置Master的IP地址(必须修改)
MASTER_IP: "172.16.40.80"
NODE01_IP: "172.16.40.81"
NODE02_IP: "172.16.40.82"

#设置Master的HOSTNAME完整的FQDN名称(必须修改)
k8s-matser: "k8s-master"
k8s-node1: "k8s-node1"
k8s-node2: "k8s-node2"

#设置ETCD集群访问地址（必须修改）
ETCD_ENDPOINTS: "https://172.16.40.80:2379,https://172.16.40.81:2379,https://172.16.40.82:2379"

#设置ETCD集群初始化列表（必须修改）
ETCD_CLUSTER: "etcd-node1=https://172.16.40.80:2380,etcd-node2=https://172.16.40.81:2380,etcd-node3=https://172.16.40.82:2380"

#通过Grains FQDN自动获取本机IP地址，请注意保证主机名解析到本机IP地址
NODE_IP: {{ grains['fqdn_ip4'][0] }}
HOST_NAME: {{ grains['fqdn'] }}

#设置BOOTSTARP的TOKEN，可以自己生成
BOOTSTRAP_TOKEN: "ad6d5bb607a186796d8861557df0d17f"

#配置Service IP地址段
SERVICE_CIDR: "10.1.0.0/16"

#Kubernetes服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_KUBERNETES_SVC_IP: "10.1.0.1"

#Kubernetes DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP: "10.1.0.2"

#设置Node Port的端口范围
NODE_PORT_RANGE: "20000-40000"

#设置POD的IP地址段
POD_CIDR: "10.2.0.0/16"

#设置集群的DNS域名
CLUSTER_DNS_DOMAIN: "cluster.local."

#设置网卡名称
VIP_IF: "{{ grains['ip4_interfaces'].keys()[1] }}"


```

## 5.执行SaltStack状态

5.1 测试Salt SSH联通性
```
[root@k8s-master ~]# salt-ssh '*' test.ping
```
执行高级状态，会根据定义的角色再对应的机器部署对应的服务

5.2 部署Etcd，由于Etcd是基础组建，需要先部署，目标为部署etcd的节点。
```
[root@k8s-master ~]# salt-ssh -L 'k8s-master,k8s-node1,k8s-node2' state.sls k8s.etcd
```
注：如果执行失败，新手建议推到重来，请检查各个节点的主机名解析是否正确（监听的IP地址依赖主机名解析）。

5.3 部署K8S集群
```
[root@k8s-master ~]# salt-ssh '*' state.highstate
```
由于包比较大，这里执行时间较长，10分钟+，喝杯咖啡休息一下，如果执行有失败可以再次执行即可！

## 6.测试Kubernetes安装
```
[root@k8s-master ~]# source /etc/profile
[root@k8s-master ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-0               Healthy   {"health":"true"}   
etcd-2               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}   
[root@k8s-master ~]# kubectl get node
NAME            STATUS    ROLES     AGE       VERSION
k8s-master      Ready     master    1m        v1.13.3
k8s-node1       Ready     node      1m        v1.13.3
k8s-node2       Ready     node      1m        v1.13.3
```
## 7.测试Kubernetes集群和Flannel网络

```
[root@k8s-master ~]# kubectl run net-test --image=alpine --replicas=2 sleep 360000
deployment "net-test" created
需要等待拉取镜像，可能稍有的慢，请等待。
[root@k8s-master ~]# kubectl get pod -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP          NODE
net-test-5767cb94df-n9lvk   1/1       Running   0          14s       10.2.12.2   172.16.40.82
net-test-5767cb94df-zclc5   1/1       Running   0          14s       10.2.24.2   172.16.40.81

测试联通性，如果都能ping通，说明Kubernetes集群部署完毕，有问题请QQ群交流。
[root@k8s-master ~]# ping -c 1 10.2.12.2
PING 10.2.12.2 (10.2.12.2) 56(84) bytes of data.
64 bytes from 10.2.12.2: icmp_seq=1 ttl=61 time=8.72 ms

--- 10.2.12.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 8.729/8.729/8.729/0.000 ms

[root@k8s-master ~]# ping -c 1 10.2.24.2
PING 10.2.24.2 (10.2.24.2) 56(84) bytes of data.
64 bytes from 10.2.24.2: icmp_seq=1 ttl=61 time=22.9 ms

--- 10.2.24.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 22.960/22.960/22.960/0.000 ms

```
## 8.如何新增Kubernetes节点

- 1.设置SSH无密码登录
- 2.在/etc/salt/roster里面，增加对应的机器
- 3.执行SaltStack状态 `salt-ssh '*' state.highstate` 。
```
[root@k8s-master ~]# vim /etc/salt/roster
k8s-node3:
  host: 172.16.40.83
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
[root@k8s-master ~]# salt-ssh 'k8s-node3' state.highstate
```

## 9.下一步要做什么？

你可以安装Kubernetes必备的插件
<table border="0">
    <tr>
        <td><strong>必备插件</strong></td>
        <td><a href="docs/coredns.md">1.CoreDNS部署</a></td>
        <td><a href="docs/dashboard.md">2.Dashboard部署</a></td>
        <td><a href="docs/heapster.md">3.Heapster部署</a></td>
        <td><a href="docs/metrics-server.md">4.metrics-server部署</a></td>
        <td><a href="docs/ingress-nginx-Deployment.md">5.Ingress部署-Deployment</a></td>
        <td><a href="docs/ingress-nginx-DaemonSet.md">6.Ingress部署-DaemonSet</a></td>
    </tr>
</table>

为Master节点打上污点，让POD尽可能的不要调度到Master节点上。
关于污点的说明大家可自行百度。

```
kubectl taint node k8s-master node-role.kubernetes.io/master=k8s-master:PreferNoSchedule
```

注意：不要相信自己，要相信电脑！！！



## 如果你觉得这个项目不错，欢迎各位打赏，你的打赏是对我们的认可，是我们的动力。

![微信](https://github.com/sky-daiji/salt-kubernetes/blob/master/images/weixin.png)
