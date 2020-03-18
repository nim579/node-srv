# Node-srv [![](https://badge.fury.io/js/node-srv.png)](https://npmjs.org/package/node-srv)
Simple fast and static node.js server

## Install

``` bash
$ npm install -g node-srv
```


## Usage

``` bash
# Start server on port 8000 in current dir
$ node-srv

# Start server on port 8000 in parent dir
$ node-srv ..

# Start server on port 8001 writing logs to *./nodeserver.log* file
$ node-srv --port 8001 --logs ./nodeserver.log
```


## API usage

`new Server(options, routes, handlers, exitCallback);`

``` js
// Require module
var server = require('node-srv');

// Start server
var srv = new Server({
    port: 5000,
    root: '../www/',
    logs: true
});

// Update server port (automatically restert server with new port)
srv.options.port = 5001;

// Stop server
srv.stop();
```


## Options

* **-p, --port [number]**, `port` — Port the server is started on (default `8000`, or env PORT)
* **-h, --host [host]**, `host` — Host or ip address on which the server will work (any host `0.0.0.0` by default)
* **-i, --index [file]**, `index` — Sets default index file for directories. For example: for uri `/test/`, server open `test/index.html`. Default `index.html`
* **-l, --logs [path/boolean]**, `logs` — Write logs flag. If you specify a path, it will write to that file (if path is folder, default filename will be node-srv.log). Default `false`
* **-t, --timeout [ms]**, `timeout` — Requset timeout (in ms). Default `30000`
* **-s, --https [boolean]**, `https` — Force create HTTPS server (only with `--key` and `--cert` options). Default `false`
* **--key [path]**, `key` — Path to key file for https server
* **--cert [path]**, `cert` — Path to certificate file for https server
* **--cors [hosts]**, `cors` — Enable CORS. If empty uses `*` for host. Default `false`
* **--not-found [path]**, `notFound` — Path to 404 error page. Default `null`
* **--help** — print help
* **--version** — print version


## Usage as [Grunt.js](http://gruntjs.com/) task
1. Install **node-srv** locally

  ``` bash
  $ npm i node-srv
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

Parameters way:
``` js
const Server = require('node-srv');

new Server({
    // options
    port: 8000
}, {
    // routes
    '**/*.md': 'markdown', // handler name for handlers list
    '_healthcheck': (params, resolve) => { // direct handler function
        resolve({
            body: `OK: ${params.method} ${params.uri}`, // "OK: GET /_healthcheck"
            code: 200,
            headers: {'Content-Type': 'text/plain'}
        });
    }
}, {
    markdown: (params, resolve, reject) => { // handlers key-value list
        markdown.renderFile(params.file).then( html => {
            resolve({
                body: html,
                code: 200,
                headers: {'Content-Type': 'text/html'}
            }, (error) => {
                if (error.code === 'ENOENT') {
                    reject({handler: 'notFound'});
                } else {
                    reject({error});
                }
            });
        });
    }
});
```

Extend way:
``` js
const Server = require('node-srv');

class MyServer extends Server {
    routes() {
        return {
            '**/*.md': 'markdown',
            '_healthcheck': (params, resolve) => {
                ... // as in parameters
            }
        };
    }
    handlers() {
        return {
            markdown: (params, resolve, reject) => {
                ... // as in parameters
            }
        }
    }
}

new MyServer();
```

You can return HTTP code or Promise object (and resolve HTTP code).

Default handlers:
* **file** — response file
* **notFound** — response error 404 page (default or optional)
* **timeout** — response timeout page (by default on request timeout)
* **serverError** — response error 500 page. Define error code by `reject({code: 403})` and page will return that.
* **options** — response for OPTIONS request method (CORS)

You can override its with any way.


## Breaking changes from 2.x to 3.x

CLI options:
* **-r, --root** removed. Use arguments: old `node-srv --root ../web`, new `node-srv ../web`
* **--404** renamed to **--not-found**
* **-k** shortcut removed from **--key**. Use only full flag
* **-c** shortcut removed from **--cert**. Use only full flag

Program API:
* class arguments changed
* handlers architecture changed
