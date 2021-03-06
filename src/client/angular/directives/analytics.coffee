angular.module("AdefyApp").directive "analytics", ["$http", "$timeout", ($http, $timeout) ->

  template: """
  <div ng-if="graphData != null">
    <div graph
      data="graphData"
      width="{{ width }}"
      height="{{ height }}"
      type="{{ type }}"
      hover="hover"
      legend="{{ legend }}"></div>
  </div>
  <div ng-if="graphData == null" class="graph-nodata">
    <span style="width: {{ width }}px; height: {{ height }}px">
      <h6>No Data</h6>
    </span>
    <div graph
      data="noGraphData"
      width="{{ width }}"
      height="{{ height }}"
      type="line">
    </div>
  </div>
  """
  restrict: "AE"
  scope:
    data: "="
    type: "@"
    width: "@"
    height: "@"
    unit: "@"
    legend: "@"
    hover: "="
    axes: "@"
    stroke: "@"
    interpolation: "@"
    refresh: "=?"
    done: "=?"

  link: (scope, element, attrs) ->
    new AdefyAnalyticsDirective scope, element, attrs, $http, $timeout
]

class AdefyAnalyticsDirective

  colors: null
  _fetchedData: null

  constructor: (@scope, @element, @attrs, @$http, @$timeout) ->
    scope.graphData = null
    scope.noGraphData = @generateEmptyGraphData()

    @initColors()
    @fetchData()

    scope.refresh = =>
      @$timeout =>
        scope.$apply =>
          @fetchData()

  getPalette: -> new Rickshaw.Color.Palette scheme: "munin"

  initColors: ->
    palette = @getPalette()
    @colors =
      earnings: palette.color()
      clicks: palette.color()
      impressions: palette.color()

      # This is an un-used color, simple to force the color palette to cycle
      # once more. We don't like this color :(
      _: palette.color()

      requests: palette.color()
      spent: palette.color()

      User: palette.color()
      Campaign: palette.color()
      Ad: palette.color()
      Publisher: palette.color()

    # Advertiser-specific
    @colors.clicksa = @colors.clicksc = @colors.clicks
    @colors.impressionsa = @colors.impressionsc = @colors.impressions

    # Publisher-specific
    @colors.clicksp = @colors.clicks
    @colors.impressionsp = @colors.impressions

    # Admin-specific
    @colors.users = @colors.user = @colors.User
    @colors.campaigns = @colors.campaign = @colors.Campaign
    @colors.ads = @colors.ad = @colors.Ad
    @colors.publishers = @colors.publisher = @colors.Publisher

  fetchData: ->
    return unless @scope.data

    @_fetchedData = null
    @requestIndividualDataSet(graph, i) for graph, i in @scope.data.graphs

  requestIndividualDataSet: (graph, i) ->
    if graph.prefix != undefined then prefix = graph.prefix
    else prefix = @scope.data.prefix

    if graph.url != undefined then url = "#{graph.url}?"
    else url = "#{prefix}/#{graph.stat}?"

    if graph.from then url += "&from=#{graph.from}"
    if graph.until then url += "&until=#{graph.until}"
    if graph.interval then url += "&interval=#{graph.interval}"

    if graph.total then url += "&total=true"
    else if graph.sum then url += "&sum=#{graph.sum}"

    @$http.get(url).success (data) =>
      if @_fetchedData == null then @_fetchedData = {}

      if graph.total
        if @_fetchedData[graph.stat] == undefined
          @_fetchedData[graph.stat] = []

        @_fetchedData[graph.stat].push { x: i, y: Number data }
      else
        @_fetchedData[graph.stat] = data

      @doneFetching()

  doneFetching: ->
    for graph in @scope.data.graphs
      if @_fetchedData[graph.stat] == undefined then return

    statics = []
    dynamics = []

    tempColorPalette = @getPalette()

    for graph in @scope.data.graphs
      if @_fetchedData[graph.stat].length > 0
        atLeastOneNonZeroPoint = false

        for point in @_fetchedData[graph.stat]
          if point.y != 0
            atLeastOneNonZeroPoint = true
            break

        if atLeastOneNonZeroPoint

          if graph.newcol != true
            if @colors[graph.stat] != undefined
              color = @colors[graph.stat]
            else if @colors[graph.stat.split(":")[0]] != undefined 
              color = @colors[graph.stat.split(":")[0]]
          else
            color = tempColorPalette.color()

          statics.push
            name: graph.name
            color: color
            y: graph.y

          dynamics.push @_fetchedData[graph.stat]

    if statics.length > 0
      @scope.graphData =
        static: statics
        dynamic: dynamics
        axes: @scope.data.axes

    if @scope.done then @scope.done @scope.graphData

  generateEmptyGraphData: ->
    palette = @getPalette()
    if @scope.data and @scope.data.axes then axes = @scope.data.axes
    else axes = {}

    data = static: [], dynamic: []

    # Generate X coords
    startX = new Date().getTime()
    xcoords = []

    for i in [0...Math.ceil(Math.random() * 20) + 30]
      xcoords.push startX -= (Math.round(Math.random() * 10) * 60000)

    xcoords.sort (a, b) -> a - b
    mainStartY = Math.round(Math.random() * 100) + 300

    for i in [0...Math.ceil(Math.random() * 2) + 1]
      data.static.push
        name: i
        color: palette.color()

      startY = mainStartY + ((Math.ceil(Math.random() * 50)) - 10)
      points = []

      for x in xcoords
        points.push
          x: x
          y: startY += Math.round(Math.random() * 50) * (1 - Math.round(Math.random() * 2))

      data.dynamic.push points

    data
