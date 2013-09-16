
var server  = require('./server')
  , program = require('commander');

program
  .version('0.1.0')
  .option('-p, --port [number]', 'Sets port on which the server will work', '8000')
  .option('-r, --root [path]', 'Sets the root from which the server will run')
  .option('-l, --logs', 'Logs writing flag')
  .parse(process.argv);

new server(program);
