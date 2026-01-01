# nodejs による lambda ローカル実行サンプル

## 実行方法

- コンテナ起動
```shell
docker run -p 9000:8080 \
    -v $(pwd):/var/task:ro \
  public.ecr.aws/lambda/nodejs:22 app.handler
```

- 呼び出し
```shell
curl -X POST localhost:9000/2015-03-31/functions/function/invocations -d '{}'
```
