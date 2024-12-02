Pod::Spec.new do |s|
  s.name             = 'PerfectLibSkinCarePlus'
  s.version          = '1.0.0'
  s.summary          = 'Core module for PerfectLib'
  s.homepage         = 'https://github.com/Sahilkathir/PerfectLibCore'
   # Required attribute - Authors
    s.authors          = { 'Sahil Kathiriya' => 'your.email@example.com' }

    # Required attribute - License
    s.license          = { :type => 'MIT', :text => 'LICENSE' }  # Or whatever license type you are using

  s.source           = { :git => 'https://github.com/Sahilkathir/PerfectLibCore.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'
  s.source_files     = 'PerfectLibCore/**/*.{h,swift}'
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
end
