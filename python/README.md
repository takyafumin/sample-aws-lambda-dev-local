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

4. `main.py`の`lambda_handler`関数をローカルで実行して動作を確認します。

    ```bash
    uv run main.py
    ```

## 参考

- [Python開発環境をVSCode + uvで整える](https://qiita.com/ebimontblanc/items/8a0a52b10a82ba800ea5)
