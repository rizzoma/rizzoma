var requestlib = require("request"),
    Stream = require("stream").Stream,
    utillib = require("util"),
    querystring = require("querystring");

/**
 * Wrapper for new XOAuth2Generator.
 *
 * Usage:
 *
 *     var xoauthgen = createXOAuth2Generator({});
 *     xoauthgen.getToken(function(err, xoauthtoken){
 *         socket.send("AUTH XOAUTH2 " + xoauthtoken);
 *     });
 *
 * @param {Object} options See XOAuth2Generator for details
 * @return {Object}
 */
module.exports.createXOAuth2Generator = function(options){
    return new XOAuth2Generator(options);
};

/**
 * XOAUTH2 access_token generator for Gmail. 
 * Create client ID for web applications in Google API console to use it.
 * See Offline Access for receiving the needed refreshToken for an user
 * https://developers.google.com/accounts/docs/OAuth2WebServer#offline
 *
 * @constructor
 * @param {Object} options Client information for token generation
 * @param {String} options.user User e-mail address
 * @param {String} options.token Existing OAuth2 token
 * @param {String} [options.accessUrl="https://accounts.google.com/o/oauth2/token"] Endpoint for token genration
 * @param {String} options.clientId Client ID value
 * @param {String} options.clientSecret Client secret value
 * @param {String} options.refreshToken Refresh token for an user
 */
function XOAuth2Generator(options){
    Stream.call(this);
    this.options = options || {};

    this.options.accessUrl = this.options.accessUrl || "https://accounts.google.com/o/oauth2/token";

    this.token = this.options.accessToken && this.buildXOAuth2Token(this.options.accessToken) || false;
    this.accessToken = this.token && this.options.accessToken || false;

    this.timeout = this.options.timeout || 0;
}
utillib.inherits(XOAuth2Generator, Stream);

/**
 * Returns or generates (if previous has expired) a XOAuth2 token
 *
 * @param {Function} callback Callback function with error object and token string
 */
XOAuth2Generator.prototype.getToken = function(callback){
    if(this.token && (!this.timeout || this.timeout > Date.now())){
        return callback(null, this.token, this.acessToken);
    }
    this.generateToken(callback);
};

/**
 * Updates token values
 *
 * @param {String} accessToken New access token
 * @param {Number} timeout Access token lifetime in seconds
 */
XOAuth2Generator.prototype.updateToken = function(accessToken, timeout){
    this.token = this.buildXOAuth2Token(accessToken);
    this.accessToken = accessToken;
    this.timeout = timeout && Date.now() + ((Number(timeout) || 0) - 1) * 1000 || 0;

    this.emit("token", {
        user: this.options.user,
        accessToken: accessToken || "",
        timeout: Math.floor(this.timeout/1000)
    });
};

/**
 * Generates a new XOAuth2 token with the credentials provided at initialization
 *
 * @param {Function} callback Callback function with error object and token string
 */
XOAuth2Generator.prototype.generateToken = function(callback){
    var urlOptions = {
            client_id: this.options.clientId || "",
            client_secret: this.options.clientSecret || "",
            refresh_token: this.options.refreshToken,
            grant_type: "refresh_token"
        },
        payload = querystring.stringify(urlOptions);

    requestlib({
            method: "POST",
            url: this.options.accessUrl, 
            body: payload,
            headers: {
                "Content-Type"   : "application/x-www-form-urlencoded",
                "Content-Length" : Buffer.byteLength(payload)
            }
        }, (function(error, response, body){
            var data;

            if(error){
                return callback(error);
            }
            try{
                data = JSON.parse(body.toString());
            }catch(E){
                return callback(E);
            }
            
            if(!data || typeof data != "object"){
                return callback(new Error("Invalid authentication response"));
            }

            if(data.error){
                return callback(data.error);
            }

            if(data.access_token){
                this.updateToken(data.access_token, data.expires_in);
                return callback(null, this.token, this.accessToken);
            }

        }).bind(this));
};

/**
 * Converts an access_token and user id into a base64 encoded XOAuth2 token
 * 
 * @param {String} accessToken Access token string
 * @return {String} Base64 encoded token for IMAP or SMTP login
 */
XOAuth2Generator.prototype.buildXOAuth2Token = function(accessToken){
    var authData = [
        "user=" + (this.options.user || ""),
        "auth=Bearer " + accessToken,
        "",
        ""];
    return new Buffer(authData.join("\x01"), "utf-8").toString("base64");
};