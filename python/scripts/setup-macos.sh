#!/bin/bash

# macOS環境セットアップスクリプト

set -e

echo "🍎 macOS用開発環境のセットアップを開始します..."

# Homebrewの確認とインストール
if ! command -v brew &> /dev/null; then
    echo "🍺 Homebrewをインストールしています..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrewは既にインストールされています"
fi

# 必要ツールのインストール
echo "🔧 必要ツールをインストールしています..."

# Python (uvを使用するのでここでは確認のみ)
if ! command -v python3 &> /dev/null; then
    echo "🐍 Pythonをインストールしています..."
    brew install python@3.13
else
    echo "✅ Pythonは既にインストールされています: $(python3 --version)"
fi

# uvのインストール
if ! command -v uv &> /dev/null; then
    echo "⚡ uvをインストールしています..."
    brew install uv
else
    echo "✅ uvは既にインストールされています: $(uv --version)"
fi

# Dockerのインストール
if ! command -v docker &> /dev/null; then
    echo "🐳 Dockerをインストールしています..."
    echo "💡 Docker DesktopまたはOrbStackをインストールしてください:"
    echo "   brew install --cask docker"
    echo "   または"
    echo "   brew install --cask orbstack"
    echo ""
    echo "⚠️  Docker Desktopを手動でインストール後、再度このスクリプトを実行してください"
    exit 1
else
    echo "✅ Dockerは既にインストールされています"
    if ! docker ps &> /dev/null; then
        echo "⚠️  Docker daemonが起動していません"
        echo "💡 Docker DesktopまたはOrbStackを起動してください"
        exit 1
    fi
fi

# AWS CLIのインストール
if ! command -v aws &> /dev/null; then
    echo "☁️  AWS CLIをインストールしています..."
    brew install awscli
else
    echo "✅ AWS CLIは既にインストールされています: $(aws --version)"
fi

# プロジェクト依存関係のインストール
echo "📦 プロジェクト依存関係をインストールしています..."
if [[ -f "pyproject.toml" ]]; then
    uv sync
    echo "✅ 依存関係のインストールが完了しました"
else
    echo "⚠️  pyproject.tomlが見つかりません。プロジェクトルートで実行してください"
fi

# .envファイルのテンプレート作成
if [[ ! -f "docker/.env" ]]; then
    echo "📝 環境変数テンプレートを作成しています..."
    cat > "docker/.env" << 'EOF'
# AWS認証情報 (本番環境では使用しないでください)
# AWS_ACCESS_KEY_ID=your_access_key_here
# AWS_SECRET_ACCESS_KEY=your_secret_key_here
# AWS_DEFAULT_REGION=ap-northeast-1

# その他の環境変数
# DATABASE_URL=your_database_url_here
EOF
    echo "✅ docker/.env テンプレートを作成しました"
    echo "💡 必要に応じて環境変数を設定してください"
else
    echo "✅ docker/.env は既に存在しています"
fi

# スクリプトに実行権限を付与
echo "🔐 スクリプトに実行権限を付与しています..."
chmod +x scripts/*.sh

echo ""
echo "🎉 macOS環境のセットアップが完了しました！"
echo ""
echo "次のステップ:"
echo "1. AWS認証情報を設定: aws configure"
echo "2. 必要に応じてdocker/.envファイルを編集"
echo "3. ローカルテスト: ./scripts/test-local.sh"
echo "4. デプロイ: ./scripts/deploy.sh"
echo ""
echo "💡 ヒント:"
echo "- Apple Silicon (M1/M2) Macの場合、自動的にx86_64プラットフォームでビルドされます"
echo "- AWS ProfileはAWS_PROFILEまたはaws configureで設定できます"