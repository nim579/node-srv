var server  = require('./server')
  , program = require('commander')
  , _		= require('underscore')
  , root 	= '';


try {
	root = _.without(JSON.parse(process.env.npm_config_argv).original, 'start', 'node-srv', 'run-script', 'npm')[0];
} catch (e) {
	root = process.cwd();
}


program
  .version('0.2.0')
  .option('-p, --port [number]', 'Sets port on which the server will work', process.env.PORT || '8000')
  .option('-r, --root [path]', 'Sets the root from which the server will run', root)
  .option('-i, --index [file]', 'Sets the index file for opening like default file in directories', 'index.html')
  .option('-l, --logs [path/boolean]', 'Logs writing flag', false)
  .option('--404 [path]', 'Path to 404 error page', null)
  .option('--500 [path]', 'Path to 500 error page', null)
  .parse(process.argv);

new server(program);
