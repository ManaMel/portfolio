# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ (全てのステージの基盤)
# =================================================================
ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION-slim AS base

# 作業ディレクトリの設定
WORKDIR /rails

# ベース環境のシステム依存パッケージのインストール
# libvips (画像処理) と postgresql-client (DB接続) を含みます。
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 環境変数の設定 (本番環境用の設定)
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development" \
    PATH="/rails/bin:/usr/local/node/bin:$PATH"

# =================================================================
# BUILD STAGE: アプリケーションのビルドと依存関係のインストール
# =================================================================
FROM base AS build

# ビルドに必要なシステム依存パッケージのインストール
# build-essential や libpq-dev など、GemのC拡張をビルドするために必要
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev node-gyp pkg-config python-is-python3 \
    # 【修正 1-1】libyaml-devを追加: date_core.soやpsychの依存関係解決に役立つ
    libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node.jsとYarnのインストール (フロントエンドのビルド用)
ARG NODE_VERSION=20.19.1
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "$NODE_VERSION" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# 1. Gemのインストール
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# 2. JSパッケージのインストール
COPY package.json yarn.lock ./

# 【修正 1-2】キャッシュ無効化（daisyuiエラー対策）:
# ビルド時のタイムスタンプを引数として渡すことで、この層のDockerキャッシュを強制的に無効化し、
# yarn install が必ず実行されるようにします。
ARG CACHE_BREAKER=$(date +%s)
RUN echo "Cache breaker: $CACHE_BREAKER" 
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .

# =================================================================
# FINAL STAGE: 実行環境 (軽量化のためビルドツールを削除)
# =================================================================
FROM base

# 【修正 2-1】bundlerバージョンを明示的に指定してインストール
RUN gem install bundler -v 2.6.8 --conservative

# ffmpegと【修正 2-2】libyamlのランタイム依存パッケージのインストール
# libyaml-0-2は、date_core.soのエラーを解決するための重要なランタイムライブラリです。
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ffmpeg libyaml-0-2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Build Stageから必要なファイルのみをコピー（Vendor bundleを含む）
COPY --from=build /rails /rails
COPY --from=build /usr/local/node /usr/local/node

# 非ルートユーザーの作成と設定
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails

# ENTRYPOINTとCMDの設定
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"] # Webサービスの起動コマンド
