```
#!/bin/sh
export UNAME=""
export UPASS=""
export DOCKERHUB_NAMESPACE="techempower"
export FRAMEWORK_LANG="C"
export FRAMEWORK="libreactor"
export GITHUB_ORG="TechEmpower"
export GITHUB_REPO="FrameworkBenchmarks"

#Authenticate
export TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${UNAME}'", "password": "'${UPASS}'"}' https://cloud.docker.com/v2/users/login/ | jq -r .token)


#Create Repo
curl -s -H "Content-Type: application/json" -H "Authorization: JWT ${TOKEN}" -X POST \
-d "{\"namespace\":\"${DOCKERHUB_NAMESPACE}\",\"name\":\"tfb.test.${FRAMEWORK}\",\"description\":\"TFB server/test image for ${FRAMEWORK}\",\"is_private\":false}" \
https://cloud.docker.com/v2/repositories/ 


#Create auto-build
curl -s -H "Content-Type: application/json" -H "Authorization: JWT ${TOKEN}" -X POST \
-d  "{\"autotests\":\"OFF\",\"build_in_farm\":true,\"owner\":\"${GITHUB_ORG}\",\"repo_links\":false,\"repository\":\"${GITHUB_REPO}\",\"channel\":\"Stable\",\"build_settings\":[{\"source_type\":\"Branch\",\"tag\":\"latest\",\"dockerfile\":\"${FRAMEWORK}.dockerfile\",\"source_name\":\"master\",\"build_context\":\"/frameworks/${FRAMEWORK_LANG}/${FRAMEWORK}\",\"autobuild\":true,\"nocache\":false}],\"envvars\":[],\"image\":\"${DOCKERHUB_NAMESPACE}/tfb.test.${FRAMEWORK}\",\"provider\":\"github\"}" \
https://cloud.docker.com/api/build/v1/${DOCKERHUB_NAMESPACE}/source/
```

```
git log main --first-parent --merges
```
