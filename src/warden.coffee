"use strict"

class Warden
  constructor: (opts) ->
    @pushState = opts?.pushState ? false
    throw 'Sorry, push state is not working yet' if @pushState is true

    @events = {}
    @params = []
    @state = null
    @version = '0.4.1'
    @anchor =
      defaultHash: window.location.hash
      get: -> if window.location.hash then window.location.hash.split('#')[1] else ''
      set: (anchor) ->
        window.location.hash = if not anchor then '' else anchor
        @
      clear: -> @set(false)
      reset : -> @set(@defaultHash)

    if @pushState
      debugger
      if typeof window.onpopstate is 'function' then @on 'popstate', window.onpopstate
      @ready = true
      window.onpopstate = =>
        if @ready
          @ready = false
          console.log 'popstate here'
          @trigger('popstate')
    else
      if typeof window.onhashchange is 'function' then @on 'hashchange', window.onhashchange
      window.addEventListener 'hashchange', => @trigger('hashchange')

    @trigger('initialized')

  trigger: (event) =>
    params = Array.prototype.slice.call(arguments, 1)
    if @events[event]
      for key , fn of @events[event]
        fn(params...)
    @

  get: (route, handler) =>
    keys = []
    regex = Warden.regexRoute route, keys

    invoke = =>
      match = @anchor.get().match(regex)
      if match
        event =
          route: route
          value: @anchor.get()
          handler: handler
          params: @params
          regex: match
          propagateEvent: true
          previousState: @state
          preventDefault: -> @propagateEvent = false
        @trigger('match', event)
        unless event.propagateEvent then return @
        @state = event
        req = params : {}, keys: keys, matches: event.regex.slice(1)
        for key, val of req.matches
          req.params[key] = if value then decodeURIComponent(value) else undefined;
        handler.call(@, req, event)
      @
    invoke().on('initialized hashchange popstate', invoke)

  on: (event, handler) ->
    events = event.split(' ')
    for event in events
      if @events[event]
        @events[event].push(handler)
      else
        @events[event] = [handler]
    @

  context: (context) =>
    (value, callback) =>
      prefix = if (context.slice(-1) isnt '/') then context + '/' else context
      pattern = prefix + value
      @get.call @, pattern, callback

  @regexRoute: (path, keys, sensitive, strict) ->
    if (path instanceof RegExp) then return path
    if (path instanceof Array) then path = '(' + path.join('|') + ')'
    path = path.concat(if strict then '' else '/?')
      .replace(/\/\(/g, '(?:/')
      .replace(/\+/g, '__plus__')
      .replace(/(\/)?(\.)?:(\w+)(?:(\(.*?\)))?(\?)?/g, (_, slash, format, key, capture, optional) ->
          keys.push(name: key, optional: !!optional)
          slash = slash or ''
          '' + (if optional then '' else slash) + '(?:' + (if optional then slash else '') + (format or '') + (capture or (format and '([^/.]+?)' and '([^/]+?)')) + ')' + (optional or '')
      )
      .replace(/([\/.])/g, '\\$1')
      .replace(/__plus__/g, '(.+)')
      .replace(/\*/g, '(.*)');
    new RegExp('^' + path + '$', if sensitive then '' else 'i')

  findController: (controllerName) =>
    require "controllers/#{controllerName}-controller"

  @navigate: (path, pushState = false) =>
    path = path.replace(/#|\//, '')
    if pushState
      history.pushState {}, "", '/'+path
    else
      location.href = '#'+path

  navigate: (path) =>
    Warden.navigate(path, @pushState)

  match: (route, requirement) =>
    [controllerName, actionName] = requirement.split('#')
    Controller = @findController controllerName

    continueAnyway = (maybePromise, next) -> maybePromise?.then?(next) ? next()

    action = (req) =>
      lastController = @currentController ? {}
      @currentController = new Controller {@pushState}
      @currentController.setLastUsings (lastController.usings ? [])

      continueAnyway @currentController.beforeAction(req), =>
        continueAnyway @currentController[actionName](req), =>
          @currentController.fix()
          continueAnyway lastController.dispose?(), =>
            continueAnyway @currentController.afterAction(req), =>
              @ready = true

    @get route, action

find = (list, fn) ->
  for i in list
    return i if fn(i)
  null

class Warden.Controller
  constructor: (opts) ->
    @pushState = opts?.pushState ? false
    @fixed = false
    @lastUsings = []
    @usings = []

  setLastUsings: (@lastUsings) ->

  reuse: (cls) =>
    throw 'Post initialized reuse exception' if @fixed
    throw 'not newable' unless cls.constructor

    used = find @lastUsings, (used) -> used.constructor is cls
    @usings.push (used ? new cls)

  use: (cls) ->
    @usings.push new cls

  navigate: (path) =>
    Warden.navigate(path, @pushState)

  fix: ->
    currentUsedList = []
    for used in @lastUsings
      alsoUsed = find @usings, (using) =>
        using.constructor is used.constructor
      unless alsoUsed
        used.dispose()
        @lastUsings.splice @lastUsings.indexOf(used), 1
    @fixed = true
    delete @lastUsings

  dispose: =>
    delete @usings

  beforeAction: (req) ->

  afterAction: (req) ->

if 'function' is typeof window.define
  window.define (require)-> Warden
else if 'object' is typeof exports
  module.exports = Warden
else
  window.Warden = Warden
