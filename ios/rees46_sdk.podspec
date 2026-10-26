#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'rees46_sdk'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin wrapper around REES46 native SDK.'
  s.description      = <<-DESC
Flutter plugin wrapper around REES46 native SDK.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'REES46' => 'support@rees46.com' }
  s.source           = { :path => '.' }
  # The sources live where Swift Package Manager expects them (rees46_sdk/Package.swift);
  # CocoaPods builds the same files.
  s.source_files = 'rees46_sdk/Sources/rees46_sdk/**/*.swift'
  s.resource_bundles = {'rees46_sdk_privacy' => ['rees46_sdk/Sources/rees46_sdk/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  # Keep in step with the dependency in rees46_sdk/Package.swift. CocoaPods trunk is
  # read-only, so a version newer than the last one there resolves only through the
  # app's Podfile (see "iOS" in README.md).
  s.dependency 'REES46', '3.35.0'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end

