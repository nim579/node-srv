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
        this.parseLogsPath();

        this.ev = new events();
        this.stack = [];

        this.on('request', this.startResponse, this);
        this.on('response', this.startResponse);

        this.bindCloseEvents();

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
        this.server = http.createServer(function(request, response){
            _this.addRequest(request, response);
        });

        this.server.listen(Number(this.options.port));
        process.stdout.write("Node.js server running at\n => http://localhost:" + this.options.port + "/\n");
    }

    serverClass.prototype.stop = function(callback){
        this.stack = [];
        if(this.server != null) this.server.close();
    }

    serverClass.prototype.bindCloseEvents = function(){
        var _this = this;
        var exit = function(){
            process.removeAllListeners('SIGINT');
            process.removeAllListeners('SIGTERM');
            _this.stop();
            if(typeof _this.exitCallback === 'function') _this.exitCallback.apply(_this);
            process.exit();
        }
        process.on('SIGINT', exit);
        process.on('SIGTERM', exit);
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
        var reqObj = {
            request: req,
            response: res,
            uid: Math.floor(Math.random()*10000000),
            startTime: new Date(),
            uri: url.parse(req.url).pathname.replace(/^\//, '').replace(/\/$/, '/'+this.options.index),
            body: ''
        }
        if(reqObj.uri.length === 0){
            reqObj.uri = this.options.index;
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

            this.responseFile(reqObj, function(err, resObj){
                _this.response(resObj);
            });
        }
    }

    serverClass.prototype.responseFile = function(reqObj, callback){
        var _this = this;
        var filePath = reqObj.filename;

        var handlerCallback = function(err, requestObj){
            if(err){
                 _this.response500(reqObj, err, callback);
                return false;
            }
            callback(null, requestObj);
        }

        if(fs.existsSync(filePath)){
            var handler;
            if(handler = this.selectHandler(filePath)){
                handler.method(reqObj, handlerCallback);
            } else {
                this.responseStatic(reqObj, handlerCallback);
            }
        } else {
            this.response404(reqObj, callback);
        }
    }

    serverClass.prototype.responseStatic = function(reqObj, callback){
        var _this = this;
        var filePath = reqObj.filename;

        reqObj.mime = {"Content-Type": mime.lookup(filePath)};
        reqObj.status = 200;
        fs.readFile(filePath, "binary", function(err, file){
            if(err){
                _this.response500(reqObj, err, callback);
                this.errorLog(reqObj, 'Error 500: '+JSON.stringify(err));
                return false;
            }
            reqObj.body = file;
            reqObj.bodyType = "binary";

            callback(null, reqObj);
        });
    }

    serverClass.prototype.response500 = function(reqObj, e, callback){
        body = 'Error 500. ' + http.STATUS_CODES['500'] + '. ' + JSON.stringify(e);

        if(fs.existsSync(this.options['500'])){
            body = fs.readFileSync(this.options['500']);
        }

        reqObj = _.extend(reqObj, {
            status: 500,
            mime: {"Content-Type": 'text/html'},
            body: body
        });
        callback('Error 500', reqObj);
    }

    serverClass.prototype.response404 = function(reqObj, callback){
        body = 'Error 404. ' + http.STATUS_CODES['404'];

        if(fs.existsSync(this.options['404'])){
            body = fs.readFileSync(this.options['404']);
        }

        reqObj = _.extend(reqObj, {
            status: 404,
            mime: {"Content-Type": 'text/html'},
            body: body
        });
        callback('Error 404', reqObj);
    }

    serverClass.prototype.writeLog = function(message){
        if(this.options.logs){
            if(typeof this.options.logs == 'string') {
                fs.appendFileSync(this.options.logs, message);
            } else {
                process.stdout.write(message);
            }
        }
    }

    serverClass.prototype.parseLogsPath = function(){
        if(typeof this.options.logs == 'string') {
            logPath = path.resolve(process.cwd(), this.options.logs ? this.options.logs : '');

            if(fs.existsSync(logPath)){
                if(fs.statSync(logPath).isDirectory()) logPath = path.join(logPath, 'node-srv.log');
            }

            this.options.logs = logPath;
        }
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

    serverClass.prototype.selectHandler = function(filepath){
        var handler = _.find(this.constructor.fileHandlers, function(handlers){
            if(_.isArray(handlers.extnames)){
                return _.contains(handlers.extnames, path.extname(filepath).toLowerCase());
            } else {
                return handlers.extnames === path.extname(filepath).toLowerCase()
            }
        });
        if(handler && handler.method){
            return handler;
        } else {
            return false;
        }
    }

    serverClass.fileHandlers = [];

    serverClass.extendHandlers = function(handler){
        if(_.isArray(handler)){
            serverClass.fileHandlers = _.union(serverClass.fileHandlers, handler);
        } else if(_.isObject(handler)){
            serverClass.fileHandlers.push(handler);
        }
        return this;
    }

    serverClass.extend = function(protoProps){
        var parent = this;
        var child;

        if (protoProps && _.has(protoProps, 'constructor')) {
            child = protoProps.constructor;
        } else {
            child = function(){ return parent.apply(this, arguments); };
        }

        _.extend(child, parent);

        var Surrogate = function(){ this.constructor = child; };
        Surrogate.prototype = parent.prototype;
        child.prototype = new Surrogate;

        if (protoProps) _.extend(child.prototype, protoProps);

        child.__super__ = parent.prototype;
        return child;
    }

    return serverClass;
})();

module.exports = serverClass;