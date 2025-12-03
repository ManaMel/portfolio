# syntax=docker/dockerfile:1

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

# 環境変数の設定
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development" \
    PATH="/rails/bin:/usr/local/node/bin:$PATH"

# --------------------------
# Build stage
# --------------------------
FROM base AS build

# ビルドに必要なシステム依存パッケージのインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev node-gyp pkg-config python-is-python3 && \
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
# BUNDLE_PATHによって/rails/vendor/bundleにインストールされる
RUN bundle install --jobs 4 --retry 3

# 2. JSパッケージのインストール
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# 3. アプリケーションコードのコピー
COPY . .

# --------------------------
# Final stage
# --------------------------
FROM base

# bundlerバージョンを明示的に指定してインストール
RUN gem install bundler -v 2.6.8 --conservative

# ffmpegのインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ffmpeg && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 【修正済み】
# Build Stageでインストールされた /rails/vendor/bundle を削除するステップを削除しました。
# これにより、ネイティブ拡張（.soファイル）が残ります。

# Copy app, Gems, and node_modules from build stage
# COPY --from=build /rails /rails は、/rails/vendor/bundle を含む全てのファイルを持ってきます。
COPY --from=build /rails /rails
COPY --from=build /usr/local/node /usr/local/node

# bundle install --local は不要です。
# COPYの時点で既に依存関係は揃っているため、削除します。

# 非ルートユーザーの作成 (このブロックはそのまま)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails

# ENTRYPOINTとCMDの設定
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
