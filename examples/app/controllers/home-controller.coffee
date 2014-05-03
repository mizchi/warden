module.exports = class HomeController extends Warden.Controller
  beforeAction: (req) ->
    layout = @reuse Layout
    new Promise (done) =>
      setTimeout =>
        done()
      , 1

  afterAction: (req) ->

  index: ->
    homeView = @reuse HomeView
    console.log 'home'
