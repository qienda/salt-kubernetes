# -*- coding: utf-8 -*-
#******************************************
# Author:       sky-daiji
# Email:        sky-daiji@qq.com
# Organization: http://www.cnblogs.com/skymydaiji/
# Description:  Kubernetes Scheduler
#******************************************

{% set k8s_version = "k8s-v1.13.3" %}


kube-scheduler-csr-json:
  file.managed:
    - name: /opt/kubernetes/ssl/kube-scheduler-csr.json
    - source: salt://k8s/templates/kube-scheduler/kube-scheduler-csr.json.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        MASTER_IP: {{ pillar['MASTER_IP'] }}

  cmd.run:
    - name: cd /opt/kubernetes/ssl && /opt/kubernetes/bin/cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem -ca-key=/opt/kubernetes/ssl/ca-key.pem -config=/opt/kubernetes/ssl/ca-config.json -profile=kubernetes kube-scheduler-csr.json | /opt/kubernetes/bin/cfssljson -bare kube-scheduler
    - unless: test -f /opt/kubernetes/ssl/kube-scheduler.pem
kube-scheduler-bin:
  file.managed:
    - name: /opt/kubernetes/bin/kube-scheduler
    - source: salt://k8s/files/{{ k8s_version }}/bin/kube-scheduler
    - user: root
    - group: root
    - mode: 755
kube-scheduler-cluster:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-cluster kubernetes --certificate-authority=/opt/kubernetes/ssl/ca.pem --embed-certs=true --server=https://{{ pillar['MASTER_IP'] }}:6443 --kubeconfig=kube-scheduler.kubeconfig

kubectl-scheduler-credentials:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-credentials system:kube-scheduler --client-certificate=/opt/kubernetes/ssl/kube-scheduler.pem --embed-certs=true --client-key=/opt/kubernetes/ssl/kube-scheduler-key.pem --kubeconfig=kube-scheduler.kubeconfig

kubectl-scheduler-context:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config set-context system:kube-scheduler --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig

kubectl-scheduler-use:
  cmd.run:
    - name: cd /opt/kubernetes/cfg && /opt/kubernetes/bin/kubectl config use-context system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig

kube-scheduler-service:
  file.managed:
    - name: /usr/lib/systemd/system/kube-scheduler.service
    - source: salt://k8s/templates/kube-scheduler/kube-scheduler.service.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
  cmd.run:
    - name: systemctl daemon-reload
    - watch:
      - file: kube-scheduler-service
  service.running:
    - name: kube-scheduler
    - enable: True
    - watch:
      - file: kube-scheduler-service
