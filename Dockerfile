# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ (ステージ 0)
# =================================================================
FROM ruby:3.3.0-slim AS base

# 環境変数の設定 (本番環境用の設定)
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    PATH="/rails/bin:/usr/local/node/bin:$PATH" \
    # タイムゾーン設定
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
    && rm -rf /var/lib/apt/lists/*
    
# =================================================================
# BUILD STAGE: アプリケーションのビルドと依存関係のインストール (ステージ 1)
# =================================================================
FROM base AS build 

# 【重要：作業ディレクトリの明示的な設定とクリーンアップ】
WORKDIR /rails
RUN rm -rf ./*

# -------------------------------------------------------------
# Node.js/Yarnのインストール (APT方式は維持)
# -------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    NODE_MAJOR=20 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    wget --quiet -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# nodejsとyarnのインストールとAPTキャッシュの削除
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y nodejs yarn python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# 1. Gemのインストール
COPY Gemfile Gemfile.lock ./
RUN gem install bundler --version "~> 2.6" --no-document
RUN bundle install --jobs 4 --retry 3
# ★★★ 修正: bundle clean --force を削除 ★★★

# 2. JSパッケージのインストール
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .
RUN chmod +x bin/rails
RUN rm -rf tmp/cache

# 【DB接続回避策】ダミーファイルをコピー
COPY database.yml.build config/database.yml 

# 共有ライブラリのパスを更新し、C拡張が正しくリンクされることを保証
RUN ldconfig

# 【重要】アセットプリコンパイル
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_REDIS_CONFIG=true ./bin/rails assets:precompile

# =================================================================
# FINAL STAGE: 実行環境 (ステージ 2) 
# =================================================================
FROM base

# 【重要】ビルドツールを削除してイメージを軽量化
RUN apt-get purge -y --auto-remove \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libyaml-dev \
    libffi-dev \
    wget \
    gnupg \
    dirmngr \
    procps \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 最終ステージで Gem (BUNDLE_PATH) とアプリケーションコードをコピー
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# 非ルートユーザーの作成と設定
ARG USER_UID=1000
ARG GROUP_UID=1000
RUN groupadd --system --gid ${GROUP_UID} rails && \
    useradd rails --uid ${USER_UID} --gid ${GROUP_UID} --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails

# ENTRYPOINTとCMDの設定
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]