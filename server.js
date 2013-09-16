var mime        = require('mime')
  , path        = require('path')
  , http        = require('http')
  , url         = require('url')
  , fs          = require('fs')
  , events      = require('events').EventEmitter
  , _           = require('underscore');


var serverClass = (function(){

    function serverClass(options){
        this.options = options;

        process.on('SIGINT', function(){
            process.stdout.write('Server was shutdown at ' + new Date().toJSON() + '\n');
            process.exit();
        });
        process.on('SIGTERM', function(){
            process.stdout.write('Server was shutdown at ' + new Date().toJSON() + '\n');
            process.exit();
        });

        this.ev = new events();
        this.stack = [];

        this.on('request', this.startResponse, this);
        this.on('response', this.startResponse);

        this.startServer();
    }

    serverClass.prototype.on = function(event, foo, context){
        var _this = this;
        this.ev.on(event, function(){
            foo.apply( typeof context !== 'undefined' ? context : this, arguments );
        }); 
    }

    serverClass.prototype.startServer = function(){
        var _this = this;
        var server = http.createServer(function(request, response){
            _this.addRequest(request, response);
        });

        server.listen(Number(this.options.port));
        process.stdout.write("Node.js server running at\n => http://localhost:" + this.options.port + "/\n");
    }

    serverClass.prototype.done = function(callback, context){
        if(typeof callback === 'function'){
            this.resolve = function(){
                callback.apply(typeof context !== 'undefined' ? context : this, arguments);
            }
        }
    }

    serverClass.prototype.response = function(resObj){
        this.accessLog(resObj);

        resObj.response.writeHead(resObj.status, resObj.mime);
        resObj.response.write(resObj.body, resObj.bodyType != null ? resObj.bodyType : void 0);
        resObj.response.end();
    }

    serverClass.prototype.addRequest = function(req, res){
        reqObj = {
            request: req,
            response: res,
            uid: Math.floor(Math.random()*10000000),
            startTime: new Date(),
            uri: url.parse(req.url).pathname.replace(/^\//, '').replace(/\/$/, '/index.html'),
            body: ''
        }
        if(reqObj.uri.length === 0){
            reqObj.uri = 'index.html';
        }
        reqObj.filename = path.resolve(process.cwd(), this.options.root ? this.options.root : '', reqObj.uri);

        this.stack.push(reqObj);
        this.ev.emit('request');
    }

    serverClass.prototype.startResponse = function(){
        if(this.stack.length > 0){
            var _this = this;
            var reqObj = this.stack[0];
            this.stack = _.without(this.stack, reqObj);

            this.responseStatic(reqObj, function(err, resObj){
                _this.response(resObj);
            });
        }
    }

    serverClass.prototype.responseStatic = function(reqObj, callback){
        var _this = this;
        var filePath = reqObj.filename;

        if(fs.existsSync(filePath)){
            reqObj.mime = {"Content-Type": mime.lookup(filePath)};
            reqObj.status = 200;
            fs.readFile(filePath, "binary", function(err, file){
                if(err){
                    _this.response500(err, callback);
                    this.errorLog(reqObj, 'Error 500: '+JSON.stringify(err));
                    return false;
                }
                reqObj.body = file;
                reqObj.bodyType = "binary";

                callback(null, reqObj);
            });
        } else {
            this.response404(callback);
        }
    }

    serverClass.prototype.response500 = function(reqObj, e, callback){
        reqObj = _.extend(reqObj, {
            status: 500,
            mime: {"Content-Type": 'text/plain'},
            body: 'Error 500! ' + JSON.stringify(e)
        });
        callback('Error 500', reqObj);
    }

    serverClass.prototype.response404 = function(callback){
        reqObj = _.extend(reqObj, {
            status: 404,
            mime: {"Content-Type": 'text/plain'},
            body: 'Error 404'
        });
        callback('Error 404', reqObj);
    }

    serverClass.prototype.writeLog = function(message){
        if(this.options.logs) process.stdout.write(message);
    }

    serverClass.prototype.accessLog = function(resObj){
        this.writeLog(
            "["+resObj.startTime.toJSON()+"]  (+" + (new Date() - resObj.startTime) + "ms):  " +
            path.join(resObj.request.headers.host, resObj.uri) + " — (" + resObj.filename + ")  Status code: " + resObj.status + "  (" + resObj.request.headers['user-agent'] + ") \n"
        );
    }
    serverClass.prototype.errorLog = function(resObj, error){
        this.writeLog(
            "["+resObj.startTime.toJSON()+"]  (+" + (new Date() - resObj.startTime) + "ms):  " +
            "Error: " + error + "  " + 
            path.join(resObj.request.headers.host, resObj.uri) + "  Status code: " + resObj.status + "  (" + resObj.request.headers['user-agent'] + ") \n"
        );
    }

    return serverClass;
})();

module.exports = serverClass;