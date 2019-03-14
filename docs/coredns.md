# Kubernetes CoreDNS

## 创建CoreDNS
```bash
[root@k8s-master ~]# kubectl create -f /srv/addons/coredns/coredns.yaml

[root@k8s-master ~]# kubectl get pod -n kube-system
NAME                                    READY     STATUS    RESTARTS   AGE
coredns-77c989547b-9pj8b                1/1       Running   0          6m
coredns-77c989547b-kncd5                1/1       Running   0          6m
```
