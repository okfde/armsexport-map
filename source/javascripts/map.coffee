class BICC
  constructor: (@element, @country, typeObj) ->
    @type = typeObj.value
    @typeText = typeObj.text
    @mapLayer = new L.TileLayer("http://{s}.tiles.mapbox.com/v3/codeformuenster.ino9j865/{z}/{x}/{y}.png")
    @map = new L.Map(@element,
        center: [
          38.1, 5.6
        ]
        zoom: 2
    ).addLayer(@mapLayer)
    @conduct_legend = @country.conductLegendText
    @colors = @country.conductColors
    @dsv = d3.dsv(";", "text/plain")
    @worldLayer = L.geoJson(null, {
      style: @featureStyle
      onEachFeature: (feature, layer) =>
        popupText = "Country: #{feature.properties.name} <br/>#{@typeText}: #{@conduct_legend[@typeValue(feature)]}"
        layer.bindPopup(popupText)
        layer.on({
          mouseover: @showDetailData
          popupclose: (event) =>
            @country.locked = false
          click: (event) =>
            @country.locked = false
            @showDetailData(event)
            @country.locked = true
        })
    })
    @addWorldLayerData()

  featureStyle: (feature) =>
    {
      fillColor: @countryColorForFeature(feature)
      weight: 0
    }

  typeValue: (feature)->
    data = @countryData(feature)
    if data then data[@type] else ""

  countryData: (feature) ->
    _.findWhere(@data, { country_e: feature.properties.name } )

  countryColorForFeature: (feature)->
    value = @typeValue(feature)
    if value then @colors[parseInt(value)] else 'rgb(255,255,255)'

  setType: (type = {}) ->
    @type = type.value
    @typeText = type.text
    # toDo: just update style, or refresh all features no need for removal
    @map.removeLayer(@dataLayer)
    @dataLayer.clearLayers()
    @addDataLayer()

  addWorldLayerData: (url) ->
    @dsv "data/bicc_armsexports_2013.csv", (data) =>
      @data = data
      @addDataLayer()

  addDataLayer: ->
    @dataLayer = omnivore.topojson('world-topo.json', null, @worldLayer)
    @dataLayer.addTo(@map)

  showDetailData: (event) =>
    unless @country.locked
      feature = event.target.feature
      data = @countryData(feature)
      @country.countryName(feature.properties.name)
      @country.germanArmsExport(data.sum_german_armsexports)
      @country.countryReport(data["link country report/laenderportrait"])
      @country.armsEmbargos(data["1"])
      @country.humanRights(data["2"])
      @dsv "data/ruex_2000_2013.csv", (data) ->
        exports = _.where(data, { country_e: feature.properties.name } )
        # import d3 barchart add barchart

Country = ->
  self = this
  self.conductLegendText = ['not considered','uncritical', 'possibly critical', 'critical']
  self.conductColors = ['rgb(255,255,178)','rgb(120,168,48)','rgb(240,168,0)','rgb(177,39,27)']
  self.layers = [
    { value: "1", text: 'Arms Embargos' }
    { value: "2", text: 'Human Rights' }
    { value: "3", text: 'Internal Conflict' }
    { value: "4", text: 'Regional Security' }
    { value: "5", text: 'Security of Member States' }
    { value: "6", text: 'membership in un conventions' }
    { value: "7", text: 'arms export control' }
    { value: "8", text: 'military/ non-military balance' }
  ]
  self.activeLayer = ko.observable(self.layers[0])
  self.map = new BICC("map", self, self.activeLayer())
  self.countryName = ko.observable('')
  self.germanArmsExport = ko.observable('0')
  self.countryReport = ko.observable('')
  self.armsEmbargos = ko.observable('')
  self.humanRights = ko.observable('')
  self.locked = false
  self.germanArmsExportinMillion = ko.computed( ->
    if this.germanArmsExport
      "#{(parseInt(this.germanArmsExport()) / 1000000).toFixed(2)} Mio €"
    else
      ""
  , this)
  self.armsEmbaroLegend = ko.computed( ->
    this.conductLegendText[parseInt(this.armsEmbargos())]
  , this)
  self.humanRightsLegend = ko.computed( ->
    this.conductLegendText[parseInt(this.humanRights())]
  , this)

  self.showLayer = (layer) ->
    self.map.setType(layer)
    self.activeLayer(layer)
  self

$ ->
  country = new Country()
  ko.applyBindings(country)
