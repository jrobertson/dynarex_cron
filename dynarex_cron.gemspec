Gem::Specification.new do |s|
  s.name = 'dynarex_cron'
  s.version = '0.1.1'
  s.summary = 'dynarex_cron'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('dynarex')
  s.add_dependency('run_every')
  s.add_dependency('chronic_cron')
  s.signing_key = '../privatekeys/dynarex_cron.pem'
  s.cert_chain  = ['gem-public_cert.pem']  
end
