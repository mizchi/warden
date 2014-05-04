"use strict"

# helpers
find = (list, fn) ->
  for i in list
    return i if fn(i)
  null

# require
{Grapnel} = require './grapnel'

class Warden extends Grapnel
  @navigate: (path, pushState = false) =>
    path = path.replace(/^(#|\/)/, '')
    if pushState
      history.pushState {}, "", '/'+path
    else
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

      continueAnyway @currentController.beforeAction(req), =>
        continueAnyway @currentController[actionName](req), =>
          @currentController.fix()
          continueAnyway lastController.dispose?(), =>
            continueAnyway @currentController.afterAction(req), =>
              @ready = true

    @get route, action

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
    used ?= new cls
    @usings.push used
    used

  use: (cls) ->
    instance = new cls
    @usings.push instance
    instance

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
