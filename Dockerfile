# syntax=docker/dockerfile:1

# =================================================================
# BASE STAGE: 基本環境のセットアップ (ステージ 0)
# =================================================================
ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION AS base

# 作業ディレクトリの設定
WORKDIR /rails

# ベース環境のシステム依存パッケージのインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    postgresql-client \
    ffmpeg && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 環境変数の設定 (本番環境用の設定)
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development" \
    PATH="/rails/bin:/usr/local/node/bin:$PATH"

# =================================================================
# BUILD STAGE: アプリケーションのビルドと依存関係のインストール (ステージ 1)
# =================================================================
FROM base AS build 

# -------------------------------------------------------------
# 修正ブロック: Node.js/Yarnのインストールを開発環境の安定方式に統一
# -------------------------------------------------------------
RUN apt-get update -qq && \
    apt-get install -y ca-certificates curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && NODE_MAJOR=20 \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && wget --quiet -O - /tmp/pubkey.gpg https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# ビルドに必要なシステム依存パッケージのインストール (C拡張ビルド用)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential libpq-dev nodejs yarn python-is-python3 zlib1g-dev \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives
# -------------------------------------------------------------

# 1. Gemのインストール
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# 2. JSパッケージのインストール
COPY package.json yarn.lock ./
# 開発環境で成功しているオプションに戻す
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .

# 【重要：Bootsnapキャッシュクリア】
# C拡張のロードエラー（msgpack.soなど）を解決するため、キャッシュを確実に削除
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