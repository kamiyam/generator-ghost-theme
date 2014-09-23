'use strict'
module.exports = (grunt) ->

  LIVERELOAD_PORT = 35729

  ###
  Grunt Config
  ###
  gruntConfig = do()->
    config = grunt.file.readJSON("theme.json")
    srcDir = "app"
    devDir = ".tmp/public"

    return {
    name: config.theme
    source:
      path: srcDir
      css: srcDir + config.dir.css
      js: srcDir + config.dir.js
      img: srcDir + config.dir.images
      font: srcDir + config.dir.fonts
    temp:
      path: devDir
      css: devDir + config.dir.css
      js: devDir + config.dir.js
      img: devDir + config.dir.images
      font: devDir + config.dir.fonts
    }


  ###
  Ghost Env Config
  ###
  ghostConfig = do() ->

    ghostRoot = require("path").resolve("../src/")

    configPath = ghostRoot + "/config"

    try
      config = require(configPath)["development"]
    catch e
      config =
        server:
          port: 3000

    return {
      root: ghostRoot
      start: ghostRoot + "/index.js"
      listen: 3000
      port: config.server.port
      theme: ghostRoot + "/content/themes/" + gruntConfig.name
    }

  mountFolder = (connect, dir) ->
    connect.static require("path").resolve(dir)

  proxySnippet = require("grunt-connect-proxy/lib/utils").proxyRequest

  # load all grunt tasks
  require('load-grunt-tasks')(grunt)

  ###
  # Project configuration.
  ###
  grunt.initConfig

    pkg: grunt.file.readJSON("package.json")

    clean:
      grunt:
        src: ".Gruntfile.js"
      theme:
        src: [ghostConfig.theme]
        options:
          force: true
      dev:
        src: [gruntConfig.temp.path]
        options:
          force: true

    sync:
      dev:
        files: [
          expand: true
          cwd: gruntConfig.source.path
          src: [".gitignore","LICENSE","**/*.!(coffee|less|styl|sass|scss|map)"]
          dest: gruntConfig.temp.path
        ],
        verbose: true

#    copy:
#      dev:
#        files: [
#          expand: true
#          cwd: gruntConfig.source.path
#          src: ["**/*.!(coffee|less|styl|sass|scss|map)"]
#          dest: gruntConfig.temp.path
#        ]

    stylus:
      dev:
        options:
          compress: false
        files: [
          {
            expand: true,
            cwd: gruntConfig.source.css
            src: ['**/*.styl']
            dest: gruntConfig.temp.css
            ext: '.css'
          }
        ]

    coffee:
      dev:
        options:
          bare: true
          sourceMap: true

        files: [
          expand: true
          cwd: gruntConfig.source.js
          src: ["**/*.coffee"]
          dest: gruntConfig.temp.js
          ext: ".js"
        ]

    jst:
      options:
        namespace: "JST"
        processName: (filepath) -> # input -> app/hbs/partial.html
          pieces = filepath.split("/");
          return pieces[pieces.length - 1].replace(/.html$/ , '') #output -> partial
      all:
        files:[
          src: [gruntConfig.source.path + "/templates/**/*.html"]
          dest: gruntConfig.temp.path + "/assets/JST.js"
        ]

    connect:
      front:
        options:
          hostname: "localhost"
          port: ghostConfig.listen
          protocol: 'http'
          middleware: (connect) ->
            [
              mountFolder(connect, ".")
              proxySnippet
            ]
          livereload: LIVERELOAD_PORT

  #          open:
  #            target: "http://localhost:" + listen,
  #            appName: "Google Chrome Canary"
  #            callback: ->
  #              return 

      proxies: [{
        context: "/"
        host: "localhost"
        port: ghostConfig.port + ""
        https: false
        changeOrigin: false
      }]

  # watch files settings
    watch:
      options:
        livereload: false
      stylus:
        options:
          cwd: gruntConfig.source.css
        files: [
          "**/*.styl"
        ]
        tasks: ["stylus:dev"]
      coffee:
        options:
          cwd: gruntConfig.source.js
        files: ["**/*.coffee"]
        tasks: ["coffee:dev"]
      static:
        options:
          cwd: gruntConfig.source.path
        files: ["**/*.!(coffee|less|styl|sass|scss|map)"]
        tasks: ["sync:dev"]
      reload:
        options:
          cwd: gruntConfig.temp.path
          nospawn: false
          livereload: true
        files: ["assets/**/*", "**/*.hbs"]

    symlink:
      options:
        overwrite: false
      dev:
        src: gruntConfig.temp.path
        dest: ghostConfig.theme

    external_daemon:
      forever:
        cmd: "forever"
        args: ["-v", "-d", ghostConfig.start, "-w", "./", "--sourceDir ", ghostConfig.root, "--watchIgnore", "!**/*.hbs" ]
        options:
          verbose: true

  init = ->
    themaPath = ghostConfig.theme
    console.log "Create SymbolicLink => " + themaPath
    process.on 'exit', ->
      console.log "Delete SymbolicLink => " + themaPath
      exec = require('child_process').exec
      exec "grunt clean:theme", ->
        process.exit()
    return

  grunt.registerTask "serv", ->
    grunt.task.run [ "compile", "linkAssets", "symlink:dev", "configureProxies", "connect:front", "external_daemon:forever", "watch" ]
    init()

  grunt.registerTask "build", [ "compile", "linkAssets" ]

  grunt.registerTask "compile", [ "clean:dev","stylus:dev", "coffee:dev", "jst" ]

  grunt.registerTask "linkAssets", [ "sync:dev" ]