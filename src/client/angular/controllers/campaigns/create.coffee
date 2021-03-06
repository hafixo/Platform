angular.module("AdefyApp").controller "AdefyCampaignCreateController", ($scope, $location, Campaign, $http, $timeout) ->

  $scope.pricingOptions = ["CPM", "CPC"]
  $scope.bidSysOptions = ["Automatic", "Manual"]

  $scope.categories = []
  $scope.minDailyBudget = 10
  $scope.campaign =
    pricing: "CPM"
    bidSystem: "Automatic"
    networks: "all"
    scheduling: "no"
    devices: []
    countries: []
    category: "Games"

  $http.get("/api/v1/filters/categories").success (list) ->
    $scope.categories = list
    $timeout -> $("#categorySelect select").select2()

  $scope.submit = ->
    $scope.submitted = true
    newCampaign = new Campaign this.campaign
    newCampaign.startDate = new Date(newCampaign.startDate).getTime()
    newCampaign.endDate = new Date(newCampaign.endDate).getTime()

    newCampaign.$save().then(
      -> # success
        $location.path "/campaigns"
      -> #error
        $scope.setNotification "There was an error with your form submission", "error"
    )

  $scope.projectSpend = ->
    if $scope.$parent.me
      funds = $scope.$parent.me.adFunds
    else
      funds = $scope.campaign.dailyBudget

    if $scope.campaign.endDate
      if $scope.campaign.startDate
        startDate = new Date($scope.campaign.startDate).getTime()
      else
        startDate = new Date().getTime()

      endDate = new Date($scope.campaign.endDate).getTime()

      # Get time span in days
      span = (endDate - startDate) / (1000 * 60 * 60 * 24)
      spend = $scope.campaign.dailyBudget * span

      if spend > funds then spend = funds

      spend.toFixed 2
    else
      funds
