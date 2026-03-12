platform :tvos, '17.0'

project 'OvrCast'

target 'OvrCast' do
  use_frameworks!
  pod 'TVVLCKit', '~> 3.6.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['TVOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end

  # Strip bitcode from TVVLCKit fat framework (Apple rejects bitcode since Xcode 14)
  bitcode_strip = `xcrun -find bitcode_strip`.strip
  Dir.glob("Pods/TVVLCKit/TVVLCKit.framework/TVVLCKit").each do |path|
    system(bitcode_strip, path, "-r", "-o", path)
    puts "Stripped bitcode from #{path}"
  end
end
