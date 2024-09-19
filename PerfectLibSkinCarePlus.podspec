Pod::Spec.new do |s|
  s.name             = 'PerfectLibSkinCarePlus'
  s.version          = '1.0.0'
  s.summary          = 'A short description of the pod'
  s.description      = 'A longer description of the pod.'
  s.homepage         = 'https://github.com/Sahilkathir/PerfectLibSkinCarePlus'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'AuthorName' => 'author@example.com' }
  s.source           = { :git => 'https://github.com/Sahilkathir/PerfectLibSkinCarePlus.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'

  s.source_files     = 'Sources/**/*.{h,m,swift}'  # Adjust based on your source file structure
  s.public_header_files = 'Sources/**/*.h'  # If using Objective-C
  s.frameworks       = 'UIKit', 'Foundation'  # Add necessary frameworks
  s.requires_arc     = true  # If using ARC

  # Include any dependencies
  # s.dependency 'SomeOtherPod'
end
