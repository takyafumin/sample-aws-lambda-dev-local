# lambda(python)のローカル開発環境検証サンプル

## 概要

AWS LambdaのPython環境でのローカル開発環境を検証するためのサンプルプロジェクトです。

## 環境

- Python 3.13
- boto3

## 使い方

1. リポジトリをクローンします。

    ```bash
    git clone <repository_url>
    cd aws-sample-lambda-dev-local/python
    ```
2. 必要なパッケージをインストールします。

    ```bash
    uv sync
    ```

3. 環境変数を設定します。`.env.sample`を参考に`.env`ファイルを作成し、AWSのアクセスキー、シークレットキー、バケット名を設定してください。

## 実行方法

### ローカルCLI実行

1. `main.py`の`lambda_handler`関数をローカルで実行して動作を確認します。

    ```bash
    uv run main.py
    ```

### Lambdaエミュレーション実行

1. Dockerを使用してLambda環境をエミュレートし、関数を実行します。

    ```bash
    docker build -t lambda-python-sample .
    docker run --rm -p 9000:8080 lambda-python-sample
    ```

2. curlコマンドでエミュレートされたLambda関数を呼び出します。

    ```bash
    curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
    ```

## 参考

- [Python開発環境をVSCode + uvで整える](https://qiita.com/ebimontblanc/items/8a0a52b10a82ba800ea5)
