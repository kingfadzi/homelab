# K3s Installation Guide with k3sup

This guide will help you install K3s on your server using k3sup. Follow the steps below to get your Kubernetes cluster up and running.

## Prerequisites

1. A Mac machine.
2. An Ubuntu server (tested on Ubuntu 22.04).
3. SSH access to your Ubuntu server.

## Steps

### 1. Install k3sup on your Mac

First, you need to install k3sup on your Mac.

```sh
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/
```

### 2. Ensure SSH Key-Based Authentication

To enable passwordless SSH, copy your SSH public key to the server.

```sh
ssh-copy-id fadzi@192.168.1.185
```

### 3. Configure Passwordless sudo on the Server

SSH into your server and configure passwordless `sudo` for your user.

```sh
ssh fadzi@192.168.1.185
```

Edit the sudoers file:

```sh
sudo visudo
```

Add the following line to allow passwordless `sudo` for your user (replace `fadzi` with your username):

```sh
fadzi ALL=(ALL) NOPASSWD:ALL
```

Save and exit the editor.

### 4. Set Up Environment Variable

Export your server IP as an environment variable.

```sh
export IP=192.168.1.185
```

### 5. Install K3s Using k3sup

Use k3sup to install K3s on your server.

```sh
k3sup install --ip $IP --user fadzi
```

### 6. Verify the Installation

Check the status of your K3s node.

```sh
kubectl get node -o wide
```

### 7. Configure kubectl to Use the K3s Cluster

Set up the KUBECONFIG environment variable to use the K3s cluster configuration.

```sh
export KUBECONFIG=/Users/fadzi/tools/charon/kubeconfig
kubectl config use-context default
kubectl get node -o wide
```
### 8. Set workspace:

Check the current context:

```sh
kubectl config current-context
```

Set the default namespace:

```sh
kubectl config set-context --current --namespace=dev
```
