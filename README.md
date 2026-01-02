# 🐞 AWS Spotlight Infrastructure As Code

This is the source code for [spotlight.o11y.cool](https://spotlight.o11y.cool),
the quick and easy comparism site for AWS spot prices for the last couple of
years.

## 🚀 Deployment

Deploy the following YAML spaghetti to the Kubernetes cluster of your choice.
We utilize `envsubst` as our poor mans templating engine:

```bash
cat << EOF > secrets.env
aws_access_key="..."
aws_secret_access_key="..."
grafana_domain=spotlight.o11y.cool
grafana_admin_password="..."
EOF
```

```bash
kubectl create namespace o11y-cool
kubectl create configmap spotlight-dashboard --namespace=o11y-cool --from-file=aws-spot-price-dashboard.json
```

```bash
set -a; source secrets.env;set +a;
envsubst < manifests/configuration.yaml | kubectl apply -f -
envsubst < manifests/deployment.yaml | kubectl apply -f -
```
