FROM public.ecr.aws/lambda/python:3.13

# uvのインストール
COPY --from=ghcr.io/astral-sh/uv /uv /uvx /bin/

# uvの仮想環境を有効化
ENV UV_PROJECT_ENVIRONMENT=${LAMBDA_TASK_ROOT}/.venv
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}/src:${LAMBDA_TASK_ROOT}:${LAMBDA_TASK_ROOT}/.venv/lib/python3.13/site-packages \
    VIRTUAL_ENV=${LAMBDA_TASK_ROOT}/.venv

# アプリケーションの依存関係をインストール 
WORKDIR ${LAMBDA_TASK_ROOT}

# 依存関係ファイルをコピー（macOSからのビルドでもパスが正しく解決されるように調整）
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

# ソースコードをコピー
COPY src/handlers/lambda_handler.py ${LAMBDA_TASK_ROOT}/src/handlers/
COPY src/__init__.py ${LAMBDA_TASK_ROOT}/src/

# 環境変数ファイルをコピー（存在する場合のみ）
# FIXME: .envファイルで認証情報をコンテナにセットするのはよくない
COPY docker/.env ${LAMBDA_TASK_ROOT}/ 2>/dev/null || echo ".envファイルが見つかりません（オプション）"

CMD ["src.handlers.lambda_handler.lambda_handler"]
