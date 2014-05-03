class window.Layout
  dispose: ->
    console.log 'Layout disposed'
class window.HomeView
  dispose: ->
    console.log 'HomeView disposed'

$ ->
  router = new Warden
  router.match '', 'home#index'
  router.match 'foo', 'foo#index'
