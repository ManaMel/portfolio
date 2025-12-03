# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ
# =================================================================
ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION-slim AS base

# 作業ディレクトリの設定
WORKDIR /rails

# ベース環境のシステム依存パッケージのインストール
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
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .

# 【DB接続回避策】ビルドステージで一時的にダミーのdatabase.ymlを使用
COPY database.yml.build config/database.yml 

# 【重要】アセットプリコンパイル
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_REDIS_CONFIG=true ./bin/rails assets:precompile

# =================================================================
# FINAL STAGE: 実行環境 (ビルドツールを削除した軽量環境)
# =================================================================
FROM base

# 【C拡張ランタイム強化 - 最終強化版】
# date_core.so、psych、その他のC拡張機能のロードエラーを解決するために必要な、
# すべての重要なランタイムライブラリを網羅します。
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    ffmpeg \
    # YAML/Psych
    libyaml-0-2 \
    # date_core.so / BigDecimal / OpenSSL
    zlib1g \
    libgmp10 \
    libssl3 \
    libffi8 \
    # ターミナル操作系（なくても動くことが多いが、念のため）
    libreadline8 \
    libncursesw6 \
    libgdbm6 \
    # データベース、XML関連のGem依存
    libpq5 \
    libxml2 \
    libxslt1.1 \
    libsqlite3-0 && \
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