# Devops

This repository contains some scripts that I have created to manage servers. The are mostly written in Ruby and rely on Ansible playbooks (found [here](https://github.com/benjamincaldwell/ansible))

## Getting Started

### Clone Repo

This repository depends on [benjamincaldwell/ansible](https://github.com/benjamincaldwell/ansible)

```bash
git clone git@github.com:benjamincaldwell/devops.git --recursive
```

### Install dependencies 
``` bash
bundle install
```

#### Ejson

This project uses [ejson](https://github.com/Shopify/ejson) to manage secrets. By default it looks for an ejson file located at `./config/secrets.ejson`.

## Kubernetes

Sets up a using [kubeadm](https://kubernetes.io/docs/getting-started-guides/kubeadm/). Currently only supports ubuntu linux distributions. To set up a cluster first create a configuration file. By default it looks for a file at `./config/clusters/kubernetes.yml`.

``` yam
---
- ip: 0.0.0.1
  user: root
  # optional: defaults to using ssh keys
  password: awesome-pass
  # optional: defaults to node
  role: master
- ip: 0.0.0.2
  user: root
  role: node
```

### CLI options

``` bash
Usage: kubernetes init [options]
    -c, --config NAME                config file
    -k, --kubeconfig NAME            location to copy new kube config file to
    -e, --ejson NAME                 ejson file
```

### Initialization

- Installs all dependencies
- Sets up the cluster. 

Note: will also upgrade any ubuntu 14 notes to ubuntu 16

```
./bin/kubernetes-setup
```

### Security 

- Sets up firewall
- Creates cloud user and copies over ssh keys from `./config/ssh-public-keys`. **Cloud user password is set using the ejson value: `cloud_user_password`**
- disable root and password ssh authentication 

```
./bin/kubernetes-security
```