##
## Copyright © 2013 Spectrum IT Solutions Gmbh
##
## Firmensitz: Wien
## Firmenbuchgericht: Handelsgericht Wien
## Firmenbuchnummer: 393588g
##
## All Rights Reserved.
##
## The use and / or modification of this file is subject to
## Spectrum IT Solutions GmbH and may not be made without the explicit
## permission of Spectrum IT Solutions GmbH
##

spew = require "spew"
routes = require "../../../routes.json"

setup = (options, imports, register) ->

  server = imports["line-express"]
  utility = imports["logic-utility"]

  # We have no homepage, just redirect to the login (unauth dash -> login)
  server.server.get "/", (req, res) -> res.redirect "/dashboard"

  # Serve layout to each path
  for p in routes.views
    server.server.get p, (req, res) ->
      if req.cookies.admin == "true" then auth = { admin: true } else auth = {}
      res.render "dashboard/layout.jade", auth

  server.server.get "/views/dashboard/:view", (req, res) ->
    if not utility.param req.params.view, res, "View" then return

    # Fancypathabstractionthingthatisprobablynotthatfancybutheywhynotgg
    if req.params.view.indexOf(":") != -1
      req.params.view = req.params.view.split(":").join "/"

    # Sanitize req.params.view
    # TODO: figure out if this is enough
    if req.params.view.indexOf("..") != -1
      req.params.view = req.params.view.split("..").join ""

    if req.cookies.admin == "true" then auth = { admin: true } else auth = {}

    res.render "dashboard/views/#{req.params.view}.jade", auth

  register null, {}

module.exports = setup
