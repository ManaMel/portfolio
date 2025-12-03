# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ
# =================================================================
ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION-slim AS base

# 作業ディレクトリの設定
WORKDIR /rails

# ベース環境のシステム依存パッケージのインストール
# libvips (画像処理), postgresql-client (DB接続)
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

# ビルドに必要なシステム依存パッケージのインストール (C拡張ビルド用)
# zlib1g-dev, libgmp-dev, libssl-dev, openssl などを追加し、より多くのC拡張に対応
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev node-gyp pkg-config python-is-python3 \
    libyaml-dev zlib1g-dev libgmp-dev libssl-dev openssl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node.jsとYarnのインストール
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
# これでdaisyuiが確実にインストールされます
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .

# 【重要】アセットプリコンパイルをDocker Build Stage内で完了させる
# Sidekiq/Redisの初期化エラーを回避するため、ガード用の環境変数 SKIP_REDIS_CONFIG=true を追加します。
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_REDIS_CONFIG=true ./bin/rails assets:precompile

# =================================================================
# FINAL STAGE: 実行環境 (ビルドツールを削除した軽量環境)
# =================================================================
FROM base

# 【C拡張ランタイム強化 - 重点修正】
# date_core.soエラー（libgmp/libssl依存）とpsych警告（libyaml依存）を解消
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    ffmpeg \
    libyaml-0-2 \
    zlib1g \
    libgmp10 \
    libssl3 \
    libreadline8 \
    libncursesw6 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Build Stageから必要なファイル (Vendor bundleとプリコンパイル済みアセット) のみをコピー
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