Node-srv
========
Simple static node.js server

## Install

~~~~~ bash
npm install -g node-srv
~~~~~

## Use

~~~~~ bash
node-srv
~~~~~

## Use from scripts

~~~~~ js
var server = require('node-srv');

new server({
	port: 5000,
	root: '../www/',
	logs: true
});
~~~~~

## Options

- **-r, --root [path]** — Path, for server root-folder (default *./*)
- **-p, --port [number]** — Port on which the server is started (default *8000*)
- **-l, --logs** — Write logs flag

## [Todo list](TODO)