Node-srv [![](https://badge.fury.io/js/node-srv.png)](https://npmjs.org/package/node-srv)
========
Simple static node.js server. Supports Heroku and Grunt.js

## Install

~~~~~ bash
$ npm install -g node-srv
~~~~~

## Use

~~~~~ bash
# Start server on port 8000
$ node-srv

# Start server on port 8001 with writing logs in file *./nodeserver.log*
$ node-srv --port 8001 --logs ./nodeserver.log
~~~~~

## Use from scripts

~~~~~ js
//Require module
var server = require('node-srv');

// Start server
var nodeSrv = new server({
    port: 5000,
    root: '../www/',
    logs: true
});

//Stop server
nodeSrv.stop();
~~~~~

## Options

- **-r, --root [path]** — Path, for server root-folder (default *./*)
- **-p, --port [number]** — Port on which the server is started (default *8000*, or env PORT)
- **-i, --index [file]** — Sets the index file for opening like default file in directories. For example: for uri */test/*, server open *test/index.html*. Default *index.html*
- **-l, --logs [path/boolean]** — Write logs flag. If you specify a path, it will write to this file (if path is folder, default filename node-srv.log) 
- **--404 [path]** — Path to 404 error page
- **--500 [path]** — Path to 500 error page

## Use like [Grunt.js](http://gruntjs.com/) task

1. Install **node-srv** localy

  ~~~~~ bash
  $ npm install node-srv --save
  ~~~~~

2. Load task into your **Gtuntfile**

  ~~~~~ js
  grunt.loadTasks('node-srv');
  ~~~~~

3. Configure as multitask

  ~~~~~ js
  grunt.initConfig({

    srv: {
      server1: {
        port: 4001,
        '404': './404.html'
        index: 'index.htm'
      },
      server2: {
        port: 4002,
        logs: true
      },
    }

  });
  ~~~~~

4. Run task

  ~~~~~ bash
  $ grunt srv:server2
  ~~~~~

## Use for [Heroku](https://heroku.com)

1. Install **node-srv** localy

  ~~~~~ bash
  $ npm install node-srv --save
  ~~~~~

2. Make [Procfile](https://devcenter.heroku.com/articles/getting-started-with-nodejs#declare-process-types-with-procfile)

  You can use root, logs, 404 500 arguments 

  ~~~~~ bash
  web: node node_modules/node-srv/index --logs --404 404.html
  ~~~~~

3. Deploy to heroku and enjoy!

## Add extensions

You can add extensions for handling some types of files.

~~~~~ js
var srv = require('node-srv');

srv.extendHandlers({
    MD: {
        extnames: ['.md', '.markdown'],                     // list of extnames (in lower case)
        method: function(reqObject, callback){
            var err = null;
            try {
                reqObject.status = 200;                     // set response status
                reqObject.body = 'This is markdown file'    // set response body
                mime = {"Content-Type": 'text/html'}        // set response Content-Type
            } catch (e) {
                err = e;
            }

            callback(err, reqObj);                          // if first argument isnt null, server response error with status `500`, else response your content with your status
        }
    }
});

new srv({port: 8000, logs: true, index: 'README.md'});
~~~~~

### reqObject fields
* `object` **request** — request onject (from Node.js HTTP module)
* `object` **response** — response onject (from Node.js HTTP module)
* `numder` **uid** — unique ID
* `date` **startTime** — request time
* `string` **uri** — request URI (if URI folder, in this string added `index` from options). Example, for URL `http://localhost:8000/some/folders/` — `uri: '/some/folders/index.html`
* `string` **body** — body for response (default empty string)
* `string` **filename** — full path to requested file
