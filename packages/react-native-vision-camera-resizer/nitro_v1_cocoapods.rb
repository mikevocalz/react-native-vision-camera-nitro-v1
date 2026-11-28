# Builds a Nitro V1 library with CocoaPods.
#
# Nitro V1 libraries build Apple targets through the Package.swift that
# nitrogen writes. CocoaPods apps (Expo) still need a pod that compiles the same
# sources, so this mirrors nitrogen's addNitrogenTargets() inside one pod:
#
#   <Module>Cxx          nitrogen/generated/shared/c++ + the library's C++ sources
#   <Module>AppleCxx     nitrogen/generated/apple/<Module>AppleCxx (C++ that Swift imports)
#   <Module>             the library's Swift sources + nitrogen/generated/apple/swift
#   <Module>SwiftBridge  nitrogen/generated/apple/{c++,*.cpp,*.mm} (C++ that includes <Module>-Swift.h)
#
# Swift imports <Module>AppleCxx (and any extra C modules) by name, so the
# helper writes a module map for each into ios/build/nitro-v1-modulemaps and puts
# that directory on the Swift and clang search paths.
#
# Keep this file identical across Nitro V1 libraries.
require "json"
require "fileutils"

module NitroV1CocoaPods
  def self.package_dir_of(name, from)
    script = "process.stdout.write(require('path').dirname(require.resolve(process.argv[1] + '/package.json', { paths: [process.argv[2]] })))"
    dir = `node -e #{script.inspect} #{name.inspect} #{from.inspect}`.strip
    raise "[NitroV1] #{name} is not resolvable from #{from}" if dir.empty? || !File.directory?(dir)
    File.realpath(dir)
  end

  def self.nitro_modules_dir(package_dir)
    package_dir_of("react-native-nitro-modules", package_dir)
  end

  def self.apple_module_name(package_dir)
    JSON.parse(File.read(File.join(package_dir, "nitro.json"))).dig("apple", "moduleName") or
      raise "[NitroV1] #{package_dir}/nitro.json has no apple.moduleName"
  end

  def self.modulemap_root
    root = defined?(Pod::Config) ? Pod::Config.instance.installation_root : nil
    base = root ? File.join(root.to_s, "build") : File.join(Dir.pwd, "build")
    File.join(base, "nitro-v1-modulemaps")
  end

  # Writes `module <name> { umbrella header "<header>" export * }` and returns its directory.
  def self.write_modulemap(name, header: nil, umbrella_dir: nil, requires_cplusplus: true)
    dir = File.join(modulemap_root, name)
    FileUtils.mkdir_p(dir)
    body = +"module #{name} {\n"
    body << "  requires cplusplus\n" if requires_cplusplus
    body << "  umbrella header \"#{header}\"\n" if header
    body << "  umbrella \"#{umbrella_dir}\"\n" if umbrella_dir
    body << "  export *\n}\n"
    path = File.join(dir, "module.modulemap")
    File.write(path, body) unless File.exist?(path) && File.read(path) == body
    dir
  end

  # CocoaPods appends a `<Module>.Swift` submodule for the generated
  # <Module>-Swift.h to a Swift static library's module map. With C++ interop
  # that header only compiles textually after the C++ declarations it uses (the
  # bridge sources include it that way), so building it as a clang module fails
  # in every pod that imports this one. SwiftPM has no such submodule; this
  # phase removes it again once CocoaPods' "Copy generated compatibility header"
  # phase has written the module map.
  def self.drop_swift_submodule_phase
    {
      :name => "[NitroV1] Drop the Swift submodule from the module map",
      :execution_position => :any,
      :input_files => ["${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap"],
      :output_files => ["${DERIVED_FILE_DIR}/nitro-v1-modulemap.stamp"],
      :script => <<~'SH',
        set -e
        MAP="${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap"
        if [ -f "$MAP" ]; then
          /usr/bin/awk -v m="module ${PRODUCT_MODULE_NAME}.Swift {" '$0 == m { skip = 1; next } skip && $0 == "}" { skip = 0; next } !skip' "$MAP" > "$MAP.tmp"
          /bin/mv "$MAP.tmp" "$MAP"
        fi
        /usr/bin/touch "${DERIVED_FILE_DIR}/nitro-v1-modulemap.stamp"
      SH
    }
  end

  # Nitro V1 libraries whose generated headers this one includes: the given
  # ones plus, recursively, the Nitro libraries they list in
  # swiftpmConfig.dependencies. Returns [[npm name, package dir], ...].
  def self.transitive_nitro_dependencies(package_dir, direct)
    seen = {}
    queue = direct.map { |name| [name, package_dir] }
    until queue.empty?
      name, from = queue.shift
      next if seen.key?(name)
      dir = package_dir_of(name, from)
      next unless File.exist?(File.join(dir, "nitro.json"))
      seen[name] = dir
      pkg = JSON.parse(File.read(File.join(dir, "package.json")))
      Array(pkg.dig("swiftpmConfig", "dependencies")).each do |child|
        queue << [child, dir] unless child == "react-native-nitro-modules"
      end
    end
    seen.to_a
  end

  def self.quote(paths)
    paths.map { |p| "\"#{p}\"" }.join(" ")
  end

  # s              the Pod::Spec
  # package_dir    the library root (__dir__ of the podspec)
  # module_name    nitro.json apple.moduleName; must equal s.name
  # swift_sources  Package.swift swiftSources (default ["apple"])
  # cxx_sources    Package.swift cxxSources (default ["cpp"])
  # c_modules      extra clang modules Swift imports: { "Name" => "relative/include/dir" }
  # header_dirs    extra header search dirs, relative to package_dir
  # nitro_dependencies  npm names of Nitro V1 libraries whose specs this one uses
  #                (Package.swift swiftpmConfig.dependencies minus react-native-nitro-modules)
  # swift_flags / cxx_flags / defines  extra build settings
  def self.configure(s, package_dir:, module_name:, swift_sources: ["apple"], cxx_sources: ["cpp"],
                     c_modules: {}, header_dirs: [], nitro_dependencies: [],
                     swift_flags: [], cxx_flags: [], defines: [])
    package_dir = File.realpath(package_dir)
    nitro = nitro_modules_dir(package_dir)
    exists = ->(p) { File.exist?(File.join(package_dir, p)) }
    swift_sources = swift_sources.select(&exists)
    cxx_sources = cxx_sources.select(&exists)
    gen = "nitrogen/generated"
    apple_cxx = "#{gen}/apple/#{module_name}AppleCxx"

    dir_glob = lambda do |path, exts|
      File.directory?(File.join(package_dir, path)) ? "#{path}/**/*.{#{exts}}" : path
    end

    # Only compile units go in source_files. Headers stay in preserve_paths so
    # CocoaPods does not symlink them into Pods/Headers: a header reached through
    # a flattened symlink is not recognized as part of its clang module, and
    # Swift's explicit module build then includes it twice ("redefinition of ...").
    s.source_files = [
      "#{gen}/shared/c++/**/*.cpp",
      "#{apple_cxx}/**/*.cpp",
      "#{gen}/apple/swift/**/*.swift",
      "#{gen}/apple/c++/**/*.cpp",
      "#{gen}/apple/*.{cpp,mm}",
    ] + swift_sources.map { |p| dir_glob.(p, "swift") } +
      cxx_sources.map { |p| dir_glob.(p, "c,cc,cpp,m,mm") }
    s.preserve_paths = ["nitro.json", "Package.swift", "#{gen}/**/*.{h,hpp,modulemap}"] +
      cxx_sources.map { |p| dir_glob.(p, "h,hpp,modulemap") }

    apple_cxx_dir = write_modulemap(
      "#{module_name}AppleCxx",
      header: File.join(package_dir, apple_cxx, "include", "#{module_name}AppleCxx", "#{module_name}AppleCxx.h")
    )
    module_dirs = [apple_cxx_dir]
    c_modules.each do |name, include_dir|
      module_dirs << write_modulemap(name, umbrella_dir: File.join(package_dir, include_dir), requires_cplusplus: false)
    end

    dep_header_dirs = []
    dep_swift_flags = []
    transitive_nitro_dependencies(package_dir, nitro_dependencies).each do |dep, dep_dir|
      dep_module = apple_module_name(dep_dir)
      module_dirs << write_modulemap(
        "#{dep_module}AppleCxx",
        header: File.join(dep_dir, gen, "apple", "#{dep_module}AppleCxx", "include", "#{dep_module}AppleCxx", "#{dep_module}AppleCxx.h")
      )
      dep_header_dirs += [
        File.join(dep_dir, gen, "shared", "c++", "include"),
        File.join(dep_dir, gen, "apple", "#{dep_module}AppleCxx", "include"),
        File.join(dep_dir, gen, "apple", "c++", "include"),
        "${PODS_CONFIGURATION_BUILD_DIR}/#{dep_module}/Swift Compatibility Header",
      ]
      dep_swift_flags << "-Xfrontend -clang-header-expose-module -Xfrontend #{dep_module}=#{dep_module}-Swift.h"
      s.dependency dep_module if nitro_dependencies.include?(dep)
    end

    cxx_header_dirs = cxx_sources.map do |p|
      full = File.join(package_dir, p)
      File.directory?(full) ? full : File.dirname(full)
    end
    header_search = [
      File.join(package_dir, gen, "shared", "c++", "include"),
      File.join(package_dir, apple_cxx, "include"),
      File.join(package_dir, gen, "apple", "c++", "include"),
      File.join(nitro, "cpp", "core", "include"),
      File.join(nitro, "apple", "core", "include"),
      File.join(nitro, "apple", "core", "swift-bridge", "include"),
      File.join(nitro, "include"),
      # <Module>-Swift.h of this pod and of NitroModules (static library pods).
      "$(DERIVED_FILE_DIR)",
      "${PODS_CONFIGURATION_BUILD_DIR}/NitroModules/Swift Compatibility Header",
    ] + cxx_header_dirs + c_modules.values.map { |d| File.join(package_dir, d) } +
      header_dirs.map { |d| File.join(package_dir, d) } + dep_header_dirs + module_dirs
    swift_search = module_dirs + [
      File.join(nitro, "cpp", "core", "include"),
      File.join(nitro, "apple", "core", "include"),
      File.join(nitro, "apple", "core", "swift-bridge", "include"),
      File.join(nitro, "include"),
    ]

    s.pod_target_xcconfig = (s.attributes_hash["pod_target_xcconfig"] || {}).merge(
      "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
      "SWIFT_OBJC_INTEROP_MODE" => "objcxx",
      "DEFINES_MODULE" => "YES",
      "HEADER_SEARCH_PATHS" => "$(inherited) #{quote(header_search)}",
      "SWIFT_INCLUDE_PATHS" => "$(inherited) #{quote(swift_search)}",
      "GCC_PREPROCESSOR_DEFINITIONS" => (["$(inherited)"] + defines).join(" "),
      "OTHER_SWIFT_FLAGS" => ([
        "$(inherited)",
        "-enable-upcoming-feature InternalImportsByDefault",
        "-Xfrontend -clang-header-expose-decls=has-expose-attr-or-stdlib",
        "-Xfrontend -clang-header-expose-module -Xfrontend NitroModules=NitroModules-Swift.h",
      ] + dep_swift_flags + swift_flags).join(" "),
      # The bridge sources include <Module>-Swift.h textually after the C++
      # declarations it uses (Package.swift: -fno-modules).
      "OTHER_CPLUSPLUSFLAGS" => (["$(inherited)", "-fno-modules", "-Wno-nullability-extension"] + cxx_flags).join(" "),
    )
    s.swift_version = "6.0"
    s.script_phases = Array(s.attributes_hash["script_phases"]) + [drop_swift_submodule_phase]
    s.dependency "NitroModules"
  end
end
