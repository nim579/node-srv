module.exports = (grunt)->

    grunt.initConfig
        coffee:
            app:
                options:
                    bare: true

                files: [
                    expand: true
                    cwd: './src/'
                    src: ['**/*.coffee']
                    dest: './lib/'
                    ext: '.js'
                ]

    grunt.loadNpmTasks 'grunt-contrib-coffee'
