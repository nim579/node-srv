module.exports = (grunt)->
    grunt.initConfig
    	coffee:
    		app:
    			options:
    				bare: true

    			files: [
                    expand: true
                    cwd: './'
                    src: ['./!(Gruntfile|grunt)*.coffee']
                    dest: './'
                    ext: '.js'
                    extDot: 'last'
                ]

    grunt.loadNpmTasks 'grunt-contrib-coffee'
