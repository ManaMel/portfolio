# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 修正1: BUNDLE_PATHをローカルのvendorに変更（Render環境で推奨）
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development"

# --------------------------
# Build stage
# --------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev node-gyp pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node
ARG NODE_VERSION=20.19.1
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "$NODE_VERSION" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install gems
COPY Gemfile Gemfile.lock ./
# 修正2: BUNDLE_BINをrailsのbinディレクトリに設定 (実行ファイルのリンク先)
RUN bundle install --jobs 4 --retry 3 --local && \
    bundle binstubs --all --path ./bin

# Install JS packages
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# --------------------------
# Final stage
# --------------------------
FROM base

# Install ffmpeg
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ffmpeg && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy app and node_modules
COPY --from=build /rails /rails
COPY --from=build /usr/local/node /usr/local/node

# Create non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails

# 修正3: Gemの実行ファイルへのパスを$PATHに追加
# BUNDLE_PATHを/rails/vendor/bundleに変更したため、その実行ディレクトリを追加
ENV PATH="/rails/bin:$PATH"

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
# 修正4: CMDをbundle exec形式に変更 (Pumaを想定)
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
