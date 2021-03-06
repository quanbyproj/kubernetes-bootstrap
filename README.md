
```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v1.8.2/manifests/ha/install.yaml
```

```
kubectl patch deploy argocd-server -n argocd -p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]' --type json
```

```
cat << EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  rules:
  - host: argocd.k8s-dev-01.quanby.lan
    http:
      paths:
      - backend:
          serviceName: argocd-server
          servicePort: https
EOF
```

wget https://github.com/argoproj/argo-cd/releases/download/v1.8.2/argocd-linux-amd64
