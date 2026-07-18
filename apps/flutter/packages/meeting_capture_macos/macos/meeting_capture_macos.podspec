#
# meeting_capture_macos — macOS (ScreenCaptureKit) meeting capture.
# Run `pod lib lint meeting_capture_macos.podspec` on a Mac to validate.
#
Pod::Spec.new do |s|
  s.name             = 'meeting_capture_macos'
  s.version          = '0.1.0'
  s.summary          = 'macOS ScreenCaptureKit implementation of meeting_capture.'
  s.description      = <<-DESC
System audio (SCStream) + default microphone capture encoded to a local M4A.
                       DESC
  s.homepage         = 'https://github.com/matome-app'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'matome' => 'noreply@matome.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  # ScreenCaptureKit system-audio capture requires macOS 12.3+; the meeting
  # feature floor is macOS 15 (task #1280).
  s.platform = :osx, '15.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.frameworks = 'AVFoundation', 'ScreenCaptureKit', 'CoreMedia', 'CoreGraphics'
end
