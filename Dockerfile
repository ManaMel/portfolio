# Dockerfileの修正後の内容
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

# 修正1: BUNDLE_PATHをローカルのvendorに変更（Render環境で必須）
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/rails/vendor/bundle" \
    BUNDLE_WITHOUT="development"

# --------------------------
# Build stage
# --------------------------
FROM base AS build
# ... (apt-get install はそのまま) ...
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev node-gyp pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node (このブロックはそのまま)
ARG NODE_VERSION=20.19.1
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "$NODE_VERSION" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install gems
COPY Gemfile Gemfile.lock ./
# 修正2: binstubsで実行ファイルを./binに作成
RUN bundle install --jobs 4 --retry 3 && \
    bundle binstubs --all --path ./bin

# ... (JS packages, Copy application, Precompile assets はそのまま) ...
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .

# --------------------------
# Final stage
# --------------------------
FROM base

# Install ffmpeg (このブロックはそのまま残す)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ffmpeg && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN rm -rf /rails/vendor/bundle

# Copy app and node_modules (このブロックはそのまま)
COPY --from=build /rails /rails
COPY --from=build /usr/local/node /usr/local/node

RUN bundle install --local --jobs 4 --retry 3

# Create non-root user (このブロックはそのまま)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails

# 修正3: Gemの実行ファイルへのパスを$PATHに追加 (sidekiq not found回避)
ENV PATH="/rails/bin:/usr/local/node/bin:$PATH"

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
# 修正4: CMDを標準のPuma起動コマンドに変更
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
