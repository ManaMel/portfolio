# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ (ステージ 0)
# =================================================================
FROM ruby:3.3.0-slim AS base

# ... (ENV設定は省略)
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development" \
    PATH="/rails/bin:/usr/local/node/bin:$PATH" \
    # タイムゾーン設定
    TZ=Asia/Tokyo

# 必要なシステムパッケージのインストール (前回修正済み)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libyaml-dev \
    libpq-dev \
    ca-certificates curl gnupg dirmngr wget \
    && rm -rf /var/lib/apt/lists/*
    
# =================================================================
# BUILD STAGE: アプリケーションのビルドと依存関係のインストール (ステージ 1)
# =================================================================
FROM base AS build 

# 【重要：作業ディレクトリの明示的な設定とクリーンアップ】
WORKDIR /rails
# 作業ディレクトリを明示的にクリーンアップ（問題のある bin ファイルなどが残っていないか確認）
RUN rm -rf ./*
# -------------------------------------------------------------
# Node.js/Yarnのインストール
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
RUN bundle install --jobs 4 --retry 3

# 2. JSパッケージのインストール
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .

# ... (以降のステップは同じ)