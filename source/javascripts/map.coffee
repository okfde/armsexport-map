class BICC
  constructor: (@element, typeObj) ->
    @type = typeObj.value
    @typeText = typeObj.text
    @mapLayer = new L.TileLayer("http://{s}.tiles.mapbox.com/v3/codeformuenster.ino9j865/{z}/{x}/{y}.png")
    @map = new L.Map(@element,
        center: [
          38.1, 5.6
        ]
        zoom: 2
    ).addLayer(@mapLayer)
    @colors = ['rgb(255,255,178)','rgb(254,204,92)','rgb(253,141,60)','rgb(227,26,28)']
    @conduct_legend = ['not considered','uncritical', 'possibly critical', 'critical']
    @dsv = d3.dsv(";", "text/plain")
    @worldLayer = L.geoJson(null, {
      style: @featureStyle
      onEachFeature: (feature, layer) =>
        popupText = "Country: #{feature.properties.name} <br/>#{@typeText}: #{@conduct_legend[@typeValue(feature)]}"
        layer.bindPopup(popupText)
        layer.on({
          mouseover: @showDetailData
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
    feature = event.target.feature
    data = @countryData(feature)
    detail_html = "<h2>#{feature.properties.name}</h2><p>#{data.sum_german_armsexports}"
    $('#info').html(detail_html)
    @dsv "data/ruex_2000_2013.csv", (data) ->
      exports = _.where(data, { country_e: feature.properties.name } )
      # import d3 barchart add barchart


$ ->
  map = new BICC("map", {value: "1", text: "Indicator 1"})
  $('#filter #type-filter .indicator').click (e) ->
    e.preventDefault()
    $('#filter #type-filter .indicator.active').removeClass('active')
    $(@).addClass('active')
    map.setType({value: $(this).data('type'), text: $(this).text()})
