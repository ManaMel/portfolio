# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ (ステージ 0)
# =================================================================
FROM ruby:3.3.0-slim AS base

# 環境変数の設定 (本番環境用の設定)
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development" \
    PATH="/rails/bin:/usr/local/node/bin:$PATH" \
    TZ=Asia/Tokyo

# 必要なシステムパッケージのインストール
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libyaml-dev \
    libpq-dev \
    libffi-dev \
    ca-certificates curl gnupg dirmngr wget \
    tzdata \
    procps \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*
    
# =================================================================
# BUILD STAGE: アプリケーションのビルドと依存関係のインストール (ステージ 1)
# =================================================================
FROM base AS build 

WORKDIR /rails
RUN rm -rf ./*

# Node.js/Yarnのインストール
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    NODE_MAJOR=20 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    wget --quiet -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y nodejs yarn python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# Gemのインストール
COPY Gemfile Gemfile.lock ./
RUN gem install bundler --version "~> 2.6" --no-document
RUN bundle install --jobs 4 --retry 3

# JSパッケージのインストール
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# アプリケーションコードのコピー
COPY . .
COPY bin/docker-entrypoint ./bin/docker-entrypoint
RUN chmod +x bin/rails bin/docker-entrypoint
RUN rm -rf tmp/cache

# DB接続回避策
COPY database.yml.build config/database.yml 

# CSS/JSのビルド
RUN yarn build && yarn build:css

# アセットプリコンパイル(シンプル版)
RUN bundle exec rake assets:precompile RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_REDIS_CONFIG=true

# =================================================================
# FINAL STAGE: 実行環境 (ステージ 2) 
# =================================================================
FROM base

# 【重要】ランタイムに必要なライブラリは残す
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    libpq5 \
    libyaml-0-2 \
    libssl3 \
    zlib1g \
    libffi8 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# 【重要】ビルドツールのみ削除(ランタイムライブラリは保持)
RUN apt-get purge -y --auto-remove \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libyaml-dev \
    libpq-dev \
    libffi-dev \
    wget \
    gnupg \
    dirmngr \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* || true

# Gemとアプリケーションコードをコピー
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# 非ルートユーザーの作成
ARG USER_UID=1000
ARG GROUP_UID=1000
RUN groupadd --system --gid ${GROUP_UID} rails && \
    useradd rails --uid ${USER_UID} --gid ${GROUP_UID} --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails

WORKDIR /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]