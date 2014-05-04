"use strict"

# helpers
find = (list, fn) ->
  for i in list
    return i if fn(i)
  null

# require
{Grapnel} = require './grapnel'

class Warden extends Grapnel
  @replaceLinksToHashChange: ->
    # TODO: Remove dependency to jQuery
    throw 'Require jQuery or zepto' unless $?
    $('body').on 'click', 'a', (event) =>
      event.preventDefault()
      href = $(event.target).attr('href').replace /^(#|\/)/, ''
      Warden.navigate(href)

  @navigate: (path) =>
    path = path.replace(/^(#|\/)/, '')
    location.href = '#'+path

  navigate: (path) =>
    Warden.navigate(path, @pushState)

  findController: (controllerName) =>
    require "controllers/#{controllerName}-controller"

  match: (route, requirement) =>
    [controllerName, actionName] = requirement.split('#')
    Controller = @findController controllerName

    continueAnyway = (maybePromise, next) -> maybePromise?.then?(next) ? next()

    action = (req) =>
      lastController = @currentController ? {}
      @currentController = new Controller {@pushState}
      @currentController.setLastUsings (lastController.usings ? [])

      continueAnyway @currentController.beforeAction(req.params), =>
        continueAnyway @currentController[actionName](req.params), =>
          @currentController.fix()
          continueAnyway lastController.dispose?(), =>
            continueAnyway @currentController.afterAction(req.params), =>
              try window.dispatchEvent new CustomEvent 'warden:routed', {req, controllerName, actionName}

    @get route, action

class Warden.Controller
  constructor: (opts) ->
    @pushState = opts?.pushState ? false
    @fixed = false
    @lastUsings = []
    @usings = []

  @findInstance: (usings, target) ->
    (find usings, (using) ->
      if (typeof target) is 'string'
        using.key is target
      else if target instanceof Function
        using.instance.constructor is target
      else if target instanceof Object
        using.instance is target
    )?.instance

  _createInstance: (maybeNewable) ->
    if maybeNewable instanceof Function
      unless maybeNewable::dispose instanceof Function
        console.warn("This class does not have dispose", maybeNewable)
      new maybeNewable
    else if maybeNewable instanceof Object
      unless maybeNewable.dispose instanceof Function
        console.warn("This object does not have dispose", maybeNewable)
      maybeNewable
    else
      throw new Error "Warden can't compose #{maybeNewable?.toString?() ? maybeNewable}"

  setLastUsings: (@lastUsings) ->

  _reuseFrom: (usings, target, maybeNewable) ->
    instance = (@constructor.findInstance usings, target) ? @_createInstance (maybeNewable ? target)
    key = if (typeof target) is 'string' then target else instance
    @usings.push {instance, key}
    instance

  reuse: (target, maybeNewable = null) =>
    throw 'Post fixed reuse exception' if @fixed
    @_reuseFrom @lastUsings, target, maybeNewable

  use: (target, maybeNewable) ->
    throw 'Pre fixed use exception' unless @fixed
    instance = @constructor.findInstance(@usings, target)
    return instance if instance?
    @_reuseFrom @usings, target, maybeNewable

  navigate: (path) => Warden.navigate(path)

  fix: ->
    throw 'Warden.Controller#fix can be called only once' if @fixed

    # dispose lastUsings
    for used in @lastUsings
      alsoUsed = @constructor.findInstance(@usings, used.key)
      unless alsoUsed? then used.instance.dispose()

    @fixed = true
    delete @lastUsings

  dispose: =>
    delete @usings

  beforeAction: (params) -> # override me

  afterAction: (params) -> # override me

if 'function' is typeof window.define
  window.define (require) -> Warden
else
  window.Warden = Warden
