#!/bin/bash
#
# Create Kubernetes user. Require cfssl.
#
# Usage:
#   ./create-user.sh <kubernetes api host> <fulle name> <clusterrole>
#
# Example:
#   ./create-user.sh k8s-api.my-domain.com "Jane Doe" my-project:admin

set -e

if [ -z "$1" ]
then
  echo "Api host is mandatory"
  exit 1
fi

if [ -z "$2" ]
then
  echo "Fullname is mandatory"
  exit 1
fi

if [ -z "$3" ]
then
  echo "Cluster role is mandatory"
  exit 1
fi

api_host=$1
fullname=$2
cluster_role=$3

username=$(echo ${fullname/ /.} | tr '[:upper:]' '[:lower:]')

read -p "Create user ${fullname} (${username}) with cluster role ${cluster_role}? [Y/n]" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  echo "Canceled."
  exit 1
fi

cat <<EOF | cfssl genkey - | cfssljson -bare client
{
  "hosts": [
    "${api_host}"
  ],
  "CN": "${fullname}",
  "key": {
    "algo": "ecdsa",
    "size": 256
  }
}
EOF

cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${username}
spec:
  groups:
  - system:authenticated
  request: $(cat client.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
  username: ${fullname}
EOF

kubectl certificate approve ${username}

kubectl get csr ${username} -o jsonpath={.status.certificate} | base64 --decode > client.pem
kubectl create clusterrolebinding ${username} --clusterrole=${cluster_role} --user=${fullname}

echo "
-------------------------------------------------------------------------------

You can now share the instructions and the following files to the user:

* certificate authority - ca.pem
* client certificate - client.pem
* client key - client-key.pem

Find below the informations to get started with the development cluster.

1. download certificates
2. run the following command to authenticate

  $ kubectl config set-cluster development --server=https://${api_host} --certificate-authority=ca.pem --embed-certs=true
  $ kubectl config set-credentials development --client-certificate=client.pem --client-key=client-key.pem --embed-certs=true
  $ kubectl config set-context dev --cluster=development --namespace=development --user=janedoe
  $ kubectl config use-context dev
"
