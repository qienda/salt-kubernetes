## 1.部署Kubernetes API服务部署
### 0.准备软件包
```
[root@k8s-master ~]# cd /usr/local/src/kubernetes
[root@k8s-master kubernetes]# cp server/bin/kube-apiserver /opt/kubernetes/bin/
[root@k8s-master kubernetes]# cp server/bin/kube-controller-manager /opt/kubernetes/bin/
[root@k8s-master kubernetes]# cp server/bin/kube-scheduler /opt/kubernetes/bin/
```

### 1.创建生成CSR的 JSON 配置文件
```
[root@k8s-master src]# vim kubernetes-csr.json
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "172.16.40.80",
    "10.1.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```

### 2.生成 kubernetes 证书和私钥
```
 [root@k8s-master src]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
   -ca-key=/opt/kubernetes/ssl/ca-key.pem \
   -config=/opt/kubernetes/ssl/ca-config.json \
   -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
[root@k8s-master src]# cp kubernetes*.pem /opt/kubernetes/ssl/
[root@k8s-master ~]# scp kubernetes*.pem 172.16.40.81:/opt/kubernetes/ssl/
[root@k8s-master ~]# scp kubernetes*.pem 172.16.40.82:/opt/kubernetes/ssl/
```

### 3.创建 kube-apiserver加密配置文件
```
[root@k8s-master ~]# vim /opt/kubernetes/ssl/encryption-config.yaml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: {{ ENCRYPTION_KEY }}
      - identity: {}
```

### 4.部署Kubernetes API Server
```
[root@k8s-master ~]# vim /usr/lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/opt/kubernetes/bin/kube-apiserver \
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --allow-privileged=true \
  --experimental-encryption-provider-config=/opt/kubernetes/ssl/encryption-config.yaml \
  --advertise-address=172.16.40.80 \
  --insecure-port=0 \
  --secure-port=6443 \
  --authorization-mode=Node,RBAC \
  --enable-bootstrap-token-auth=true \
  --service-cluster-ip-range=10.1.0.0/16 \
  --service-node-port-range=20000-40000 \
  --tls-cert-file=/opt/kubernetes/ssl/kubernetes.pem \
  --tls-private-key-file=/opt/kubernetes/ssl/kubernetes-key.pem \
  --client-ca-file=/opt/kubernetes/ssl/ca.pem \
  --kubelet-client-certificate=/opt/kubernetes/ssl/kubernetes.pem \
  --kubelet-client-key=/opt/kubernetes/ssl/kubernetes-key.pem \
  --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \
  --service-account-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --etcd-cafile=/opt/kubernetes/ssl/ca.pem \
  --etcd-certfile=/opt/kubernetes/ssl/kubernetes.pem \
  --etcd-keyfile=/opt/kubernetes/ssl/kubernetes-key.pem \
  --etcd-servers=https://172.16.40.80:2379,https://172.16.40.81:2379,https://172.16.40.82:2379 \
  --enable-swagger-ui=true \
  --max-mutating-requests-inflight=2000 \
  --max-requests-inflight=4000 \
  --requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \
  --requestheader-allowed-names= \
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-username-headers=X-Remote-User \
  --proxy-client-cert-file=/opt/kubernetes/ssl/metrics-server.pem \
  --proxy-client-key-file=/opt/kubernetes/ssl/metrics-server-key.pem \
  --runtime-config=api/all=true \
  --apiserver-count=3 \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/kube-apiserver-audit.log \
  --event-ttl=1h \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log \
  --v=2

[Install]
WantedBy=multi-user.target
```

### 6.启动API Server服务
```
[root@k8s-master ~]# systemctl daemon-reload
[root@k8s-master ~]# systemctl enable kube-apiserver
[root@k8s-master ~]# systemctl start kube-apiserver
```

查看API Server服务状态
```
[root@k8s-master ~]# systemctl status kube-apiserver
```

## 2.部署Kubernetes controller-manager服务部署

### 0.创建生成kube-controller-manager CSR的 JSON 配置文件
```
[root@k8s-master ]# vim kub-controller-manager-csr.json
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "172.16.40.80"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-controller-manager",
        "OU": "System"
      }
    ]
}
```

### 1.生成Kubernetes controller manager证书和私钥
```
[root@k8s-master ]# cd /opt/kubernetes/ssl
[root@k8s-master ssl]# /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes kube-controller-manager-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-controller-manager
```

### 2.创建kubeconfig 文件
```
[root@k8s-master ]# cd /opt/kubernetes/cfg
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config set-cluster kubernetes --certificate-authority=/opt/kubernetes/ssl/ca.pem --embed-certs=true --server=https://172.16.40.80:6443 --kubeconfig=kube-controller-manager.kubeconfig
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config set-credentials system:kube-controller-manager --client-certificate=/opt/kubernetes/ssl/kube-controller-manager.pem --embed-certs=true --client-key=/opt/kubernetes/ssl/kube-controller-manager-key.pem --kubeconfig=kube-controller-manager.kubeconfig
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config set-context system:kube-controller-manager --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
```

### 3.部署Kubernetes controller manager服务
```
[root@k8s-master ]# vim /usr/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-controller-manager \
  --address=127.0.0.1 \
  --allocate-node-cidrs=true \
  --authentication-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \
  --authorization-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \
  --kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \
  --service-cluster-ip-range=10.1.0.0/16 \
  --cluster-cidr=10.2.0.0/16 \
  --cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --root-ca-file=/opt/kubernetes/ssl/ca.pem \
  --service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --leader-elect=true \
  --feature-gates=RotateKubeletServerCertificate=true \
  --controllers=*,bootstrapsigner,tokencleaner \
  --horizontal-pod-autoscaler-use-rest-clients=true \
  --horizontal-pod-autoscaler-sync-period=10s \
  --tls-cert-file=/opt/kubernetes/ssl/kube-controller-manager.pem \
  --tls-private-key-file=/opt/kubernetes/ssl/kube-controller-manager-key.pem \
  --use-service-account-credentials=true \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target

```

### 4.启动Kubernetes controller manager服务
```
[root@k8s-master ~]# systemctl daemon-reload
[root@k8s-master ~]# systemctl enable kube-controller-manager
[root@k8s-master ~]# systemctl start kube-controller-manager
```
查看controller manager服务状态
```
[root@k8s-master ~]# systemctl status kube-controller-manager
```

## 3.部署Kubernetes scheduler服务部署

### 0.创建生成Kubernetes scheduler CSR的 JSON 配置文件
```
[root@k8s-master ]# vim kube-scheduler-csr.json
{
    "CN": "system:kube-scheduler",
    "hosts": [
      "127.0.0.1",
      "172.16.40.80"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-scheduler",
        "OU": "System"
      }
    ]
}

```
### 1.生成Kubernetes scheduler证书和私钥
```
[root@k8s-master ]# cd /opt/kubernetes/ssl
[root@k8s-master ssl]# /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes kube-scheduler-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-scheduler
```

### 2.创建kubeconfig 文件
```
[root@k8s-master ]# cd /opt/kubernetes/cfg
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config set-cluster kubernetes --certificate-authority=/opt/kubernetes/ssl/ca.pem --embed-certs=true --server=https://172.16.40.80:6443 --kubeconfig=kube-scheduler.kubeconfig
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config set-credentials system:kube-scheduler --client-certificate=/opt/kubernetes/ssl/kube-scheduler.pem --embed-certs=true --client-key=/opt/kubernetes/ssl/kube-scheduler-key.pem --kubeconfig=kube-scheduler.kubeconfig
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config set-context system:kube-scheduler --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
[root@k8s-master cfg]# /opt/kubernetes/bin/kubectl config use-context system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
```

### 3.部署Kubernetes scheduler服务
```
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-scheduler --address=127.0.0.1 --kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig --leader-elect=true --alsologtostderr=true --logtostderr=false --log-dir=/opt/kubernetes/log --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target

```
### 4.启动Kubernetes scheduler服务
```
[root@k8s-master ~]# systemctl daemon-reload
[root@k8s-master ~]# systemctl enable kube-scheduler
[root@k8s-master ~]# systemctl start kube-scheduler
```
查看scheduler服务状态
```
[root@k8s-master ~]# systemctl status kube-scheduler
```
## 部署kubectl 命令行工具

1.准备二进制命令包
```
[root@k8s-master ~]# cd /usr/local/src/kubernetes/client/bin
[root@k8s-master bin]# cp kubectl /opt/kubernetes/bin/
```

2.创建 admin 证书签名请求
```
[root@k8s-master ~]# cd /usr/local/src/ssl/
[root@k8s-master ssl]# vim admin-csr.json
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
```

3.生成 admin 证书和私钥：
```
[root@k8s-master ssl]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
   -ca-key=/opt/kubernetes/ssl/ca-key.pem \
   -config=/opt/kubernetes/ssl/ca-config.json \
   -profile=kubernetes admin-csr.json | cfssljson -bare admin
[root@k8s-master ssl]# ls -l admin*
-rw-r--r-- 1 root root 1009 Mar  5 12:29 admin.csr
-rw-r--r-- 1 root root  229 Mar  5 12:28 admin-csr.json
-rw------- 1 root root 1675 Mar  5 12:29 admin-key.pem
-rw-r--r-- 1 root root 1399 Mar  5 12:29 admin.pem

[root@k8s-master src]# mv admin*.pem /opt/kubernetes/ssl/
```

4.设置集群参数
```
[root@k8s-master src]# kubectl config set-cluster kubernetes \
   --certificate-authority=/opt/kubernetes/ssl/ca.pem \
   --embed-certs=true \
   --server=https://172.16.40.80:6443
Cluster "kubernetes" set.
```

5.设置客户端认证参数
```
[root@k8s-master src]# kubectl config set-credentials admin \
   --client-certificate=/opt/kubernetes/ssl/admin.pem \
   --embed-certs=true \
   --client-key=/opt/kubernetes/ssl/admin-key.pem
User "admin" set.
```

6.设置上下文参数
```
[root@k8s-master src]# kubectl config set-context kubernetes \
   --cluster=kubernetes \
   --user=admin
Context "kubernetes" created.
```

7.设置默认上下文
```
[root@k8s-master src]# kubectl config use-context kubernetes
Switched to context "kubernetes".
```

8.使用kubectl工具
```
[root@k8s-master ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok                  
scheduler            Healthy   ok                  
etcd-1               Healthy   {"health":"true"}   
etcd-2               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}   
```
