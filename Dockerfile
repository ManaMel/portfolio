# syntax=docker/dockerfile:1

# ... [BASE STAGEは省略] ...

# =================================================================
# BUILD STAGE: アプリケーションのビルドと依存関係のインストール
# =================================================================
FROM base AS build

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
# FINAL STAGE: 実行環境 (非常に安定した環境)
# =================================================================
FROM base

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