graphiteInterface = require "../helpers/graphiteInterface"
engineFilters = require "../helpers/filters"
redisInterface = require "../helpers/redisInterface"
redis = redisInterface.main
mongoose = require "mongoose"
spew = require "spew"
_ = require "underscore"
async = require "async"
config = require "../config"

AWS = require "aws-sdk"
AWS.config.update
  accessKeyId: config "s3_config_accessKeyId"
  secretAccessKey: config "s3_config_secretAccessKey"

s3 = new AWS.S3()

generateS3Url = (object) -> "//#{s3Host}/#{getS3Key object}"
getS3Key = (object) ->
  if object.key != undefined
    object.key
  else
    object.split("//#{s3Host}/")[1]

##
## Ad schema
##

schema = new mongoose.Schema

  # Generic per-ad information
  owner: { type: mongoose.Schema.Types.ObjectId, ref: "User" }
  name: String

  native:
    title: { type: String, default: "" }
    description: { type: String, default: "" }
    storeURL: { type: String, default: "" }
    clickURL: { type: String, default: "" }

    iconURL: { type: String, default: "" }
    featureURL: { type: String, default: "" }

    active: { type: Boolean, default: false }

  organic:
    jsSource: { type: String, default: "" }

    notification:
      clickURL: { type: String, default: "" }
      title: { type: String, default: "" }
      description: { type: String, default: "" }
      icon: { type: String, default: "" }

    active: { type: Boolean, default: false }

  # Texture array for creative
  assets: [
    name: String    # Asset name (texture handle)
    buffer: String  # Base64 buffer
    key: String     # S3 asset key
  ]

  version: { type: Number, default: 2 }

  # 0 - Pending
  # 1 - Rejected
  # 2 - Approved
  status: { type: Number, default: 0 }
  tutorial: { type: Boolean, default: false }

  campaigns: [

    # Campaign model
    campaign: { type: mongoose.Schema.Types.ObjectId, ref: "Campaign" }

    # Fine-tunning
    networks: { type: Array, default: [] }

    # Removed relative lists, we'll resort to re-compiling them each time
    # Saves DB space
    # countries: { type: Array, default: [] }
    # devices: { type: Array, default: [] }

    # Non-translated filter lists for nicer client presentation.
    # Note: Matching lists are combined appropriately to yield the proper
    # plainly named compiled lists
    devicesInclude: { type: Array, default: [] }
    devicesExclude: { type: Array, default: [] }
    countriesInclude: { type: Array, default: [] }
    countriesExclude: { type: Array, default: [] }

    # "manual" or "automatic"
    bidSystem: { type: String, default: "" }

    # either bid or max bid, inferred from bidSystem
    bid: { type: Number, default: -1 }

    # example items should not be allowed to get used
    tutorial: { type: Boolean, default: false }
  ]

  ##
  ## LEGACY FIELDS
  ## Keep these on untill all databases are migrated
  ##
  data: { type: String, default: "" }
  url: { type: String, default: "" }
  pushTitle: { type: String, default: "" }
  pushDesc: { type: String, default: "" }
  pushIcon: { type: String, default: "" }
  ##
  ##
  ##

##
## ID and handle generation
##

schema.methods.getGraphiteId = -> "ads.#{@_id}"
schema.methods.getGraphiteCampaignId = (campaignId) ->
  "campaigns.#{campaignId}.ads.#{@_id}"

schema.methods.toAPI = ->
  ret = @toObject()
  ret.id = ret._id.toString()

  if ret.data != undefined and ret.data.length > 0
    try
      ret.data = JSON.parse ret.data

  for i in [0...ret.campaigns.length]
    if ret.campaigns[i].campaign != null
      if ret.campaigns[i].campaign._id != undefined
        ret.campaigns[i].campaign.id = ret.campaigns[i].campaign._id.toString()

      delete ret.campaigns[i].campaign._id
      delete ret.campaigns[i].campaign.__v
      delete ret.campaigns[i].campaign.version
      delete ret.campaigns[i].campaign.owner
      delete ret.campaigns[i].campaign.countries
      delete ret.campaigns[i].campaign.devices

      delete ret.campaigns[i].countries
      delete ret.campaigns[i].devices

      # No idea where this comes from.
      # Todo: Figure this out
      delete ret.campaigns[i]._id

  delete ret._id
  delete ret.__v
  delete ret.version
  ret

schema.methods.toAnonAPI = ->
  ret = @toAPI()
  delete ret.owner
  ret

##
## Approval and status info
##

schema.methods.isApproved = -> @status == 2
schema.methods.approve = -> @status = 2
schema.methods.clearApproval = -> @status = 0
schema.methods.disaprove = (cb) ->
  @status = 1
  @removeFromCampaigns -> if cb then cb()

##
## Creative status
##
schema.methods.isCreativeActive = (creative) ->
  if creative == "native"
    @native.active
  else if creative == "oAd"
    @organic.active
  else
    throw new Error "[Ad isCreativeActive] Unknown creative type: creative"

schema.methods.setCreativeActive = (creative, active) ->
  if creative == "native"
    @native.active = active
  else if creative == "oAd"
    @organic.active = active
  else
    throw new Error "[Ad isCreativeActive] Unknown creative type: creative"

schema.methods.activateNativeCreative = -> @setCreativeActive "native", true
schema.methods.deactivateNativeCreative = -> @setCreativeActive "native", false
schema.methods.activateOrganicCreative = -> @setCreativeActive "organic", true
schema.methods.deactivateOrganicCreative = -> @setCreativeActive "organic", false

##
## Stat fetching
##

# Fetches Spent, Clicks, Impressions and CTR for the past 24 hours, and
# lifetime (both sums) for all campaigns
schema.methods.fetchCompiledStats = (cb) ->
  @fetchTotalStats (localStats) =>
    @fetch24hStats (remoteStats) ->
      cb _.extend localStats, remoteStats

# Fetches redis lifetime stats (sum between campaigns)
schema.methods.fetchTotalStats = (cb) ->

  stats =
    requests: 0
    clicks: 0
    impressions: 0
    spent: 0
    ctr: 0

  if @campaigns.length == 0 then return cb stats

  # Go through and generate a key list
  keys = []
  for campaign in @campaigns
    if campaign.campaign != null
      ref = @getRedisRefForCampaign campaign.campaign

      # Note: The order is important, since we parse by it
      keys.push "#{ref}:requests"
      keys.push "#{ref}:clicks"
      keys.push "#{ref}:impressions"
      keys.push "#{ref}:spent"

  # All campaigns null, known bug
  if keys.length == 0
    spew.warning "Ad campaigns are null ;( Ad id: #{@_id}"
    return cb()

  redis.mget keys, (err, results) ->
    if err
      spew.error err
      return cb stats

    for i in [0...results.length] by 4
      if results[i] != null then stats.requests += Number results[i]
      if results[i + 1] != null then stats.clicks += Number results[i + 1]
      if results[i + 2] != null then stats.impressions += Number results[i + 2]
      if results[i + 3] != null then stats.spent += Number results[i + 3]

    if stats.impressions != 0
      stats.ctr = stats.clicks / stats.impressions

    cb stats

schema.methods.fetch24hStats = (cb) ->
  remoteStats =
    impressions24h: 0
    clicks24h: 0
    ctr24h: 0
    spent24h: 0

  if @campaigns.length == 0 then return cb remoteStats

  query = graphiteInterface.query()

  for campaign in @campaigns
    if campaign.campaign._id == undefined then campaignId = campaign.campaign
    else campaignId = campaign.campaign._id

    ref = @getGraphiteCampaignId campaignId

    query.addStatCountTarget "#{ref}.impressions", "summarize", "24hours"
    query.addStatCountTarget "#{ref}.clicks", "summarize", "24hours"
    query.addStatCountTarget "#{ref}.earnings", "summarize", "24hours"
    query.addStatCountTarget "#{ref}.requests", "summarize", "24hours"

  query.exec (data) ->
    for entry in data

      # Extract data name
      target = entry.target.split(",").join(".").split(".")[6]

      for point in entry.datapoints
        if point[0] != null
          remoteStats["#{target}24h"] += Number point[0]

    if remoteStats.impressions24h != 0
      remoteStats.ctr24h = remoteStats.clicks24h / remoteStats.impressions24h

    cb remoteStats

# Fetch verbose stat data
schema.methods.fetchStatGraphData = (options, cb) ->
  matches = []

  for campaign in @campaigns
    if campaign.campaign._id == undefined then campaignId = campaign.campaign
    else campaignId = campaign.campaign._id

    matches.push "#{@getGraphiteCampaignId campaignId}.#{options.stat}"

  delete options.stat
  options.multipleSeries = matches
  graphiteInterface.makeAnalyticsQuery options, cb

##
## Campaign operations
##

# Go through our campaigns, and remove ourselves from each
# Expects campaigns field to be populated!
schema.methods.removeFromCampaigns = (cb) ->

  count = @campaigns.length
  if count == 0 and cb then return cb()

  doneCb = =>
    if count == 1

      # Clear our campaign list
      @campaigns = []
      @save()

      if cb then cb()
    else count--

  for c in @campaigns
    c.campaign.removeAd @, ->
      c.save()
      doneCb()

# Creates a campaign entry. Use this before clearing or setting campaign
# references!
schema.methods.registerCampaignParticipation = (campaign) ->
  @campaigns.push
    campaign: campaign._id

    countries: campaign.countries
    networks: campaign.networks
    devices: campaign.devices

    bidSystem: campaign.bidSystem
    bid: campaign.bid

# Clear campaign entry, to be used after campaign references are cleared!
schema.methods.voidCampaignParticipation = (campaign) ->
  if campaign._id != undefined then id = campaign._id
  else id = campaign.id

  for c, i in @campaigns
    cId = c.campaign._id or c.campaign.id or c.campaign

    if "#{cId}" == "#{id}"
      @campaigns.splice i, 1
      break

# Return array of campaign documents the ad is a part of
#
# @param [String, Ad] adId
# @param [Method] callback
# @return [Array<Campaigns>]
schema.statics.getCampaigns = (adId, cb) ->

  # Get ad id if needed
  if typeof adId == "object"
    if adId.id != undefined then adId = cId.id
    else if adId._id != undefined then adId = cId._id
    else
      spew.error "Couldn't fech campaigns, no ad id: #{JSON.stringify adId}"
      cb []

  @findById(adId).populate("campaigns").exec (err, ad) ->
    if err
      spew.error err
      cb []
    else cb ad.campaigns

##
## Saving/update utility methods
##

# Helper to prepare organic JS object source for shipping. Returns null if src
# is not stringifiable
#
# @param [Object] src raw JS object source
# @return [String] JSON stringified source
schema.methods.prepareOrganicSource = (src) ->
  if src.type == undefined then src.type = "flat_template"
  JSON = null

  try
    JSON = JSON.stringify src

  JSON

# Update organic ad notification
#
# @param [Object] data
schema.methods.updateOrganicNotification = (data) ->
  if data.clickURL != undefined
    @organic.notification.clickURL = data.clickURL

  if data.title != undefined
    @organic.notification.title = data.title

  if data.description != undefined
    @organic.notification.description = data.description

  # Generate new icon url, and only update if it is new
  if data.icon != undefined
    newIconURL = generateS3Url data.icon

    if newIconURL != @organic.notification.icon
      @organic.notification.icon = newIconURL
      @updateAsset "push-icon", "", getS3Key newIconURL

# Update asset entry; if it doesn't already exist, a new entry is created
#
# @param [String] name
# @param [String] buffer
# @param [String] key
schema.methods.updateAsset = (name, buffer, key) ->
  asset = name: name, buffer: buffer, key: key

  for a, i in @assets
    if a.name == name
      @assets[i] = asset
      return

  @assets.push asset

# Update organic creative with raw data (handles icon asset managment)
#
# @param [Object] data
schema.methods.updateOrganic = (data) ->
  if data.jsSource
    @organic.jsSource = @prepareOrganicSource data.jsSource

  if data.notification then @updateOrganicNotification data.notification

# Update native creative with raw data
schema.methods.updateNative = (data) ->

  if data.title != undefined then @native.title = data.title
  if data.description != undefined then @native.description = data.description
  if data.storeURL != undefined then @native.storeURL = data.storeURL
  if data.clickURL != undefined then @native.clickURL = data.clickURL

  # S3 assets
  if data.iconURL != undefined
    @native.iconURL = generateS3Url data.iconURL

  if data.featureURL != undefined
    @native.featureURL = generateS3Url data.featureURL

##
##
## Redis reference management
##
##

## Top-level reference management

# Remove redis keys and values referencing us as belonging to a campaign.
# This is called by the campaign when removing us! So we must not modify the
# campaign itself.
#
# @param [Campaign] campaign
# @param [Method] cb
schema.methods.clearCampaignReferences = (campaign, cb) ->
  ref = @getRedisRefForCampaign campaign

  @clearRedisFilters @getCompiledFetchData(campaign), ref, ->
    redis.del ref, -> if cb then cb()

# The opposite of clearCampaignReferences, this creates references for the
# supplied campaign. It must already be in our campaign list, and it must
# be active!
#
# @param [Campaign] campaign
schema.methods.createCampaignReferences = (campaign, cb) ->
  if @tutorial then return cb()
  if not campaign.active then return cb()

  ref = @getRedisRefForCampaign campaign
  fetchData = @getCompiledFetchData campaign

  @createRedisFilters fetchData, ref, ->

    bidSystem = fetchData.bidSystem
    bid = fetchData.bid
    pricing = fetchData.pricing

    # Now fill out our data
    redis.set "#{ref}:bidSystem", bidSystem
    redis.set "#{ref}:bid", bid
    redis.set "#{ref}:requests", 0
    redis.set "#{ref}:impressions", 0
    redis.set "#{ref}:clicks", 0
    redis.set "#{ref}:spent", 0
    redis.set "#{ref}:pricing", pricing

    if cb then cb()

## Redis helpers

# Generate our handle, to be inserted into all redis structures
#
# @param [Campaign] campaign
# @return [String] ref
schema.methods.getRedisRefForCampaign = (campaign) ->
  if campaign.owner == undefined then ownerId = campaign
  else if campaign.owner._id == undefined then ownerId = campaign.owner
  else ownerId = campaign.owner._id

  "campaignAd:#{campaign._id}:#{@_id}:#{ownerId}"

schema.methods.getRedisRef = -> "ads:#{@_id}"

# Fetch final targeting filters (country, network, etc) and bid info for
# campaign
#
# @param [Campaign] campaign
# @return [Object] data compiled set of filter arrays
schema.methods.getCompiledFetchData = (campaign) ->

  includes = campaign.countriesInclude
  excludes = campaign.countriesExclude
  countries = engineFilters.countries.translateInput includes, excludes

  includes = campaign.devicesInclude
  excludes = campaign.devicesExclude
  devices = engineFilters.devices.translateInput includes, excludes

  compiledData =
    countries: countries
    networks: campaign.networks
    devices: devices
    bid: campaign.bid
    bidSystem: campaign.bidSystem
    pricing: campaign.pricing
    category: campaign.category

  # For now, disallow ad-level settings
  ###
  for c in @campaigns
    if c.campaign != undefined
      if c.campaign == campaign._id

        if c.countries.length > 0 then compiledData.countries = c.countries
        if c.networks.length > 0 then compiledData.networks = c.networks
        if c.devices.length > 0 then compiledData.devices = c.devices

        if c.bid >= 0 then compiledData.bid = c.bid
        if c.bidSystem.length > 0 then compiledData.bidSystem = c.bidSystem

        break
  ###

  compiledData

# Generate final keys for target filters (each country, platform, etc)
#
# @param [Object] data targeting filters to build keys from
# @return [Object] sets
schema.methods.buildRedisKeySets = (data) ->
  baseKey = "#{data.pricing}:#{data.category}"

  sets =
    countrySets: []
    deviceSets: []
    networkSets: []

  for country in data.countries
    sets.countrySets.push "country:#{country}"
  for device in data.devices
    sets.deviceSets.push "#{baseKey}:device:#{device}"
  for network in data.networks
    sets.networkSets.push "#{baseKey}:network:#{network}"

  sets

## Actual redis filter manipulation

# Clear redis targeting/ad fetch keys
#
# @param [Object] fetchData compiled filter sets
# @param [String] ref our own redis reference
# @param [Method] cb
schema.methods.clearRedisFilters = (data, ref, cb) ->
  sets = @buildRedisKeySets data

  redis.srem country, 0, ref for country in sets.countrySets
  redis.srem device, 0, ref for device in sets.deviceSets
  redis.srem network, 0, ref for network in sets.networkSets

  if cb then cb()

# Create redis targeting/ad fetch keys
#
# @param [Object] fetchData compiled filter sets
# @param [String] ref our own redis reference
# @param [Method] cb
schema.methods.createRedisFilters = (data, ref, cb) ->
  sets = @buildRedisKeySets data

  redis.sadd country, ref for country in sets.countrySets
  redis.sadd device, ref for device in sets.deviceSets
  redis.sadd network, ref for network in sets.networkSets

  if cb then cb()

schema.methods.createRedisStruture = (cb) ->
  performRedisRefresh = =>

    # Store ad formats
    adData = organic: @organic, native: @native

    redis.set @getRedisRef(), JSON.stringify(adData), (err) ->
      if err then spew.error err
      if cb then cb()

  # Go through and renew assets if needed, otherwise perform a normal refresh
  for asset in @assets
    if asset.buffer.length == 0
      return @fetchAssetsFromS3 => performRedisRefresh -> cb()

  performRedisRefresh -> cb()

schema.methods.fetchAssetsFromS3 = (finalCb) ->
  if @assets.length == 0 then return finalCb()

  async.each @assets, (asset, cb) ->
    if asset.buffer.length > 0 then return cb()

    s3.getObject
      Bucket: "adefyplatformmain"
      Key: asset.key
    , (err, data) ->

      if err
        spew.error err
      else
        asset.buffer = new Buffer(data.Body).toString "base64"

      cb()
  , -> finalCb()

# Rebuild our redis structures
schema.pre "save", (next) ->
  @fetchAssetsFromS3 =>
    @createRedisStruture ->
      next()

schema.path("data").validate (value) ->
  try
    if (value)
      hash = JSON.parse(value)
      if hash.min < 16
        return false
    return true
  catch e
    spew.error e
    false

mongoose.model "Ad", schema
