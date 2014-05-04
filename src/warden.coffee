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
    find usings, (using) ->
      if (typof target) is 'string'
        using.key is target
      else if target instanceof Function
        using.instance.constructor is target
      else if target instanceof Object
        using.instance is target

  _createInstance: (maybeNewable) ->
    if maybePromise instanceof Function
      new maybeNewable
    else if maybeNewable instanceof Object
      maybeNewable

  setLastUsings: (@lastUsings) ->

  reuse: (target, maybeNewable = null) =>
    throw 'Post fixed reuse exception' if @fixed

    used = (@constructor.findInstance @lastUsings, target) ? @_createInstance(maybeNewable)
    console.log 'used',used

    if (typof target) is 'string'
      @usings.push {key: target, instance: used}
    else if target instanceof Function
      @usings.push {key: used, instance: used}
    used

  use: (target, maybeNewable) ->
    instance = @constructor.findInstance(@usings, target)
    return instance if instance?

    if (typof target) is 'string'
      instance = @_createInstance maybeNewable
      @usings.push {key: target, instance: instance}
    else
      instance = @_createInstance target
      @usings.push {key: instance, instance: instance}
    instance

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
