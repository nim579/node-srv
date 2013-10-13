Node-srv
========
Simple static node.js server

## Install

~~~~~ bash
npm install -g node-srv
~~~~~

## Use

~~~~~ bash
# Start server on port 8000
node-srv

# Start server on port 8001 with writing logs in file *./nodeserver.log*
node-srv --port 8001 --logs ./nodeserver.log
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
- **-l, --logs [path/boolean]** — Write logs flag. If you specify a path, it will write to this file (if path is folder, default filename node-srv.log) 
- **--404 [path]** — Path to 404 error page
- **--500 [path]** — Path to 500 error page

## Use for [Heroku](https://heroku.com)

1. Install **node-srv** localy

  ~~~~~ bash
  $ npm install node-srv --save
  ~~~~~

2. Make [Pcocfile](https://devcenter.heroku.com/articles/getting-started-with-nodejs#declare-process-types-with-procfile)

  You can use root, logs, 404 500 arguments 

  ~~~~~ bash
  web: node node_modules/node-srv/index --logs --404 404.html
  ~~~~~

3. Deploy to heroku and enjoy!