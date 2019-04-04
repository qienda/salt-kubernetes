# -*- coding: utf-8 -*-
#******************************************
# Author:       sky-daiji
# Email:        sky-daiji@qq.com
# Organization: http://www.cnblogs.com/skymydaiji/
# Description:  Kubernetes Node
#******************************************

include:
  - k8s.modules.ca-file
  - k8s.modules.cfssl
  - k8s.modules.kubectl
  - k8s.modules.flannel
  - k8s.modules.docker
  - k8s.modules.kubelet
  - k8s.modules.kube-proxy
