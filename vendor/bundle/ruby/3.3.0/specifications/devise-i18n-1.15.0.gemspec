# -*- encoding: utf-8 -*-
# stub: devise-i18n 1.15.0 ruby lib

Gem::Specification.new do |s|
  s.name = "devise-i18n".freeze
  s.version = "1.15.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/devise-i18n/devise-i18n/blob/master/CHANGELOG.md" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Christopher Dell".freeze, "mcasimir".freeze, "Jason Barnabe".freeze]
  s.date = "2023-10-04"
  s.description = "Translations for the devise gem".freeze
  s.email = "jason.barnabe@gmail.com".freeze
  s.extra_rdoc_files = ["LICENSE.txt".freeze, "README.md".freeze]
  s.files = ["LICENSE.txt".freeze, "README.md".freeze]
  s.homepage = "https://github.com/devise-i18n/devise-i18n".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0".freeze)
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Translations for the devise gem".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<devise>.freeze, [">= 4.9.0".freeze])
  s.add_runtime_dependency(%q<rails-i18n>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 2.8.0".freeze])
  s.add_development_dependency(%q<rspec-rails>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<railties>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<activemodel>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<omniauth-twitter>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<appraisal>.freeze, [">= 0".freeze])
end
