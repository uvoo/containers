current_time_seconds=$(date +%s)
ts=$((current_time_seconds - 0))
rn=$(( ( RANDOM % 20 )  + 10 ))
echo $rn

# -H "X-Scope-OrgID: test" \
curl -X POST -g \
    -u user1:pass1 \
    --data "my_metric2{app=\"test\",job=\"test\",instance=\"test\"} $rn ${ts}" \
    https://pushproxy.example.com/api/v1/push
