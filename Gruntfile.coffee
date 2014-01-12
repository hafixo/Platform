##
## Copyright © 2013 Spectrum IT Solutions Gmbh
##
## Firmensitz: Wien
## Firmenbuchgericht: Handelsgericht Wien
## Firmenbuchnummer: 393588g
##
## All Rights Reserved.
##
## The use and / or modification of this file is subject to
## Spectrum IT Solutions GmbH and may not be made without the explicit
## permission of Spectrum IT Solutions GmbH
##
srcDir = "src/"
fs = require "fs"

config = JSON.parse fs.readFileSync "./#{srcDir}config.json.base"

module.exports = (grunt) ->

  # To build the site, we must do a few things
  # First, we build our modules to a modules folder inside of our build
  # directory. At this point, we copy the package.json files to the build folder
  # as well.
  #
  # The models have to be built as well, but they are built as they are, no
  # facy stuff.
  #
  # Once the models have been built, we turn our attention to the static files.
  # We need to copy over the static folder, then build our stylus files into
  # a single style.css. Followed by this comes our client scripts. They are
  # built as they are during development but concated in production.

  # Deployment paths
  devDir = config.buildDirs.development
  stagingDir = config.buildDirs.staging
  productionDir = config.buildDirs.production
  testingDir = config.buildDirs.testing

  # Initial build directory (by default, development)
  _buildDir = devDir

  # Config file generation
  genConfig = (mode) ->
    config.mode = mode
    fs.writeFileSync "#{__dirname}/#{srcDir}config.json", JSON.stringify config

  # Generate default config
  genConfig "development"

  # Source paths relative to src/
  modelSrc = [ "models/*.coffee" ]
  moduleSrc = [
    "*.coffee"
    "modules/**/*.coffee"
    "helpers/*.coffee"
    "tests/*.coffee"
    "tests/**/*.coffee"
  ]
  clientSrc = [
    "client/*.coffee"
    "client/**/*.coffee"
  ]
  stylusSrc = [
    "stylus/*.styl"
    "stylus/**/*.styl"
  ]
  jadeSrc = [
    "views/*.jade"
    "views/**/*.jade"
  ]

  stylusMin = {}
  clientProdSrc = {}

  # Module package.json paths
  modulePackageJSON = [
    "*.json"
    "modules/**/*.json"
  ]

  _prodSrc = []
  _prodSrc.push "#{srcDir}#{s}" for s in clientSrc

  # Watch doesn't work properly with cwd, so tag on src path manually
  _watchify = (paths) ->
    ret = []
    ret.push "#{srcDir}#{p}" for p in paths
    ret

  # Filled in by buildPaths()
  WmodelSrc = []
  WmoduleSrc = []
  WclientSrc = []
  WstylusSrc = []
  WjadeSrc = []
  WmodulePackageJSON = []

  # Build fresh paths with our current build target
  buildPaths = ->

    stylusMin = {}
    stylusMin["#{_buildDir}static/css/styles.css"] = "#{srcDir}stylus/styles.styl"

    clientProdSrc = {}
    clientProdSrc["#{_buildDir}static/client/app.min.js"] = _prodSrc

    # Create watch versions of each src array
    WmodelSrc = _watchify modelSrc
    WmoduleSrc = _watchify moduleSrc
    WclientSrc = _watchify clientSrc
    WstylusSrc = _watchify stylusSrc
    WjadeSrc = _watchify jadeSrc
    WmodulePackageJSON = _watchify modulePackageJSON

  # Set build paths as needed according to task
  if process.argv[2] == "deploy"
    _buildDir = productionDir
  else if process.argv[2] == "stage"
    _buildDir = stagingDir
  else if process.argv[2] == "deployTest"
    _buildDir = testingDir

  # Execute here, with default build path
  buildPaths()

  grunt.initConfig
    pkg: grunt.file.readJSON "package.json"

    # Proper source files (client and server-side logic)
    coffee:

      # Server-side modules, build as they are (1 to 1)
      modules:
        expand: true
        options:
          bare: true
        ext: ".js"
        cwd: srcDir
        dest: _buildDir
        src: moduleSrc

      # Database models, again build as they are
      models:
        expand: true
        options:
          bare: true
        ext: ".js"
        cwd: srcDir
        dest: _buildDir
        src: modelSrc

      # Dev client settings, build files as they are
      client_dev:
        expand: true
        options:
          bare: true
        ext: ".js"
        cwd: srcDir
        dest: "#{_buildDir}static"
        src: clientSrc

      # Production client settings, concat all files
      client_prod:
        expand: true
        options:
          bare: true
        files: clientProdSrc

    # Stylesheets
    stylus:
      full:
        files: stylusMin

    copy:

      # Copy module package.json files
      packageJSON:
        files: [
          expand:true
          src: modulePackageJSON
          cwd: srcDir
          dest: _buildDir
        ]

      # True static files (images, fonts, etc)
      static:
        files: [
          expand: true
          cwd: "#{srcDir}/static"
          src: "**"
          dest: "#{_buildDir}/static"
        ]

      # Jade templates
      jade:
        files: [
          expand: true
          cwd: srcDir
          src: jadeSrc
          dest: _buildDir
        ]

      ssl:
        files: [
          expand: true
          cwd: "#{srcDir}/ssl"
          src: "**"
          dest: "#{_buildDir}/ssl"
        ]

      templateAssets:
        files: [
          expand: true
          cwd: "#{srcDir}/modules/engine/engine-templates/templates"
          src: "*/*"
          dest: "#{_buildDir}/modules/engine/engine-templates/templates"
        ]

    # CSS Minifier
    cssmin:
      minify:
        expand: true
        cwd: "#{_buildDir}/static/css/"
        src: ["*.css", "!*.min.css", "**/*.css", "!**/*.min.css"]
        dest: "#{_buildDir}/static/css"
        ext: ".min.css"

    # Node server, restarts when it detects changes
    nodemon:
      dev:
        options:
          file: "#{_buildDir}adefy.js"
          watchedExtensions: [ ".js" ]
          watchedFolders: [ _buildDir ]

    # Our dev task, combines watch with nodemon (sexy!)
    concurrent:
      dev: [ "watch", "nodemon:dev" ]
      options:
        logConcurrentOutput: true

    clean: [
      _buildDir
    ]

    mochaTest:
      test:
        options:
          reporter: "spec"
          require: "coffee-script"
        src: [
          "#{srcDir}/tests/*.coffee"
        ]
      selfTest:
        options:
          reporter: "spec"
        src: [
          "#{_buildDir}/tests/selftest.js"
        ]

    # Watch files for changes and ship updates to build folder
    watch:
      serverCS:
        files: WmoduleSrc
        tasks: [ "coffee:modules" ]
      models:
        files: WmodelSrc
        tasks: [ "coffee:models" ]
      clientCS:
        files: WclientSrc
        tasks: [ "coffee:client_dev" ]
      stylus:
        files: WstylusSrc
        tasks: [ "stylus:full" ]
      packageJSON:
        files: WmodulePackageJSON
        tasks: [ "copy:packageJSON" ]
      static:
        files: [ "#{srcDir}static/**" ]
        tasks: [ "copy:static" ]
      jade:
        files: WjadeSrc
        tasks: [ "copy:jade" ]

  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-stylus"
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-contrib-copy"
  grunt.loadNpmTasks "grunt-contrib-clean"
  grunt.loadNpmTasks "grunt-contrib-cssmin"
  grunt.loadNpmTasks "grunt-concurrent"
  grunt.loadNpmTasks "grunt-nodemon"
  grunt.loadNpmTasks "grunt-mocha-test"

  # Perform a full build
  grunt.registerTask "persistentFull", [
    "copy:packageJSON"
    "copy:static"
    "copy:jade"
    "copy:ssl"
    "copy:templateAssets"
    "coffee:modules"
    "coffee:models"
    "coffee:client_dev"
    "coffee:client_prod"
    "stylus:full"
    "cssmin:minify"
  ]
  grunt.registerTask "full", [
    "clean"
    "persistentFull"
  ]

  grunt.registerTask "test", ["mochaTest:test"]

  grunt.registerTask "default", [ "full" ]
  grunt.registerTask "dev", [ "concurrent:dev" ]

  # Generate a production config file, then build to the production folder
  grunt.registerTask "deploy", "Build to production folder", ->

    genConfig "production"
    _buildDir = productionDir
    buildPaths()
    grunt.task.run "persistentFull"

  # Generate a staging config file, then build to the staging folder
  grunt.registerTask "stage", "Build to staging folder", ->

    genConfig "staging"
    _buildDir = stagingDir
    buildPaths()
    grunt.task.run "persistentFull"

  # Generates a test config file, builds to testing, and runs our unit tests
  # This is used server-side to verify deployment
  grunt.registerTask "deployTest", "Build for testing, and test", ->

    genConfig "testing"
    _buildDir = testingDir
    buildPaths()
    grunt.task.run "full"
    grunt.task.run "mochaTest:selfTest"
