## Warden.js

`warden.js` is lightweight router and manager of resouces, inspired by `Chaplin`'s `controller` and `composition`.

See [Chaplin.Controller · Chaplin Documentation](http://chaplinjs.org/chaplin/chaplin.controller.html "Chaplin.Controller · Chaplin Documentation")

This repository's base is `EngineeringMode/Grapnel.js` https://github.com/EngineeringMode/Grapnel.js

## Features

- Routing with params
- Reuse continuous instances after routing
- All steps can handle with ES6's `Promise`

## How to use

Create Controller at first

`app/controllers/home-controller.coffee`

```coffeescript
# resouce target must be implemented with `dispose` function
class Layout
  dispose: ->
class MyView
  dispose: ->

# app/controllers/home-controller.coffee
module.exports = class HomeController extends Warden.Controller
  beforeAction: (req) ->
	  @reuse Layout
	index: (req) ->
	  view = @reuse MyView 

# app/controllers/foo-controller.coffee
module.exports = class HomeController extends Warden.Controller
  beforeAction: (req) ->
	  @reuse Layout
	index: (req) ->

# app/initialize.coffee
$ ->
  router = new Warden
  router.match '', 'home#index'
  router.match 'foo/:bar', 'foo#index'
```

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

#### Warden.navigate(path)
fire routing

#### Warden#match(path: string, controllerAction: string)
Add routing pattern

### Warden.Controller
#### Warden.Controller#beforeAction() : => Promise?
First callback before action. If you return promise, router wait it.

#### Warden.Controller#afterAction() : => Promise?
Last callback after action. If you return promise, router wait it.

#### Warden.Controller#[action] : => Promise?

Callback fired by router. If you return promise, router wait it.

#### Warden.Controller#reuse(Class)

Reuse or create instance of Class. Class can't take constructor parameters and should be implemented with `dispose`.

#### Warden.Controller#use(Class)

Create instance of Class. Instance create by this function will be judged dead or alive by next routing.

## TODO

- Add testings
- bower registration
- PushState support(wip)
