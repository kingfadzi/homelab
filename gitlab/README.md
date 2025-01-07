# Prerequisites

## Install cert-manager

Run the following command in your shell to install cert-manager:

```shell
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml
```

# GitLab Runner Version

This version of the GitLab Runner Operator ships with GitLab Runner `v15.2.1`.

To use a different version of GitLab Runner, change the `runnerImage` and `helperImage` properties.

# Usage

To link a GitLab Runner instance to a self-hosted GitLab instance or to the hosted GitLab, follow these steps:

## Create a Secret Containing the Runner-Registration-Token

1. Create a secret containing the `runner-registration-token` from your GitLab project by running:

```shell
cat > gitlab-runner-secret.yml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-runner-secret
type: Opaque
stringData:
  runner-registration-token: REPLACE_ME # your project runner secret
EOF
```

2. Apply the secret to your cluster:

```shell
oc apply -f gitlab-runner-secret.yml
```

## Create the Custom Resource Definition (CRD) for the GitLab Runner

1. Create a CRD file named `gitlab-runner.yml` with the following content:

```shell
cat > gitlab-runner.yml << EOF
apiVersion: apps.gitlab.com/v1beta2
kind: Runner
metadata:
  name: gitlab-runner
spec:
  gitlabUrl: https://gitlab.example.com
  buildImage: alpine
  token: gitlab-runner-secret
  tags: openshift
EOF
```

2. Apply the CRD to your cluster:

```shell
oc apply -f gitlab-runner.yml
```

Ensure to replace the placeholder `REPLACE_ME` with your actual project's runner secret.

## Access Management for GitLab Runners

[AccessManagementREADME.md](./AccessManagementREADME.md).