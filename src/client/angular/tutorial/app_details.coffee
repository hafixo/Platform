guiders.createGuider
  title: "App Details"
  description: "Here you can see your 24 hour and lifetime metrics, and configure your application."
  buttons: [{ name: "Next" }, { name: "Close" }]
  id: "appDetailsGuider1"
  next: "appDetailsGuider2"
  position: "6"
  overlay: true
  highlight: ".content"
  onClose: ->
    if window.UserService != undefined
      window.UserService.disableTutorial "appDetails"

guiders.createGuider
  title: "Settings & Integration"
  description: "You can configure your app on the settings page, and find links to our SDKs and integration tutorials on the integration page."
  attachTo: ".titlebar.cf.full .menu.full"
  buttons: [{ name: "Check out ads", onclick: guiders.navigate }, { name: "Previous" }, { name: "Close" }]
  id: "appDetailsGuider2"
  position: "6"
  overlay: true
  highlight: ".titlebar.cf.full"
  onNavigate: ->
    if window.UserService != undefined
      window.UserService.disableTutorial "appDetails", ->
        window.location.href = "/ads#guider=adsGuider1"
    else
      window.location.href = "/ads#guider=adsGuider1"
  onClose: ->
    if window.UserService != undefined
      window.UserService.disableTutorial "appDetails"
