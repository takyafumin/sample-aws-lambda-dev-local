FROM public.ecr.aws/lambda/python:3.13

# uvのインストール
COPY --from=ghcr.io/astral-sh/uv /uv /uvx /bin/

# uvの仮想環境を有効化
ENV UV_PROJECT_ENVIRONMENT=${LAMBDA_TASK_ROOT}/.venv
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}/src:${LAMBDA_TASK_ROOT}:${LAMBDA_TASK_ROOT}/.venv/lib/python3.13/site-packages \
    VIRTUAL_ENV=${LAMBDA_TASK_ROOT}/.venv

# アプリケーションの依存関係をインストール 
WORKDIR ${LAMBDA_TASK_ROOT}
COPY uv.lock pyproject.toml ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

COPY main.py ${LAMBDA_TASK_ROOT}
# FIXME: .envファイルで認証情報をコンテナにセットするのはよくない
COPY .env ${LAMBDA_TASK_ROOT}

CMD ["main.lambda_handler"]
