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

window.AdefyDashboard.controller "AdefyAppsIndexController", ($scope, $location, App) ->

  $scope.apps = []

  # Chart.js options
  $scope.options =
    scaleShowLabels: false
    scaleShowGridLines: false
    scaleLineColor : "rgba(0,0,0,0)"
    pointDot: false

  ##
  ## App listing
  ##
  refreshAppListing = ->
    App.query (apps) ->
      # Calculate CTR, status, and active text
      for app, i in apps

        app.ctr = (app.clicks / app.impressions) * 100
        if isNaN app.ctr then app.ctr = 0

        # fetch chart data here later
        app.chart =
          labels : ["", "", "", "", "", "", ""]
          datasets : [
              fillColor : "rgba(220,220,220,0.5)"
              strokeColor : "rgba(220,220,220,1)"
              pointColor : "rgba(220,220,220,1)"
              pointStrokeColor : "#fff"
              data : [65, 59, 90, 81, 56, 55, 40]
            ,
              fillColor : "rgba(151,187,205,0.5)"
              strokeColor : "rgba(151,187,205,1)"
              pointColor : "rgba(151,187,205,1)"
              pointStrokeColor : "#fff"
              data : [28, 48, 40, 19, 96, 27, 100]
          ]

      $scope.apps = apps

  refreshAppListing()