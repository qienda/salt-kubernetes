# -*- coding: utf-8 -*-
#******************************************
# Author:       sky-daiji
# Email:        sky-daiji@qq.com
# Organization: http://www.cnblogs.com/skymydaiji/
# Description:  Kubernetes API Server
#******************************************

{% set k8s_version = "k8s-v1.13.3" %}

kube-api-server-csr-json:
  file.managed:
    - name: /opt/kubernetes/ssl/kubernetes-csr.json
    - source: salt://k8s/templates/kube-api-server/kubernetes-csr.json.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP: {{ pillar['MASTER_IP'] }}
        CLUSTER_KUBERNETES_SVC_IP: {{ pillar['CLUSTER_KUBERNETES_SVC_IP'] }}
  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes kubernetes-csr.json | /opt/kubernetes/bin/cfssljson -bare kubernetes
    - unless: test -f /opt/kubernetes/ssl/kubernetes.pem
metrics-server-csr-json:
  file.managed:
    - name: /opt/kubernetes/ssl/metrics-server-csr.json
    - source: salt://k8s/templates/kube-api-server/metrics-server-csr.json.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes metrics-server-csr.json | /opt/kubernetes/bin/cfssljson -bare metrics-server
    - unless: test -f /opt/kubernetes/ssl/metrics-server.pem
api-auth-encryption-config:
  file.managed:
    - name: /opt/kubernetes/ssl/encryption-config.yaml
    - source: salt://k8s/templates/kube-api-server/encryption-config.yaml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        ENCRYPTION_KEY: {{ pillar['ENCRYPTION_KEY'] }}
kube-apiserver-bin:
  file.managed:
    - name: /opt/kubernetes/bin/kube-apiserver
    - source: salt://k8s/files/{{ k8s_version }}/bin/kube-apiserver
    - user: root
    - group: root
    - mode: 755
    - template: jinja

kube-apiserver-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-apiserver.service
    - source: salt://k8s/templates/kube-api-server/kube-apiserver.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP: {{ pillar['MASTER_IP'] }}
        SERVICE_CIDR: {{ pillar['SERVICE_CIDR'] }}
        NODE_PORT_RANGE: {{ pillar['NODE_PORT_RANGE'] }}
        ETCD_ENDPOINTS: {{ pillar['ETCD_ENDPOINTS'] }}
  pkg.installed:
    - names:
      - ipvsadm
      - ipset
      - conntrack-tools
  cmd.run:
    - name: systemctl daemon-reload
  service.running:
    - name: kube-apiserver
    - enable: True
    - watch:
      - file: kube-apiserver-service
#接着在k8s-master建立TLS bootstrap secret来提供自动签证使用
bootstrap-token-secret:
  file.managed:
    - name: /opt/kubernetes/cfg/bootstrap-token-secret.yaml
    - source: salt://k8s/templates/kube-api-server/bootstrap-token-secret.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        TOKEN_ID: {{ pillar['TOKEN_ID'] }}
        TOKEN_SECRET: {{ pillar['TOKEN_SECRET'] }}
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl delete -f /opt/kubernetes/cfg/bootstrap-token-secret.yaml;/opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/bootstrap-token-secret.yaml
#在k8s-master建立 TLS Bootstrap Autoapprove RBAC来自动处理 CSR
kubelet-bootstrap-rbac:
  file.managed:
    - name: /opt/kubernetes/cfg/kubelet-bootstrap-rbac.yaml
    - source: salt://k8s/templates/kube-api-server/kubelet-bootstrap-rbac.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl delete -f /opt/kubernetes/cfg/kubelet-bootstrap-rbac.yaml;/opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/kubelet-bootstrap-rbac.yaml

#kubectl logs 来查看,但由于 API 权限,故需要建立一个 RBAC Role 来获取存取权限,这边在k8s-master节点执行下面命令创建
apiserver-to-kubelet-rbac:
  file.managed:
    - name: /opt/kubernetes/cfg/apiserver-to-kubelet-rbac.yaml
    - source: salt://k8s/templates/kube-api-server/apiserver-to-kubelet-rbac.yml.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: /opt/kubernetes/bin/kubectl delete -f /opt/kubernetes/cfg/apiserver-to-kubelet-rbac.yaml;/opt/kubernetes/bin/kubectl create -f /opt/kubernetes/cfg/apiserver-to-kubelet-rbac.yaml
