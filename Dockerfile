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
# 修正点: FROM base を FROM 0 に変更し、最初のステージを確実な番号で参照します。
FROM 0 AS build 

# ビルドに必要なシステム依存パッケージのインストール (C拡張ビルド用)
# 標準イメージをベースにしたため、依存を最小化
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev node-gyp pkg-config python-is-python3 \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node.jsとYarnのインストール
ARG NODE_VERSION=20.19.1
ARG YARN_VERSION=1.22.22
ENV PATH="/rails/bin:/usr/local/node/bin:$PATH"
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    nodejs \
    yarn && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 1. Gemのインストール
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# 2. JSパッケージのインストール
COPY package.json yarn.lock ./
# 修正点: --frozen-lockfile を --immutable に変更 (前回の修正を反映)
RUN yarn install --immutable

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
# 修正点: FROM base を FROM 0 に変更し、最初のステージを確実な番号で参照します。
FROM 0 

# C拡張ランタイム強化ブロックは、標準イメージへの変更により削除されました。

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