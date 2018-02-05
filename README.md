# Node-srv [![](https://badge.fury.io/js/node-srv.png)](https://npmjs.org/package/node-srv)
Simple static node.js server. Supports Heroku and Grunt.js

## Install

``` bash
$ npm install -g node-srv
```

## Usage

``` bash
# Start server on port 8000
$ node-srv

# Start server on port 8001 writing logs to *./nodeserver.log* file
$ node-srv --port 8001 --logs ./nodeserver.log
```

## Scripts usage

``` js
//Require module
var server = require('node-srv');

// Start server
var srv = new Server({
    port: 5000,
    root: '../www/',
    logs: true
}, function(){
    console.log('Server stopped');
});

//Stop server
srv.stop();
```

## Options

* **-r, --root [path]** — Path, for server root-folder (default *./*)
* **-p, --port [number]** — Port the server is started on (default *8000*, or env PORT)
* **-h, --host [host]** — Host or ip address on which the server will work (any host by default)
* **-i, --index [file]** — Sets default index file for directories. For example: for uri */test/*, server open *test/index.html*. Default *index.html*
* **-l, --logs [path/boolean]** — Write logs flag. If you specify a path, it will write to that file (if path is folder, default filename will be node-srv.log)
* **--404 [path]** — Path to 404 error page

## Usage as [Grunt.js](http://gruntjs.com/) task
1. Install **node-srv** locally

  ``` bash
  $ npm install node-srv --save
  ```

2. Load task into your **Gruntfile**

  ``` js
  grunt.loadTasks('node-srv');
  ```

3. Configure as multitask

  ``` js
  grunt.initConfig({
      srv: {
          server1: {
              port: 4001,
              '404': './404.html'
              index: 'index.htm',
              keepalive: false
          },
          server2: {
              port: 4002,
              logs: true
          },
      }
  });
  ```

4. Run task

  ``` bash
  $ grunt srv:server2
  ```

## Usage with [Heroku](https://heroku.com)

1. Install **node-srv** localy

  ``` bash
  $ npm install node-srv --save
  ```

2. Make [Procfile](https://devcenter.heroku.com/articles/getting-started-with-nodejs#define-a-procfile)

  You can use root, logs, 404 arguments

  ```
  web: node node_modules/node-srv/ --logs --404 404.html
  ```

3. Deploy to heroku and enjoy!

## Extending server
You can extend server class.

``` js
const Server = require('node-srv');

class MyServer extends Server {
    log(string) {
        console.log(string);
    }
}
```

## Handlers

You can add custom handlres specific path patterns (like [minimatch](https://www.npmjs.com/package/minimatch)).

``` js
const Server = require('node-srv');

class MyServer extends Server {}
    handlers() { // or object
        return {
            ".(md|markdown)": function(response, filePath){
                return this.handlerMarkdown(response, filePath);
            }
            "/static/fake": function(response, filePath){
                response.writeHead(204, server.getHeaders());
                response.write('');
                response.end();

                return 204
            }
            "/static/**/*": function(response, filePath){
                return this.handlerStaticFile(response, filePath);
            }
        }
    }

    handlerMarkdown(response, filePath, method, headers) {
        let server = this;

        return new Promise(function(resolve, reject){
            if(method === 'HEAD'){
                headers = server.getHeaders();
                headers['Content-Type'] = 'text/html';

                response.writeHead(200, headers);
                response.end();

                resolve(200);
            } else if(method === 'GET') {
                markdown.renderFile(filePath, function(err, html){
                    if(err) return reject(err);

                    headers = server.getHeaders();
                    headers['Content-Type'] = 'text/html';

                    response.writeHead(200, headers);
                    response.write(html);
                    response.end();

                    resolve(200);
                });
            } else {
                reject({code: 405});
            }
        });
    }
}

new MyServer({port: 8000, logs: true, index: 'README.md'});
```
You can return HTTP code or Promise object (and resolve HTTP code).

You can use default handlers:
* `handlerStaticFile(response, filePath, method, headers)` for response files
* `handlerNotFound(response, filePath, method, headers)` for response 404 error

If you reject Promise with object with code **ENOENT**, server response 404 error, else server response 500 error.
