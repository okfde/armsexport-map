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
    @gmi_colors = ['rgb(255,255,178)','rgb(254,204,92)','rgb(253,141,60)','rgb(240,59,32)','rgb(189,0,38)'].reverse()
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
    @getData()

  featureStyle: (feature) =>
    {
      fillColor: @countryColorForFeature(feature)
      weight: 0
    }

  typeValue: (feature)->
    data = @countryData(feature)
    if data then data[@type] else ""

  full_country_name: (name) ->
    name.split(",").reverse().join(" ").trim()

  first_country_name_part: (name) ->
    name.split(",").shift()

  country_iso_from_name: (name) ->
    iso_2_code = @country_iso_2_code(@full_country_name(name))
    unless iso_2_code
      iso_2_code = @country_iso_2_code(@first_country_name_part(name))
    country = _.findWhere(@countryNames, { iso_2_code: iso_2_code } )
    if country then country.iso_3_code else ""

  country_iso_2_code: (name) ->
    country = _.findWhere(@nomenklatura, { name: name })
    if country
      unless country.acronym
        country = _.findWhere(@nomenklatura, { name: country.canonical } )
      if country then country.acronym else ""
    else
      ""

  countryData: (feature) ->
    _.findWhere(@data, { iso3_code: @country_iso_from_name(feature.properties.name) } )

  countryColorForFeature: (feature)->
    unless @type == "gmi"
      value = @typeValue(feature)
      if value then @colors[parseInt(value)] else 'rgb(255,255,255)'
    else
      iso_3_code = @country_iso_from_name(feature.properties.name)
      @gmi_colors[@gmi.getQuantile(iso_3_code)] || '#ccc'

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

  addDataLayer: ->
    @dataLayer = omnivore.topojson('world-topo.json', null, @worldLayer)
    @dataLayer.addTo(@map)

  showDetailData: (event) =>
    unless @country.locked
      feature = event.target.feature
      data = @countryData(feature)
      @country.gmiRank(@gmi.getRank(data.iso3_code))
      @country.countryData(data)
      @country.countryName(feature.properties.name)
      @country.germanArmsExport(data.sum_german_armsexports)
      @country.countryReport(data["link country report/laenderportrait"])
      @dsv "data/ruex_2000_2013.csv", (data) ->
        exports = _.where(data, { country_e: feature.properties.name } )
        # import d3 barchart add barchart
  getData: ->
    queue()
      .defer(d3.csv, "data/iso_3166_2_countries.csv")
      .defer(d3.csv, "data/nomenklatura.csv")
      .defer(@dsv, "data/gmi_1990_2013_values.csv")
      .defer(@dsv, "data/bicc_armsexports_2013.csv")
      .await( (error, countries, nomenklatura, gmi, codeOfConduct) =>
        @nomenklatura = nomenklatura
        @countryNames = countries
        @data = codeOfConduct
        @gmi = new GMI(gmi)
        @addDataLayer()
      )

class @GMI
  constructor: (@data) ->
    @year = '2012'
    @setDomainForYear()
    @scale = d3.scale.ordinal().domain(@domain).range(@getRange())
    @quantileScale = d3.scale.quantile().domain([1,150]).range([0,1,2,3,4])

  setDomainForYear: ->
    @domain = _.sortBy(@gmiData().map( (d) => @gmiValue(d) ), (d) => @getValueFromGmi(d))

  gmiValue: (d) =>
    d["gmi#{@year}"]

  getRange: ->
    [@gmiData().length..1]

  gmiData: ->
    _.reject(@data, (d) => @gmiValue(d) is "")
  setScale: ->
    @setDomainForYear()
    @scale.domain(@domain).range(@getRange())

  getRank: (country_code, year = '2012') ->
    unless year is @year
      @year = year
      @setScale()
    country = _.findWhere(@data, { iso3_code: country_code } )
    if country
      @scale(@gmiValue(country))

  getQuantile: (country_code, year = '2012') ->
    unless year is @year
      @year = year
    @quantileScale(@getRank(country_code))


  getValueFromGmi: (value) ->
    parseFloat(value.replace(',','.'))

Country = ->
  self = this
  self.conductLegendText = ['not considered','uncritical', 'possibly critical', 'critical']
  self.conductColors = ['rgb(255,255,178)','rgb(120,168,48)','rgb(240,168,0)','rgb(177,39,27)']
  self.gmiRanks = ['no data','1-30','31-60','61-90','91-120','>120']
  self.layers = [
    { value: "gmi", text: 'GMI' }
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
  self.countryData = ko.observable()
  self.armsExports = ko.observable(false)
  self.weaponsExports = ko.observable(false)
  self.gmiRank = ko.observable(0)
  self.locked = false
  signalFalse = {
    redActive: false
    yellowActive: false
    greenActive: false
  }

  self.armsEmbargo = ko.observable(signalFalse)
  self.humanRights= ko.observable(signalFalse)
  self.internalConflict = ko.observable(signalFalse)
  self.regionalSecurity = ko.observable(signalFalse)
  self.securityMemberStates = ko.observable(signalFalse)
  self.membershipUN = ko.observable(signalFalse)
  self.armsExportControl = ko.observable(signalFalse)
  self.militaryBalance = ko.observable(signalFalse)

  self.countryData.subscribe( (newValue) ->
    if newValue
      self.armsExports(if parseInt(self.countryData()["armsexport_yesno"]) == 1 then true else false)
      self.weaponsExports(if parseInt(self.countryData()["kweaponsexport_yesno"]) == 1 then true else false)
      self.armsEmbargo({
        redActive: self.redActive("1")
        yellowActive: self.yellowActive("1")
        greenActive: self.greenActive("1")
      })
      self.humanRights({
        redActive: self.redActive("2")
        yellowActive: self.yellowActive("2")
        greenActive: self.greenActive("2")
      })
      self.internalConflict({
        redActive: self.redActive("3")
        yellowActive: self.yellowActive("3")
        greenActive: self.greenActive("3")
      })
      self.regionalSecurity({
        redActive: self.redActive("4")
        yellowActive: self.yellowActive("4")
        greenActive: self.greenActive("4")
      })
      self.securityMemberStates({
        redActive: self.redActive("5")
        yellowActive: self.yellowActive("5")
        greenActive: self.greenActive("5")
      })
      self.membershipUN({
        redActive: self.redActive("6")
        yellowActive: self.yellowActive("6")
        greenActive: self.greenActive("6")
      })
      self.armsExportControl({
        redActive: self.redActive("7")
        yellowActive: self.yellowActive("7")
        greenActive: self.greenActive("7")
      })
      self.militaryBalance({
        redActive: self.redActive("8")
        yellowActive: self.yellowActive("8")
        greenActive: self.greenActive("8")
      })
  )

  self.germanArmsExportinMillion = ko.computed( ->
    if this.germanArmsExport
      "#{(parseInt(this.germanArmsExport()) / 1000000).toFixed(2)} Mio €"
    else
      ""
  , self)
  self.humanRightsLegend = ko.computed( ->
    this.conductLegendText[parseInt(this.humanRights())]
  , self)

  self.gmiRankText = ko.computed( ->
    this.gmiRanks[self.gmiRank()]
  , self)

  self.redActive = (key) ->
    if parseInt(self.countryData()[key]) == 3 then true else false

  self.yellowActive = (key) ->
    if parseInt(self.countryData()[key]) == 2 then true else false

  self.greenActive = (key) ->
    if parseInt(self.countryData()[key]) == 1 then true else false

  self.showLayer = (layer) ->
    self.map.setType(layer)
    self.activeLayer(layer)
  self

$ ->
  country = new Country()
  ko.applyBindings(country)
