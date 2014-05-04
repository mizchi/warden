(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
/****
 * Grapnel.js
 * https://github.com/EngineeringMode/Grapnel.js
 *
 * @author Greg Sabia Tucker
 * @link http://artificer.io
 * @version 0.4.1
 *
 * Released under MIT License. See LICENSE.txt or http://opensource.org/licenses/MIT
*/

(function(root){

    function Grapnel(){
        "use strict";

        var self = this; // Scope reference
        this.events = {}; // Event Listeners
        this.params = []; // Named parameters
        this.state = null; // Event state
        this.version = '0.4.1'; // Version
        // Anchor
        this.anchor = {
            defaultHash : window.location.hash,
            get : function(){
                return (window.location.hash) ? window.location.hash.split('#')[1] : '';
            },
            set : function(anchor){
                window.location.hash = (!anchor) ? '' : anchor;
                return self;
            },
            clear : function(){
                return this.set(false);
            },
            reset : function(){
                return this.set(this.defaultHash);
            }
        }
        /**
         * ForEach workaround
         *
         * @param {Array} to iterate
         * @param {Function} callback
        */
        this._forEach = function(a, callback){
            if(typeof Array.prototype.forEach === 'function') return Array.prototype.forEach.call(a, callback);
            // Replicate forEach()
            return function(c, next){
                for(var i=0, n = this.length; i<n; ++i){
                    c.call(next, this[i], i, this);
                }
            }.call(a, callback);
        }
        /**
         * Fire an event listener
         *
         * @param {String} event
         * @param {Mixed} [attributes] Parameters that will be applied to event listener
         * @return self
        */
        this.trigger = function(event){
            var params = Array.prototype.slice.call(arguments, 1);
            // Call matching events
            if(this.events[event]){
                this._forEach(this.events[event], function(fn){
                    fn.apply(self, params);
                });
            }

            return this;
        }
        // Check current hash change event -- if one exists already, add it to the queue
        if(typeof window.onhashchange === 'function') this.on('hashchange', window.onhashchange);
        /**
         * Hash change event
         * TODO: increase browser compatibility. "window.onhashchange" can be supplemented in older browsers with setInterval()
        */
        window.onhashchange = function(){
            self.trigger('hashchange');
        }

        return this.trigger('initialized');
    }
    /**
     * Create a RegExp Route from a string
     * This is the heart of the router and I've made it as small as possible!
     *
     * @param {String} Path of route
     * @param {Array} Array of keys to fill
     * @param {Bool} Case sensitive comparison
     * @param {Bool} Strict mode
    */
    Grapnel.regexRoute = function(path, keys, sensitive, strict){
        if(path instanceof RegExp) return path;
        if(path instanceof Array) path = '(' + path.join('|') + ')';
        // Build route RegExp
        path = path.concat(strict ? '' : '/?')
            .replace(/\/\(/g, '(?:/')
            .replace(/\+/g, '__plus__')
            .replace(/(\/)?(\.)?:(\w+)(?:(\(.*?\)))?(\?)?/g, function(_, slash, format, key, capture, optional){
                keys.push({ name : key, optional : !!optional });
                slash = slash || '';

                return '' + (optional ? '' : slash) + '(?:' + (optional ? slash : '') + (format || '') + (capture || (format && '([^/.]+?)' || '([^/]+?)')) + ')' + (optional || '');
            })
            .replace(/([\/.])/g, '\\$1')
            .replace(/__plus__/g, '(.+)')
            .replace(/\*/g, '(.*)');

        return new RegExp('^' + path + '$', sensitive ? '' : 'i');
    }
    /**
     * Add an action and handler
     *
     * @param {String|RegExp} action name
     * @param {Function} callback
     * @return self
    */
    Grapnel.prototype.get = Grapnel.prototype.add = function(route, handler){
        var self = this,
            keys = [],
            regex = Grapnel.regexRoute(route, keys);

        var invoke = function(){
            // If action is instance of RegEx, match the action
            var match = self.anchor.get().match(regex);
            // Test matches against current action
            if(match){
                // Match found
                var event = {
                    route : route,
                    value : self.anchor.get(),
                    handler : handler,
                    params : self.params,
                    regex : match,
                    propagateEvent : true,
                    previousState : self.state,
                    preventDefault : function(){
                        this.propagateEvent = false;
                    }
                }
                // Trigger main event
                self.trigger('match', event);
                // Continue?
                if(!event.propagateEvent) return self;
                // Save new state
                self.state = event;
                // Callback
                var req = { params : {}, keys : keys, matches : event.regex.slice(1) };
                // Build parameters
                self._forEach(req.matches, function(value, i){
                    var key = (keys[i] && keys[i].name) ? keys[i].name : i;
                    // Parameter key will be its key or the iteration index. This is useful if a wildcard (*) is matched
                    req.params[key] = (value) ? decodeURIComponent(value) : undefined;
                });
                // Call handler
                handler.call(self, req, event);
            }
            // Returns self
            return self;
        }
        // Invoke and add listeners -- this uses less code
        return invoke().on('initialized hashchange', invoke);
    }
    /**
     * Add an event listener
     *
     * @param {String|Array} event
     * @param {Function} callback
     * @return self
    */
    Grapnel.prototype.on = Grapnel.prototype.bind = function(event, handler){
        var self = this,
            events = event.split(' ');

        this._forEach(events, function(event){
            if(self.events[event]){
                self.events[event].push(handler);
            }else{
                self.events[event] = [handler];
            }
        });

        return this;
    }
    /**
     * Call Grapnel().router constructor for backwards compatibility
     *
     * @return {self} Router
    */
    Grapnel.Router = Grapnel.prototype.router = Grapnel;
    /**
     * Allow context
     *
     * @param {String} Route context
     * @return {Function} Adds route to context
    */
    Grapnel.prototype.context = function(context){
        var self = this;

        return function(value, callback){
            var prefix = (context.slice(-1) !== '/') ? context + '/' : context,
                pattern = prefix + value;

            return self.get.call(self, pattern, callback);
        }
    }
    /**
     * Create routes based on an object
     *
     * @param {Object} Routes
     * @return {self} Router
    */
    Grapnel.listen = function(routes){
        // Return a new Grapnel instance
        return (function(){
            // TODO: Accept multi-level routes
            for(var key in routes){
                this.get.call(this, key, routes[key]);
            }

            return this;
        }).call(new Grapnel());
    }
    // Window or module?
    if('function' === typeof root.define){
        root.define(function(require){
            return Grapnel;
        });
    }else if('object' === typeof exports){
        exports.Grapnel = Grapnel;
    }else{
        root.Grapnel = Grapnel;
    }

}).call({}, window);

},{}],2:[function(require,module,exports){
"use strict";
var Grapnel, Warden, find,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

find = function(list, fn) {
  var i, _i, _len;
  for (_i = 0, _len = list.length; _i < _len; _i++) {
    i = list[_i];
    if (fn(i)) {
      return i;
    }
  }
  return null;
};

Grapnel = require('./grapnel').Grapnel;

Warden = (function(_super) {
  __extends(Warden, _super);

  function Warden(opts) {
    var action, route;
    if (opts == null) {
      opts = {};
    }
    this.match = __bind(this.match, this);
    this.findController = __bind(this.findController, this);
    this.navigate = __bind(this.navigate, this);
    Warden.__super__.constructor.apply(this, arguments);
    if (opts.routes instanceof Function) {
      opts.routes(this.match);
    } else if (opts.routes instanceof Object) {
      for (route in routes) {
        action = routes[route];
        this.match(route, action);
      }
    }
  }

  Warden.replaceLinksToHashChange = function() {
    if (typeof $ === "undefined" || $ === null) {
      throw 'Require jQuery or zepto';
    }
    return $('body').on('click', 'a', (function(_this) {
      return function(event) {
        var href;
        event.preventDefault();
        href = $(event.target).attr('href').replace(/^(#|\/)/, '');
        return Warden.navigate(href);
      };
    })(this));
  };

  Warden.navigate = function(path) {
    path = path.replace(/^(#|\/)/, '');
    return location.href = '#' + path;
  };

  Warden.prototype.navigate = function(path) {
    return Warden.navigate(path, this.pushState);
  };

  Warden.prototype.findController = function(controllerName) {
    return require("controllers/" + controllerName + "-controller");
  };

  Warden.prototype.match = function(route, requirement) {
    var Controller, action, actionName, continueAnyway, controllerName, _ref;
    _ref = requirement.split('#'), controllerName = _ref[0], actionName = _ref[1];
    Controller = this.findController(controllerName);
    continueAnyway = function(maybePromise, next) {
      var _ref1;
      return (_ref1 = maybePromise != null ? typeof maybePromise.then === "function" ? maybePromise.then(next) : void 0 : void 0) != null ? _ref1 : next();
    };
    action = (function(_this) {
      return function(req) {
        var lastController, _ref1, _ref2;
        lastController = (_ref1 = _this.currentController) != null ? _ref1 : {};
        _this.currentController = new Controller({
          pushState: _this.pushState
        });
        _this.currentController.setLastUsings((_ref2 = lastController.usings) != null ? _ref2 : []);
        return continueAnyway(_this.currentController.beforeAction(req.params), function() {
          return continueAnyway(_this.currentController[actionName](req.params), function() {
            _this.currentController.fix();
            return continueAnyway(typeof lastController.dispose === "function" ? lastController.dispose() : void 0, function() {
              return continueAnyway(_this.currentController.afterAction(req.params), function() {
                try {
                  return window.dispatchEvent(new CustomEvent('warden:routed', {
                    req: req,
                    controllerName: controllerName,
                    actionName: actionName
                  }));
                } catch (_error) {}
              });
            });
          });
        });
      };
    })(this);
    return this.get(route, action);
  };

  return Warden;

})(Grapnel);

Warden.Controller = (function() {
  function Controller(opts) {
    this.dispose = __bind(this.dispose, this);
    this.navigate = __bind(this.navigate, this);
    this.reuse = __bind(this.reuse, this);
    var _ref;
    this.pushState = (_ref = opts != null ? opts.pushState : void 0) != null ? _ref : false;
    this.fixed = false;
    this.lastUsings = [];
    this.usings = [];
  }

  Controller.findInstance = function(usings, target) {
    var _ref, _ref1;
    return (_ref = (_ref1 = find(usings, function(using) {
      if ((typeof target) === 'string') {
        return using.key === target;
      } else if (target instanceof Function) {
        return using.instance.constructor === target;
      } else if (target instanceof Object) {
        return using.instance === target;
      }
    })) != null ? _ref1.instance : void 0) != null ? _ref : null;
  };

  Controller.prototype._createInstance = function(maybeNewable) {
    var _ref;
    if (maybeNewable instanceof Function) {
      if (!(maybeNewable.prototype.dispose instanceof Function)) {
        console.warn("This class does not have dispose", maybeNewable);
      }
      return new maybeNewable;
    } else if (maybeNewable instanceof Object) {
      if (!(maybeNewable.dispose instanceof Function)) {
        console.warn("This object does not have dispose", maybeNewable);
      }
      return maybeNewable;
    } else {
      throw new Error("Warden can't compose " + ((_ref = maybeNewable != null ? typeof maybeNewable.toString === "function" ? maybeNewable.toString() : void 0 : void 0) != null ? _ref : maybeNewable));
    }
  };

  Controller.prototype.setLastUsings = function(lastUsings) {
    this.lastUsings = lastUsings;
  };

  Controller.prototype._reuseFrom = function(usings, target, maybeNewable) {
    var instance, key, _ref;
    instance = (_ref = this.constructor.findInstance(usings, target)) != null ? _ref : this._createInstance(maybeNewable != null ? maybeNewable : target);
    key = (typeof target) === 'string' ? target : instance;
    this.usings.push({
      instance: instance,
      key: key
    });
    return instance;
  };

  Controller.prototype.reuse = function(target, maybeNewable) {
    if (maybeNewable == null) {
      maybeNewable = null;
    }
    if (this.fixed) {
      throw 'Post fixed reuse exception';
    }
    return this._reuseFrom(this.lastUsings, target, maybeNewable);
  };

  Controller.prototype.use = function(target, maybeNewable) {
    var instance;
    if (!this.fixed) {
      throw 'Pre fixed use exception';
    }
    instance = this.constructor.findInstance(this.usings, target);
    if (instance != null) {
      return instance;
    }
    return this._reuseFrom(this.usings, target, maybeNewable);
  };

  Controller.prototype.navigate = function(path) {
    return Warden.navigate(path);
  };

  Controller.prototype.fix = function() {
    var alsoUsed, used, _i, _len, _ref;
    if (this.fixed) {
      throw 'Warden.Controller#fix can be called only once';
    }
    _ref = this.lastUsings;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      used = _ref[_i];
      alsoUsed = this.constructor.findInstance(this.usings, used.key);
      if (alsoUsed == null) {
        used.instance.dispose();
      }
    }
    this.fixed = true;
    return delete this.lastUsings;
  };

  Controller.prototype.dispose = function() {
    return delete this.usings;
  };

  Controller.prototype.beforeAction = function(params) {};

  Controller.prototype.afterAction = function(params) {};

  return Controller;

})();

if ('function' === typeof window.define) {
  window.define(function(require) {
    return Warden;
  });
} else {
  window.Warden = Warden;
}


},{"./grapnel":1}]},{},[2])