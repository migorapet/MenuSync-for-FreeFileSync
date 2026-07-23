#!/usr/bin/env ruby

require "xcodeproj"

root = File.expand_path("..", __dir__)
project_path = File.join(root, "MenuSyncForFreeFileSync.xcodeproj")
project = Xcodeproj::Project.new(project_path)

project.root_object.attributes["LastSwiftUpdateCheck"] = "2660"
project.root_object.attributes["LastUpgradeCheck"] = "2660"

app = project.new_target(
  :application,
  "MenuSyncForFreeFileSync",
  :osx,
  "14.0"
)

tests = project.new_target(
  :unit_test_bundle,
  "MenuSyncForFreeFileSyncTests",
  :osx,
  "14.0"
)
tests.add_dependency(app)

app_group = project.main_group.new_group(
  "MenuSyncForFreeFileSync",
  "MenuSyncForFreeFileSync"
)

Dir.glob(File.join(root, "MenuSyncForFreeFileSync", "**", "*.swift")).sort.each do |path|
  relative = path.delete_prefix("#{root}/MenuSyncForFreeFileSync/")
  components = relative.split("/")
  filename = components.pop
  group = components.inject(app_group) do |parent, component|
    parent.groups.find { |candidate| candidate.display_name == component } ||
      parent.new_group(component, component)
  end
  reference = group.new_file(filename)
  app.source_build_phase.add_file_reference(reference)
end

resources_group = app_group.new_group("Resources", "Resources")
Dir.glob(File.join(root, "MenuSyncForFreeFileSync", "Resources", "*.xcassets")).sort.each do |path|
  reference = resources_group.new_file(File.basename(path))
  app.resources_build_phase.add_file_reference(reference)
end

test_group = project.main_group.new_group(
  "MenuSyncForFreeFileSyncTests",
  "MenuSyncForFreeFileSyncTests"
)

Dir.glob(File.join(root, "MenuSyncForFreeFileSyncTests", "**", "*.swift")).sort.each do |path|
  reference = test_group.new_file(File.basename(path))
  tests.source_build_phase.add_file_reference(reference)
end

app.build_configurations.each do |configuration|
  configuration.build_settings.merge!(
    "CLANG_ENABLE_MODULES" => "YES",
    "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
    "CODE_SIGN_STYLE" => "Automatic",
    "COMBINE_HIDPI_IMAGES" => "YES",
    "CURRENT_PROJECT_VERSION" => "1",
    "DEAD_CODE_STRIPPING" => "YES",
    "ENABLE_APP_SANDBOX" => "NO",
    "ENABLE_HARDENED_RUNTIME" => "YES",
    "GENERATE_INFOPLIST_FILE" => "YES",
    "INFOPLIST_KEY_CFBundleDisplayName" => "MenuSync for FreeFileSync",
    "INFOPLIST_KEY_LSApplicationCategoryType" => "public.app-category.utilities",
    "INFOPLIST_KEY_LSUIElement" => "YES",
    "MACOSX_DEPLOYMENT_TARGET" => "14.0",
    "MARKETING_VERSION" => "0.1.0",
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.migorapet.MenuSyncForFreeFileSync",
    "PRODUCT_NAME" => "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS" => "YES",
    "SWIFT_VERSION" => "6.0"
  )
end

tests.build_configurations.each do |configuration|
  configuration.build_settings.merge!(
    "BUNDLE_LOADER" => "$(TEST_HOST)",
    "CODE_SIGN_STYLE" => "Automatic",
    "GENERATE_INFOPLIST_FILE" => "YES",
    "MACOSX_DEPLOYMENT_TARGET" => "14.0",
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.migorapet.MenuSyncForFreeFileSyncTests",
    "SWIFT_VERSION" => "6.0",
    "TEST_HOST" => "$(BUILT_PRODUCTS_DIR)/MenuSyncForFreeFileSync.app/Contents/MacOS/MenuSyncForFreeFileSync"
  )
end

project.build_configurations.each do |configuration|
  configuration.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.add_test_target(tests)
scheme.save_as(project_path, "MenuSyncForFreeFileSync", true)
