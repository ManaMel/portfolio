#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
RAILS_ENV=production bundle exec rake assets:precompile
bundle exec rails assets:clean
bundle exec rake db:migrate
