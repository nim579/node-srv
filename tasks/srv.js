/*
 * grunt-node-srv
 * https://github.com/nim579/grunt-node-srv
 *
 * Copyright (c) 2013 Nick Iv
 * Licensed under the MIT license.
 */

'use strict';

module.exports = function(grunt) {

  // Please see the Grunt documentation for more information regarding task
  // creation: http://gruntjs.com/creating-tasks

    grunt.registerMultiTask('srv', 'Simple server for Grunt.js', function() {
    // Merge task-specific and/or target-specific options with these defaults.
        var done = this.async();

        var _ = require('underscore');

        var options = _.extend({
            port: '8000',
            root: './',
            logs: false,
            '404': null,
            '500': null

        }, this.data);

        var srvClass = require('../server');
        var srv = new srvClass(options, false);

        process.on('SIGINT', function(){
            process.removeAllListeners('SIGINT');
            process.removeAllListeners('SIGTERM');
            srv.stop();
            grunt.log.ok('Server was shutdown at ' + new Date().toJSON());
            done();
        });
        process.on('SIGTERM', function(){
            process.removeAllListeners('SIGINT');
            process.removeAllListeners('SIGTERM');
            srv.stop();
            grunt.log.ok('Server was shutdown at ' + new Date().toJSON());
            done();
        });
    });
};