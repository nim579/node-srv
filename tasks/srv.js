/*
 * Grunt.js task "node-srv"
 * https://github.com/nim579/node-srv
 *
 * Copyright (c) 2014 Nick Iv
 * Licensed under the MIT license.
 */

'use strict';

module.exports = function(grunt) {
    grunt.registerMultiTask('srv', 'Simple server for Grunt.js', function() {
        var done = this.async();

        var _ = require('underscore');

        var options = _.extend({
            port: '8000',
            root: './',
            index: 'index.html',
            logs: false,
            '404': null,
            keepalive: true
        }, this.data);

        var Server = require('../lib/server');

        var srv = new Server(options, function(){
            grunt.log.ok('Server was shutdown at ' + new Date().toJSON());
        });

        var host = 'localhost';
        if(options.host && options.host != '0.0.0.0'){
            host = options.host;
        }

        grunt.log.ok("node-srv server running at\n => http://" + host +":" + options.port + "/\n");

        if(!options.keepalive){
            done();
        }
    });
};
