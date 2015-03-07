Gem::Specification.new do |s|
  s.name = 'dynarex_cron'
  s.version = '0.6.1'
  s.summary = 'dynarex_cron'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('chronic_cron', '~> 0.2', '>=0.2.33')
  s.add_runtime_dependency('dynarex', '~> 1.2', '>=1.2.90')
  s.add_runtime_dependency('sps-pub', '~> 0.4', '>=0.4.0')  
  s.add_runtime_dependency('run_every', '~> 0.1', '>=0.1.9')    
  s.signing_key = '../privatekeys/dynarex_cron.pem'
  s.cert_chain  = ['gem-public_cert.pem']  
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/dynarex_cron'
  s.required_ruby_version = '>= 2.1.2'
end
