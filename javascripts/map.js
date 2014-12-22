(function() {
  var BICC, Country,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  BICC = (function() {
    function BICC(element, country, typeObj) {
      this.element = element;
      this.country = country;
      this.showDetailData = __bind(this.showDetailData, this);
      this.worldZoom = __bind(this.worldZoom, this);
      this.search = __bind(this.search, this);
      this.featureStyle = __bind(this.featureStyle, this);
      this.type = typeObj.value;
      this.typeText = typeObj.text;
      this.mapLayer = new L.TileLayer("http://{s}.tiles.mapbox.com/v3/codeformuenster.ino9j865/{z}/{x}/{y}.png", {
        continuousWorld: false,
        noWrap: true
      });
      this.map = new L.Map(this.element, {
        crs: L.CRS.EPSG4326,
        center: [10.1, 5.6],
        zoom: 2
      });
      L.easyButton('fa-globe', this.worldZoom, '', this.map);
      L.easyButton('fa-search', this.search, '', this.map);
      this.conduct_legend = this.country.conductLegendText;
      this.colors = this.country.conductColors;
      this.gmi_colors = ['rgb(255,255,178)', 'rgb(254,204,92)', 'rgb(253,141,60)', 'rgb(240,59,32)', 'rgb(189,0,38)'].reverse();
      this.dsv = d3.dsv(";", "text/plain");
      this.worldLayer = L.geoJson(null, {
        style: this.featureStyle,
        onEachFeature: (function(_this) {
          return function(feature, layer) {
            var popupText;
            popupText = "Country: " + feature.properties.name + " <br/>" + _this.typeText + ": " + _this.conduct_legend[_this.typeValue(feature)];
            layer.bindPopup(popupText);
            return layer.on({
              mouseover: _this.showDetailData,
              popupclose: function(event) {
                return _this.country.locked = false;
              },
              click: function(event) {
                _this.country.locked = false;
                _this.showDetailData(event);
                return _this.country.locked = true;
              }
            });
          };
        })(this)
      });
      this.getData();
    }

    BICC.prototype.featureStyle = function(feature) {
      return {
        fillColor: this.countryColorForFeature(feature),
        weight: 0,
        fillOpacity: 0.8,
        color: "#777",
        weight: 0.6,
        smoothFactor: 0.3
      };
    };

    BICC.prototype.search = function() {
      return this.country.search(!this.country.search());
    };

    BICC.prototype.worldZoom = function() {
      return this.map.setView([38.1, 5.6], 2);
    };

    BICC.prototype.typeValue = function(feature) {
      var data;
      data = this.countryData(feature);
      if (data) {
        return data[this.type];
      } else {
        return "";
      }
    };

    BICC.prototype.searchCountries = function(searchTerm) {
      var layers;
      layers = _.filter(this.dataLayer.getLayers(), function(d) {
        return d.feature.properties.name.match(new RegExp("" + searchTerm, "gi"));
      });
      return layers.map(function(d) {
        return {
          name: d.feature.properties.name,
          layer: d
        };
      });
    };

    BICC.prototype.zoomTo = function(layer) {
      return this.map.fitBounds(layer.getBounds());
    };

    BICC.prototype.countryData = function(feature) {
      return _.findWhere(this.data, {
        iso3_code: feature.properties.iso_a3
      });
    };

    BICC.prototype.countryColorForFeature = function(feature) {
      var value;
      if (this.type !== "gmi") {
        value = this.typeValue(feature);
        if (value) {
          return this.colors[parseInt(value)];
        } else {
          return 'rgb(255,255,255)';
        }
      } else {
        return this.gmi_colors[this.gmi.getQuantile(feature.properties.iso_a3)] || '#ccc';
      }
    };

    BICC.prototype.setType = function(type) {
      if (type == null) {
        type = {};
      }
      this.type = type.value;
      this.typeText = type.text;
      this.map.removeLayer(this.dataLayer);
      this.dataLayer.clearLayers();
      return this.addDataLayer();
    };

    BICC.prototype.addWorldLayerData = function(url) {
      return this.dsv("data/bicc_armsexports_2013.csv", (function(_this) {
        return function(data) {
          return _this.data = data;
        };
      })(this));
    };

    BICC.prototype.addDataLayer = function() {
      this.dataLayer = omnivore.geojson('wgs.geojson', null, this.worldLayer);
      return this.dataLayer.addTo(this.map);
    };

    BICC.prototype.setDetailsForFeature = function(feature) {
      var data, exports;
      data = this.countryData(feature);
      this.country.countryData(data);
      this.country.gmiRank(this.gmi.getRank(data.iso3_code));
      this.country.gmiCountryCount(this.gmi.getCountryCount());
      this.country.countryName(data.country_e);
      this.country.germanArmsExport(data.sum_german_armsexports);
      this.country.germanWeaponsExport(data.sum_german_kweaponsexport);
      exports = _.findWhere(this.exportData, {
        iso3_code: data.iso3_code,
        year: '2013-01-01'
      });
      this.country.exports2013(exports.gesamt);
      return this.country.warWeapons2013(exports.war_weapons);
    };

    BICC.prototype.showDetailData = function(event) {
      if (!this.country.locked) {
        return this.setDetailsForFeature(event.target.feature);
      }
    };

    BICC.prototype.getData = function() {
      return queue().defer(d3.csv, "data/iso_3166_2_countries.csv").defer(d3.csv, "data/nomenklatura.csv").defer(this.dsv, "data/gmi_1990_2013_values.csv").defer(this.dsv, "data/bicc_armsexports_2013.csv").defer(this.dsv, "data/ruex_2000_2013.csv").await((function(_this) {
        return function(error, countries, nomenklatura, gmi, codeOfConduct, exportData) {
          _this.nomenklatura = nomenklatura;
          _this.countryNames = countries;
          _this.data = codeOfConduct;
          _this.exportData = exportData;
          _this.gmi = new GMI(gmi);
          return _this.addDataLayer();
        };
      })(this));
    };

    return BICC;

  })();

  this.GMI = (function() {
    function GMI(data) {
      this.data = data;
      this.gmiValue = __bind(this.gmiValue, this);
      this.year = '2012';
      this.setDomainForYear();
      this.scale = d3.scale.ordinal().domain(this.domain).range(this.getRange());
      this.quantileScale = d3.scale.quantile().domain([1, 150]).range([0, 1, 2, 3, 4]);
    }

    GMI.prototype.setDomainForYear = function() {
      return this.domain = _.sortBy(this.gmiData().map((function(_this) {
        return function(d) {
          return _this.gmiValue(d);
        };
      })(this)), (function(_this) {
        return function(d) {
          return _this.getValueFromGmi(d);
        };
      })(this));
    };

    GMI.prototype.gmiValue = function(d) {
      return d["gmi" + this.year];
    };

    GMI.prototype.getRange = function() {
      var _i, _ref, _results;
      return (function() {
        _results = [];
        for (var _i = _ref = this.gmiData().length; _ref <= 1 ? _i <= 1 : _i >= 1; _ref <= 1 ? _i++ : _i--){ _results.push(_i); }
        return _results;
      }).apply(this);
    };

    GMI.prototype.gmiData = function() {
      return _.reject(this.data, (function(_this) {
        return function(d) {
          return _this.gmiValue(d) === "";
        };
      })(this));
    };

    GMI.prototype.setScale = function() {
      this.setDomainForYear();
      return this.scale.domain(this.domain).range(this.getRange());
    };

    GMI.prototype.getRank = function(country_code, year) {
      var country;
      if (year == null) {
        year = '2012';
      }
      if (year !== this.year) {
        this.year = year;
        this.setScale();
      }
      country = _.findWhere(this.data, {
        iso3_code: country_code
      });
      if (country) {
        return this.scale(this.gmiValue(country));
      }
    };

    GMI.prototype.getQuantile = function(country_code, year) {
      if (year == null) {
        year = '2012';
      }
      if (year !== this.year) {
        this.year = year;
      }
      return this.quantileScale(this.getRank(country_code));
    };

    GMI.prototype.getCountryCount = function() {
      return this.gmiData().length;
    };

    GMI.prototype.getValueFromGmi = function(value) {
      return parseFloat(value.replace(',', '.'));
    };

    return GMI;

  })();

  Country = function() {
    var self, signalFalse;
    self = this;
    self.conductLegendText = ['not considered', 'uncritical', 'possibly critical', 'critical'];
    self.conductColors = ['rgb(255,255,178)', 'rgb(120,168,48)', 'rgb(240,168,0)', 'rgb(177,39,27)'];
    self.gmiRanks = ['no data', '1-30', '31-60', '61-90', '91-120', '>120'];
    self.layers = [
      {
        value: "1",
        text: 'Arms Embargos',
        explanation: 'International obligations: International or Regional Arms Embargoes and Membership in Arms Control Agreements'
      }, {
        value: "2",
        text: 'Human Rights',
        explanation: 'Adherence to Human Rights'
      }, {
        value: "3",
        text: 'Internal Conflict',
        explanation: 'Internal Situation – Stability or Conflict'
      }, {
        value: "4",
        text: 'Regional Security',
        explanation: 'Preservation of regional peace, security and stability'
      }, {
        value: "5",
        text: 'Security of Member States',
        explanation: 'National Security of Member States and Allies'
      }, {
        value: "6",
        text: 'Membership in UN Conventions',
        explanation: 'Membership in Human Rights and Arms Control Conventions'
      }, {
        value: "7",
        text: 'Arms Export Control',
        explanation: 'Arms Export Controls'
      }, {
        value: "8",
        text: 'Military/ Non-military Balance',
        explanation: 'Danger of disproportionate military capacities impairing development'
      }, {
        value: "gmi",
        text: 'GMI',
        explanation: 'The Global Militarization Index (GMI) compares, for example, a country’s military expenditure with its Gross Domestic Product (GDP) and its health expenditure.',
        longExplanation: 'The Global Militarization Index (GMI) compares, for example, a country’s military expenditure with its Gross Domestic Product (GDP) and its health expenditure. It contrasts the total number of military and paramilitary forces in a country with the number of physicians. Finally, it studies the number of heavy weapons available to a country’s armed forces. These and other indicators are used to determine a country’s ranking, which in turn makes it possible to measure the respective level of militarization in comparison to other countries.'
      }
    ];
    self.activeLayer = ko.observable(self.layers[0]);
    self.map = new BICC("map", self, self.activeLayer());
    self.countryName = ko.observable('');
    self.germanArmsExport = ko.observable('0');
    self.germanWeaponsExport = ko.observable('0');
    self.countryReportLink = ko.observable('');
    self.countryData = ko.observable();
    self.armsExports = ko.observable(false);
    self.weaponsExports = ko.observable(false);
    self.gmiRank = ko.observable(0);
    self.gmiCountryCount = ko.observable(0);
    self.searchCountry = ko.observable('');
    self.exports2013 = ko.observable(0);
    self.warWeapons2013 = ko.observable(0);
    self.explanation = ko.observable(self.layers[0].explanation);
    self.search = ko.observable(false);
    self.searchedCountries = ko.dependentObservable(function() {
      var search;
      search = self.searchCountry().toLowerCase();
      if (search) {
        return self.map.searchCountries(search);
      } else {
        return [];
      }
    });
    self.locked = false;
    signalFalse = {
      redActive: false,
      yellowActive: false,
      greenActive: false
    };
    self.armsEmbargo = ko.observable(signalFalse);
    self.humanRights = ko.observable(signalFalse);
    self.internalConflict = ko.observable(signalFalse);
    self.regionalSecurity = ko.observable(signalFalse);
    self.securityMemberStates = ko.observable(signalFalse);
    self.membershipUN = ko.observable(signalFalse);
    self.armsExportControl = ko.observable(signalFalse);
    self.militaryBalance = ko.observable(signalFalse);
    self.countryData.subscribe(function(newValue) {
      if (newValue) {
        self.armsExports(parseInt(self.countryData()["armsexport_yesno"]) === 1 ? true : false);
        self.weaponsExports(parseInt(self.countryData()["kweaponsexport_yesno"]) === 1 ? true : false);
        self.countryReportLink("http://ruestungsexport.info/index.php/database2?page=database2&iso_code=" + (self.countryData()["iso3_code"]));
        self.armsEmbargo({
          redActive: self.redActive("1"),
          yellowActive: self.yellowActive("1"),
          greenActive: self.greenActive("1")
        });
        self.humanRights({
          redActive: self.redActive("2"),
          yellowActive: self.yellowActive("2"),
          greenActive: self.greenActive("2")
        });
        self.internalConflict({
          redActive: self.redActive("3"),
          yellowActive: self.yellowActive("3"),
          greenActive: self.greenActive("3")
        });
        self.regionalSecurity({
          redActive: self.redActive("4"),
          yellowActive: self.yellowActive("4"),
          greenActive: self.greenActive("4")
        });
        self.securityMemberStates({
          redActive: self.redActive("5"),
          yellowActive: self.yellowActive("5"),
          greenActive: self.greenActive("5")
        });
        self.membershipUN({
          redActive: self.redActive("6"),
          yellowActive: self.yellowActive("6"),
          greenActive: self.greenActive("6")
        });
        self.armsExportControl({
          redActive: self.redActive("7"),
          yellowActive: self.yellowActive("7"),
          greenActive: self.greenActive("7")
        });
        return self.militaryBalance({
          redActive: self.redActive("8"),
          yellowActive: self.yellowActive("8"),
          greenActive: self.greenActive("8")
        });
      }
    });
    self.humanRightsLegend = ko.computed(function() {
      return this.conductLegendText[parseInt(this.humanRights())];
    }, self);
    self.gmiRankText = ko.computed(function() {
      return this.gmiRanks[self.gmiRank()];
    }, self);
    self.redActive = function(key) {
      if (parseInt(self.countryData()[key]) === 3) {
        return true;
      } else {
        return false;
      }
    };
    self.yellowActive = function(key) {
      if (parseInt(self.countryData()[key]) === 2) {
        return true;
      } else {
        return false;
      }
    };
    self.greenActive = function(key) {
      if (parseInt(self.countryData()[key]) === 1) {
        return true;
      } else {
        return false;
      }
    };
    self.yesNoCss = function(booleanValue) {
      if (booleanValue) {
        return "green";
      } else {
        return "red";
      }
    };
    self.yesNoText = function(booleanValue) {
      if (booleanValue) {
        return "yes";
      } else {
        return "no";
      }
    };
    self.showLayer = function(layer) {
      self.map.setType(layer);
      return self.activeLayer(layer);
    };
    self.showCurrentExplanation = function(layer) {
      return self.explanation(self.activeLayer().explanation);
    };
    self.showExplanation = function(layer) {
      return self.explanation(layer.explanation);
    };
    self.showDetailedExplanation = function() {
      return self.explanation("");
    };
    self.zoomToCountry = function(feature) {
      self.searchCountry('');
      self.map.zoomTo(feature.layer);
      return self.map.setDetailsForFeature(feature.layer.feature);
    };
    return self;
  };

  this.formatToMillions = function(number) {
    if (number) {
      return "" + ((parseInt(number) / 1000000).toFixed(2)) + " Mio €";
    } else {
      return "";
    }
  };

  $(function() {
    var country;
    country = new Country();
    return ko.applyBindings(country);
  });

}).call(this);
