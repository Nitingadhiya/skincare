Pod::Spec.new do |s|
  s.name             = 'PerfectLibSkinCarePlus'
  s.version          = '1.0.0'
  s.summary          = 'A short description of the pod.'
  s.description      = 'A longer description of the pod.'
  s.homepage         = 'https://example.com'  # Replace with an actual URL if needed
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'YourName' => 'your.email@example.com' }
  s.source           = { :git => 'https://github.com/YourRepo.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'

  s.source_files     = 'Frameworks/**/*'  # Adjust based on where your files are located
  s.frameworks       = 'UIKit', 'Foundation'  # Add any required frameworks
  s.requires_arc     = true  # If using ARC
end
