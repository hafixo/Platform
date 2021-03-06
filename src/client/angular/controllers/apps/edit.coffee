angular.module("AdefyApp").controller "AdefyAppsEditController", ($scope, $location, $routeParams, AppService, $http, $timeout) ->

  $scope.categories = []
  $scope.pricingModels = ["Any", "CPM", "CPC"]

  $http.get("/api/v1/filters/categories").success (list) ->
    $scope.categories = list
    $timeout -> $("#categorySelect select").select2()

  AppService.getApp $routeParams.id, (app) -> $scope.app = app

  $scope.submit = ->
    $scope.submitted = true

    AppService.updateCachedApp $scope.app.id, $scope.app
    $scope.app.$save().then(
      -> # Success
        $location.path "/apps/#{$scope.app.id}"
      -> # Error
        $scope.setNotification "There was an error with your form submission", "error"
    )

  $scope.form = {}
  $scope.delete = ->
    if $scope.app.name == $scope.form.name
      $scope.app.$delete().then(
        -> # Success
          $location.path "/apps"
        -> # Error
          $scope.setNotification "There was an error with your form submission", "error"
      )

    true
