# CFSSL

```
cd files
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout self.key -out self.crt -subj "/C=US/ST=Utah/CN=example.io"
htpasswd -bc .htpasswd admin admin
cd ../
kubectl create secret generic files --from-file=files
```


```
envtpl --keep-template cfssl.secret.yaml.tpl
kubectl apply -f cfssl.secret.yaml
kubectl apply -f cfssl.cm.yaml
kubectl apply -f cfssl.yaml
```
You probably don't need cfssl.secret
