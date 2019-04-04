# -*- coding: utf-8 -*-
#******************************************
# Author:       sky-daiji
# Email:        sky-daiji@qq.com
# Organization: http://www.cnblogs.com/skymydaiji/
# Description:  SaltStack Top File
#******************************************

base:
  'k8s-role:master':
    - match: grain
    - k8s.master
  'k8s-role:node':
    - match: grain
    - k8s.node
  'etcd-role:node':
    - match: grain
    - k8s.etcd
