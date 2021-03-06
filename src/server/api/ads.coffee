spew = require "spew"
db = require "mongoose"
async = require "async"
_ = require "lodash"
APIBase = require "./base"
aem = require "../helpers/aem"

class APIAds extends APIBase

  constructor: (@app) ->
    super model: "Ad", populate: ["campaigns.campaign"]
    @registerRoutes()

  ###
  # Creates a new ad model with the provided options
  #
  # @param [Object] options
  # @param [ObjectId] owner
  # @return [Campaign] model
  ###
  createNewAd: (options, owner) ->
    db.model("Ad")
      owner: owner
      name: options.name
      campaigns: []

  ###
  # Register our routes on an express server
  #
  ###
  registerRoutes: ->

    ###
    # POST /api/v1/ads
    #   Create an ad, expects "name" in url and req.cookies.user to be valid
    # @qparam [String] name
    # @response [Object] Ad returns a new Ad object
    # @example
    #   $.ajax method: "POST",
    #          url: "/api/v1/ads",
    #          data:
    #            name: "AwesomeAd"
    ###
    @app.post "/api/v1/ads", @apiLogin, (req, res) =>
      return unless aem.param req.body.name, res, "Ad name"

      newAd = @createNewAd req.body, req.user.id
      newAd.validate (err) ->
        return aem.send res, "400:validate", error: err if err

        newAd.save()
        res.json 200, newAd.toAnonAPI()

    ###
    # POST /api/v1/ads/:id/:creative/activate
    #   Activates an ad creative
    # @param [ID] id
    # @param [Creative] creative
    # @example
    #   $.ajax method: "POST",
    #          url: "/api/v1/ads/U1FyJtQHy8S5nfZvmfyjDPt3/native/activate"
    ###
    @app.post "/api/v1/ads/:id/:creative/activate", @apiLogin, (req, res) =>
      if req.params.creative != "native" and req.params.creative != "organic"
        return aem.send res, "400"

      @queryId req.params.id, res, (ad) ->
        return aem.send res, "404:ad" unless ad
        return aem.send res, "401" if ad.tutorial
        return unless aem.isOwnerOf req.user, ad, res

        return aem.send res, "401", error: "Ad un-approved" if ad.status != 2

        ad.setCreativeActive req.params.creative, true
        ad.save()
        res.json 200, ad.toAnonAPI()

    ###
    # POST /api/v1/ads/:id/:creative/deactivate
    #   Deactivates an ad creative
    # @param [ID] id
    # @param [Creative] creative
    # @example
    #   $.ajax method: "POST",
    #          url: "/api/v1/ads/U1FyJtQHy8S5nfZvmfyjDPt3/native/deactivate"
    ###
    @app.post "/api/v1/ads/:id/:creative/deactivate", @apiLogin, (req, res) =>
      if req.params.creative != "native" and req.params.creative != "organic"
        return aem.send res, "400"

      @queryId req.params.id, res, (ad) ->
        return aem.send res, "404:ad" unless ad
        return aem.send res, "401" if ad.tutorial
        return unless aem.isOwnerOf req.user, ad, res

        ad.setCreativeActive req.params.creative, false
        ad.save()
        res.json 200, ad.toAnonAPI()

    ###
    # POST /api/v1/ads/:id
    #   Updates an existing Ad by :id
    # @param [ID] id
    # @qparam [Object] native
    # @qparam [Object] organic
    # @response [Object] Ad returns an updated Ad object
    # @example
    #   $.ajax method: "POST",
    #          url: "/api/v1/ads/DbVXoSZygP7RtxDjqVupTdI8",
    #          data:
    #            name: "AwesomeAdMkII"
    ###
    @app.post "/api/v1/ads/:id", @apiLogin, (req, res) =>
      @queryId req.params.id, res, (ad) ->
        return aem.send res, "404:ad" unless ad
        return aem.send res, "401" if ad.tutorial
        return unless aem.isOwnerOf req.user, ad, res

        if req.body.native then ad.updateNative req.body.native
        if req.body.organic then ad.updateOrganic req.body.organic

        ad.validate (err) ->
          return aem.send res, "400:validate", error: err if err

          ad.save ->
            ad.fetchCompiledStats (stats) ->
              adData = ad.toAnonAPI()
              adData.stats = stats
              res.json 200, adData

    ###
    # POST /api/v1/ads/:id
    #   Deletes an existing Ad by :id
    # @param [ID] id
    # @example
    #   $.ajax method: "DELETE",
    #          url: "/api/v1/ads/fCf3hGpvM3rVIoDNi09bvMYo"
    ###
    @app.delete "/api/v1/ads/:id", @apiLogin, (req, res) =>
      @queryId req.params.id, res, (ad) ->
        return aem.send res, "404:ad" unless ad
        return aem.send res, "401" if ad.tutorial
        return unless aem.isOwnerOf req.user, ad, res

        ad.removeFromCampaigns ->
          ad.remove ->
            aem.send res, "200:delete"

    ###
    # GET /api/v1/ads
    #   Returns a list of all owned Ads
    # @response [Array<Object>] Ads a list of Ads
    # @example
    #   $.ajax method: "GET",
    #          url: "/api/v1/ads"
    ###
    @app.get "/api/v1/ads", @apiLogin, (req, res) =>
      @queryOwner req.user.id, res, (ads) ->
        return res.json 200, [] if ads.length == 0

        async.map ads, (ad, done) ->
          ad.fetchCompiledStats (adStats) ->

            if ad.campaigns.length == 0
              return done null, _.extend ad.toAnonAPI(), stats: adStats

            async.map ad.campaigns, (campaign, innerDone) ->
              return innerDone(null, null) if campaign.campaign == null

              campaign.campaign.fetchTotalStatsForAd ad, (stats) ->
                campaign.campaign.stats = stats
                innerDone null, campaign
            , (err, campaigns) ->
              ad.campaigns = campaigns
              done err, _.extend ad.toAnonAPI(), stats: adStats

        , (err, ads) ->
          return res.send aem.send res, "500" if err
          res.json ads

    ###
    # GET /api/v1/ads/all
    #   Returns a every available Ad
    # @admin
    # @response [Array<Object>] Ads a list of Ads
    # @example
    #   $.ajax method: "GET",
    #          url: "/api/v1/ads/all"
    ###
    @app.get "/api/v1/ads/all", @apiLogin, (req, res) =>
      return aem.send res, "401" unless req.user.admin

      @queryRaw { populate: ["owner"] }, tutorial: false, res, (ads) ->

        # Attach 24 hour stats to publishers, and return with complete data
        async.map ads, (ad, done) ->
          ad.fetchCompiledStats (stats) ->

            done null, _.extend ad.toAPI(),
              stats: stats
              owner: ad.owner.toAPI()

        , (err, ads) ->
          return res.send aem.send res, "500" if err
          res.json ads

    ###
    # GET /api/v1/ads/:id
    #   Returns an existing Ad by :id
    # @param [ID] id
    # @response [Object] Ad
    # @example
    #   $.ajax method: "GET",
    #          url: "/api/v1/ads/l46Wyehf72ovf1tkDa5Y3ddA"
    ###
    @app.get "/api/v1/ads/:id", @apiLogin, (req, res) =>
      @queryId req.params.id, res, (ad) ->
        return aem.send res, "404:ad" unless ad
        return unless aem.isOwnerOf req.user, ad, res

        ad.fetchCompiledStats (stats) ->
          res.json 200, _.extend ad.toAnonAPI(), stats: stats

    ###
    # POST /api/v1/ads/:id/approve
    #   If an Admin posts this request, the target Ad will be approved
    #   If a regular user posts this request, the target Ad will be pushed for
    #   approval
    # @param [ID] id
    # @example
    #   $.ajax method: "POST",
    #          url: "/api/v1/ads/WaeE4dObsK7ObS2ifntxqrGh/approve"
    ###
    @app.post "/api/v1/ads/:id/approve", @apiLogin, (req, res) =>
      @queryId req.params.id, res, (ad) ->
        return aem.send res, "404:ad" unless ad
        return aem.send res, "401" if ad.tutorial
        return unless aem.isOwnerOf req.user, ad, res

        # If we are admin, approve directly
        if req.user.admin
          ad.approve()
          aemResponse = aem.make "200:approve"
        else
          ad.clearApproval()
          aemResponse = aem.make "200:approve_pending"

        ad.save()
        res.json 200, aemResponse

    ###
    # POST /api/v1/ads/:id/disaprove
    #   Dissaproves an existing Ad
    # @admin
    # @param [ID] id
    # @example
    #   $.ajax method: "POST",
    #          url: "/api/v1/ads/V8graeQTXklkx6AzODYDsDQR/disaprove"
    ###
    @app.post "/api/v1/ads/:id/disaprove", @apiLogin, (req, res) =>
      if not req.user.admin then return aem.send res, "403", error: "Attempted to access protected Ad"

      @queryId req.params.id, res, (ad) ->
        return aem.send res, "404:ad" unless ad
        return aem.send res, "401" if ad.tutorial
        return unless aem.isOwnerOf req.user, ad, res

        ad.disaprove ->
          ad.save()
          aem.send res, "200:disapprove"

module.exports = (app) -> new APIAds app
