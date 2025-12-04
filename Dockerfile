# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ (ステージ 0)
# - すべてのC拡張機能のビルドに必要なシステムライブラリをインストール
# =================================================================
FROM ruby:3.3.0-slim AS base

# 環境変数の設定 (本番環境用の設定)
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development" \
    PATH="/rails/bin:/usr/local/node/bin:$PATH" \
    # タイムゾーン設定
    TZ Asia/Tokyo

# 必要なシステムパッケージのインストール
# date_core.so や psych の問題を解決するため、ビルドに必要なパッケージを追加
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    # Ruby拡張機能のビルドに必要な基本ツール
    build-essential \
    # dateや他のC拡張機能に必要なlibsslやzlib
    libssl-dev \
    zlib1g-dev \
    # psych gem (YAML) の問題を解決するために必要
    libyaml-dev \
    # PostgreSQLクライアント
    libpq-dev \
    # Node/Yarnのセットアップに必要な基本ツール
    ca-certificates curl gnupg dirmngr \
    && rm -rf /var/lib/apt/lists/*
    
# =================================================================
# BUILD STAGE: アプリケーションのビルドと依存関係のインストール (ステージ 1)
# - Node.jsとYarnのインストールをこのステージで完結させる
# =================================================================
FROM base AS build 

# -------------------------------------------------------------
# Node.js/Yarnのインストール (BASEステージでインストールしたツールを使用)
# -------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    NODE_MAJOR=20 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    wget --quiet -O - /tmp/pubkey.gpg https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# nodejsとyarnのインストールとAPTキャッシュの削除
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y nodejs yarn python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# 1. Gemのインストール
COPY Gemfile Gemfile.lock ./
# Bootsnapがないため、これだけでOK
RUN bundle install --jobs 4 --retry 3

# 2. JSパッケージのインストール
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .

# 【重要：キャッシュクリア】
RUN rm -rf tmp/cache

# 【DB接続回避策】ビルドステージで一時的にダミーのdatabase.ymlを使用
COPY database.yml.build config/database.yml 

# 【重要】アセットプリコンパイル
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_REDIS_CONFIG=true ./bin/rails assets:precompile

# =================================================================
# FINAL STAGE: 実行環境 (ステージ 2)
# =================================================================
FROM base 

# Build Stageから必要なファイル (Vendor bundleとプリコンパイル済みアセット) のみをコピー
COPY --from=build /rails /rails
# Node実行バイナリをコピー
COPY --from=build /usr/bin/node /usr/bin/node
# Node環境一式をコピー (必須)
COPY --from=build /usr/local/node /usr/local/node

# 非ルートユーザーの作成と設定
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails

# ENTRYPOINTとCMDの設定
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]