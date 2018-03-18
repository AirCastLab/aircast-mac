Pod::Spec.new do |s|

  s.name          = 'aircast'
  s.version       = '1.0.2'
  s.summary       = 'airplay mirroring and airplay casting'
  s.homepage      = 'https://github.com/AirCastLab'
  s.author        = { 'LianXiang Liu' => 'leeoxiang@gmail.com' }
  s.source        = { :git => 'https://github.com/AirCastLab/aircast-mac.git' }
  s.platform      = :osx, '10.9'
  s.vendored_frameworks = 'aircast_sdk_mac.framework'
  s.public_header_files = 'aircast_sdk_mac.framework/Headers/acast_c.h'
end
