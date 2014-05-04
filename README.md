## Warden.js

`warden.js` is lightweight router and manager of resouces, inspired by `Chaplin`'s `controller` and `composition`.

See [Chaplin.Controller · Chaplin Documentation](http://chaplinjs.org/chaplin/chaplin.controller.html "Chaplin.Controller · Chaplin Documentation")

This repository's base is `EngineeringMode/Grapnel.js` https://github.com/EngineeringMode/Grapnel.js

## Features

- Routing with params
- Reuse continuous instances after routing
- All steps can handle with ES6's `Promise`

`Warden` is mainly designed to use with [yyx990803/vue](https://github.com/yyx990803/vue "yyx990803/vue").

## How to use

This is an ideological example.

```coffeescript
# resouce target must be implemented with `dispose` function

class Layout
  dispose: ->
class HomeView
  dispose: ->
class FooView
  dispose: ->

# app/controllers/home-controller.coffee
module.exports = class HomeController extends Warden.Controller
  beforeAction: (params) ->
    @reuse Layout
  index: (params) ->
    home = @reuse HomeView # Create instance or reuse from previous controller

# app/controllers/foo-controller.coffee
module.exports = class FooController extends Warden.Controller
  beforeAction: (params) ->
    @reuse Layout
  index: (params) ->
    console.log params.bar # extract params
    foo1 = @reuse 'foo1', FooView # named reusing
    foo2 = @reuse 'foo2', FooView # another instance
    disposable = @reuse {dispose: -> console.log 'It will be called by routing'}


# app/initialize.coffee
$ ->
  router = new Warden
  router.match '', 'home#index'
  router.match 'foo/:bar', 'foo#index'
```

## Tactics

`HomeController` has `MyView` but `FooController` doesn't have it. So after routing from '' to '/foo', `MyView` will be dispose. `Layout` will alive in this case.

if you want to arrange controllers allocation, Override `Warden#findController`

```coffeescript
Warden.prototype.findController = (controllerName) ->
  switch controllerName
    when 'home'
      class HomeController extends Warden.Controller
        index: ->
         'something your logic'
```

Default expects `require('controllers/' + controlleName + '-controller')` by AMD.

## API

### Warden

- `Warden.navigate(path)` Fire routing
- `Warden#match(path: string, controllerAction: string)` Add routing pattern
- `Warden.replaceLinksToHashChange()` Replace `a` tag link event by jQuery (jQuery or zepto needed now)

### Warden.Controller

- `Warden.Controller#reuse(Class)` Reuse instance of Class by matching constructor or create instance with new
- `Warden.Controller#reuse({dispose()})` Reuse disposable object or register
- `Warden.Controller#reuse(name, Class)` Reuse instance of Class by name
- `Warden.Controller#reuse(name, {dispose()})` Reuse disposable object by name
- `Warden.Controller#use(Class)` Create instance of Class. Instance create by this function will be judged dead or alive by next routing.
- `Warden.Controller#beforeAction(params) : => Promise?` First callback before action. If you return promise, router wait it.
- `Warden.Controller#afterAction(params) : => Promise?` Last callback after action. If you return promise, router wait it.
- `Warden.Controller\#[action](params) : => Promise?` Callback fired by router. If you return promise, router wait it.

## TODO

- Add testings
- PushState support
- Independent from Grapnel
