var server  = require('./server')
  , program = require('commander');

program
  .version('0.2.0')
  .option('-p, --port [number]', 'Sets port on which the server will work', '8000')
  .option('-r, --root [path]', 'Sets the root from which the server will run')
  .option('-l, --logs [path/boolean]', 'Logs writing flag', false)
  .option('--404 [path]', 'Path to 404 error page', null)
  .option('--500 [path]', 'Path to 500 error page', null)
  .parse(process.argv);

new server(program);
