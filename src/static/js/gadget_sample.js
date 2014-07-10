initGadget = function(gadgetUrl, divId) {
	gadgets.pubsubrouter.init(function() { return gadgetUrl; });
	var iframeBaseUrl = '/gadgets/';
	var container = shindig.container;
	container.view_ = "default";
	container.gadgets_ = {};
	
	this.divIds = this.divIds || [];
	this.divIds.push(divId);
	container.layoutManager.setGadgetChromeIds(this.divIds);

    var getAdditionalParams = function() {
        return '&wave=1&waveId=hjhghg!hjgjh';
    };

	var generateGadgets = function(metadata) {
		for (var i = 0; i < metadata.gadgets.length; i++) {
		  var gadget = container.createGadget({'specUrl': metadata.gadgets[i].url,
			  'title': metadata.gadgets[i].title, 'userPrefs': metadata.gadgets[i].userPrefs});
		  gadget.setServerBase(iframeBaseUrl);
		  gadget.secureToken = escape(generateSecureToken(gadgetUrl));
		  gadget.getAdditionalParams = getAdditionalParams;
		  container.addGadget(gadget);
		}
		container.renderGadgets();
	};

	requestGadgetMetaData(gadgetUrl, generateGadgets);
};

function requestGadgetMetaData(gadgetUrl, opt_callback) {
	var request = {
	  context: {
		country: "default",
		language: "default",
		view: "default",
		container: "default"
	  },
	  gadgets: [{
		url: gadgetUrl,
		moduleId: 0
	  }]
	};

	sendRequestToServer("/gadgets/metadata", "POST",
		gadgets.json.stringify(request), opt_callback, true);
}

function sendRequestToServer(url, method, opt_postParams, opt_callback, opt_excludeSecurityToken) {
	// TODO: Should re-use the jsoncontainer code somehow
	opt_postParams = opt_postParams || {};
	
	var socialDataPath = document.location.protocol + "//" + document.location.host
    + "/social/rest/samplecontainer/";

	var makeRequestParams = {
	  "CONTENT_TYPE" : "JSON",
	  "METHOD" : method,
	  "POST_DATA" : opt_postParams};

	if (!opt_excludeSecurityToken) {
	  url = socialDataPath + url + "?st=" + gadget.secureToken;
	}

	gadgets.io.makeNonProxiedRequest(url,
	  function(data) {
		data = data.data;
		if (opt_callback) {
			opt_callback(data);
		}
	  },
	  makeRequestParams,
	  "application/javascript"
	);
};

function generateSecureToken(gadgetUrl) {
	// TODO: Use a less silly mechanism of mapping a gadget URL to an appid
	var appId = 0;
	for (var i = 0; i < gadgetUrl.length; i++) {
	  appId += gadgetUrl.charCodeAt(i);
	}
	var fields = ["ownerId111", "viewerId111", appId, "shindig", gadgetUrl, "0", "default"];
	for (var i = 0; i < fields.length; i++) {
	  // escape each field individually, for metachars in URL
	  fields[i] = escape(fields[i]);
	}
	return fields.join(":");
};
  