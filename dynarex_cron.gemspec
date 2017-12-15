Gem::Specification.new do |s|
  s.name = 'dynarex_cron'
  s.version = '0.9.3'
  s.summary = 'Publishes SimplePubSub messages by reading cron ' + 
      'entries from a Dynarex document'
  s.authors = ['James Robertson']
  s.files = Dir['lib/dynarex_cron.rb']
  s.add_runtime_dependency('chronic_cron', '~> 0.3', '>=0.3.7')
  s.add_runtime_dependency('dynarex', '~> 1.7', '>=1.7.27')
  s.add_runtime_dependency('sps-pub', '~> 0.5', '>=0.5.5')  
  s.signing_key = '../privatekeys/dynarex_cron.pem'
  s.cert_chain  = ['gem-public_cert.pem']  
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/dynarex_cron'
  s.required_ruby_version = '>= 2.1.2'
end
