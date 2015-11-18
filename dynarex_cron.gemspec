Gem::Specification.new do |s|
  s.name = 'dynarex_cron'
  s.version = '0.8.2'
  s.summary = 'Publishes SimplePubSub messages by reading cron entries from a Dynarex document'
  s.authors = ['James Robertson']
  s.files = Dir['lib/dynarex_cron.rb']
  s.add_runtime_dependency('chronic_cron', '~> 0.3', '>=0.3.1')
  s.add_runtime_dependency('dynarex', '~> 1.5', '>=1.5.26')
  s.add_runtime_dependency('sps-sub-ping', '~> 0.1', '>=0.1.0')  
  s.signing_key = '../privatekeys/dynarex_cron.pem'
  s.cert_chain  = ['gem-public_cert.pem']  
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/dynarex_cron'
  s.required_ruby_version = '>= 2.1.2'
end
