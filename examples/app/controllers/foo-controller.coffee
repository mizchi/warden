module.exports = class FooController extends Warden.Controller
  beforeAction: (req) ->
    layout = @reuse Layout

  afterAction: (req) ->

  index: ->
    console.log 'foo'
