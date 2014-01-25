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

##
## Ad fetching (the heart of the beast) - /api/v1/serve
##
spew = require "spew"
db = require "mongoose"

setup = (options, imports, register) ->

  app = imports["core-express"].server
  filterEngine = require "../../../helpers/filters"

  app.get "/api/v1/filters/countries", (req, res) ->
    if req.query.q == undefined
      res.json filterEngine.getCountries()
    else
      filterEngine.autocompleteCountries req.query.q, (d) ->
        res.json d
      , uniqueIDs: true

  app.get "/api/v1/filters/categories", (req, res) ->
    if req.query.q == undefined
      res.json filterEngine.getCategories()
    else
      filterEngine.autocompleteCategories req.query.q, (d) ->
        res.json d
      , uniqueIDs: true

  app.get "/api/v1/filters/devices", (req, res) ->
    if req.query.q == undefined
      res.json filterEngine.getDevices()
    else
      filterEngine.autocompleteDevices req.query.q, (d) ->
        res.json d
      , uniqueIDs: true

  app.get "/api/v1/filters/manufacturers", (req, res) ->
    if req.query.q == undefined
      res.json filterEngine.getManufacturers()
    else
      filterEngine.autocompleteManufacturers req.query.q, (d) ->
        res.json d
      , uniqueIDs: true

  register null, {}

module.exports = setup
