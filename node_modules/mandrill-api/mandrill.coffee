
https = require 'https'

OPTS = {
    host:   'mandrillapp.com',
    port:   443,
    prefix: '/api/1.0/',
    method: 'POST',
    headers: {'Content-Type': 'application/json', 'User-Agent': 'Mandrill-Node/1.0.5'}
}

class exports.Mandrill
    constructor: (@apikey=null, @debug=false) ->
        @templates = new Templates(this)
        @users = new Users(this)
        @rejects = new Rejects(this)
        @tags = new Tags(this)
        @messages = new Messages(this)
        @urls = new Urls(this)
        @webhooks = new Webhooks(this)
        @senders = new Senders(this)

        if @apikey == null then @apikey = process.env['MANDRILL_APIKEY']

    call: (uri, params={}, onresult, onerror) ->
        params.key = @apikey
        params = JSON.stringify(params)

        if @debug then console.log("Mandrill: Opening request to https://#{OPTS.host}#{OPTS.prefix}#{uri}.json")
        OPTS.path = "#{OPTS.prefix}#{uri}.json"
        OPTS.headers['Content-Length'] = params.length
        req = https.request(OPTS, (res) =>
            res.setEncoding('utf8')
            json = ''
            res.on('data', (d) =>
                json += d
            )

            res.on('end', =>
                try
                    json = JSON.parse(json)
                catch e
                    json = {status: 'error', name: 'GeneralError', message: e}
                
                json ?= {status: 'error', name: 'GeneralError', message: 'An unexpected error occurred'}
                if res.statusCode != 200
                    if onerror then onerror(json) else @onerror(json)
                else
                    if onresult then onresult(json)
            )
        )
        req.write(params)
        req.end()
        req.on('error', (e) =>
            if onerror then onerror(e) else @onerror({status: 'error', name: 'GeneralError', message: e})
        )

        return null

    onerror: (err) ->
        throw {name: err.name, message: err.message, toString: -> "#{err.name}: #{err.message}"}

class Templates
    constructor: (@master) ->


    ###
    Add a new template
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} name the name for the new template - must be unique
    @option params {String} code the HTML code for the template with mc:edit attributes for the editable elements
    @option params {Boolean} publish set to false to add a draft template without publishing
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    add: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["publish"] ?= true

        @master.call('templates/add', params, onsuccess, onerror)

    ###
    Get the information for an existing template
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} name the name of an existing template
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    info: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('templates/info', params, onsuccess, onerror)

    ###
    Update the code for an existing template
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} name the name of an existing template
    @option params {String} code the new code for the template
    @option params {Boolean} publish set to false to update the draft version of the template without publishing
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    update: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["publish"] ?= true

        @master.call('templates/update', params, onsuccess, onerror)

    ###
    Publish the content for the template. Any new messages sent using this template will start using the content that was previously in draft.
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} name the name of an existing template
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    publish: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('templates/publish', params, onsuccess, onerror)

    ###
    Delete a template
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} name the name of an existing template
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    delete: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('templates/delete', params, onsuccess, onerror)

    ###
    Return a list of all the templates available to this user
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    list: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('templates/list', params, onsuccess, onerror)

    ###
    Return the recent history (hourly stats for the last 30 days) for a template
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} name the name of an existing template
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    timeSeries: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('templates/time-series', params, onsuccess, onerror)

    ###
    Inject content and optionally merge fields into a template, returning the HTML that results
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} template_name the name of a template that exists in the user's account
    @option params {Array} template_content an array of template content to render.  Each item in the array should be a struct with two keys - name: the name of the content block to set the content for, and content: the actual content to put into the block
         - template_content[] {Object} the injection of a single piece of content into a single editable region
             - name {String} the name of the mc:edit editable region to inject into
             - content {String} the content to inject
    @option params {Array} merge_vars optional merge variables to use for injecting merge field content.  If this is not provided, no merge fields will be replaced.
         - merge_vars[] {Object} a single merge variable
             - name {String} the merge variable's name. Merge variable names are case-insensitive and may not start with _
             - content {String} the merge variable's content
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    render: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["merge_vars"] ?= null

        @master.call('templates/render', params, onsuccess, onerror)
class Users
    constructor: (@master) ->


    ###
    Return the information about the API-connected user
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    info: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('users/info', params, onsuccess, onerror)

    ###
    Validate an API key and respond to a ping
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    ping: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('users/ping', params, onsuccess, onerror)

    ###
    Validate an API key and respond to a ping (anal JSON parser version)
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    ping2: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('users/ping2', params, onsuccess, onerror)

    ###
    Return the senders that have tried to use this account, both verified and unverified
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    senders: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('users/senders', params, onsuccess, onerror)
class Rejects
    constructor: (@master) ->


    ###
    Retrieves your email rejection blacklist. You can provide an email
address to limit the results. Returns up to 1000 results. By default,
entries that have expired are excluded from the results; set
include_expired to true to include them.
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} email an optional email address to search by
    @option params {Boolean} include_expired whether to include rejections that have already expired.
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    list: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["email"] ?= null
        params["include_expired"] ?= false

        @master.call('rejects/list', params, onsuccess, onerror)

    ###
    Deletes an email rejection. There is no limit to how many rejections
you can remove from your blacklist, but keep in mind that each deletion
has an affect on your reputation.
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} email an email address
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    delete: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('rejects/delete', params, onsuccess, onerror)
class Tags
    constructor: (@master) ->


    ###
    Return all of the user-defined tag information
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    list: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('tags/list', params, onsuccess, onerror)

    ###
    Return more detailed information about a single tag, including aggregates of recent stats
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} tag an existing tag name
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    info: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('tags/info', params, onsuccess, onerror)

    ###
    Return the recent history (hourly stats for the last 30 days) for a tag
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} tag an existing tag name
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    timeSeries: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('tags/time-series', params, onsuccess, onerror)

    ###
    Return the recent history (hourly stats for the last 30 days) for all tags
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    allTimeSeries: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('tags/all-time-series', params, onsuccess, onerror)
class Messages
    constructor: (@master) ->


    ###
    Send a new transactional message through Mandrill
    @param {Object} params the hash of the parameters to pass to the request
    @option params {Struct} message the information on the message to send
         - html {String} the full HTML content to be sent
         - text {String} optional full text content to be sent
         - subject {String} the message subject
         - from_email {String} the sender email address.
         - from_name {String} optional from name to be used
         - to {Array} an array of recipient information.
             - to[] {Object} a single recipient's information.
                 - email {String} the email address of the recipient
                 - name {String} the optional display name to use for the recipient
         - headers {Object} optional extra headers to add to the message (currently only Reply-To and X-* headers are allowed)
         - track_opens {Boolean} whether or not to turn on open tracking for the message
         - track_clicks {Boolean} whether or not to turn on click tracking for the message
         - auto_text {Boolean} whether or not to automatically generate a text part for messages that are not given text
         - url_strip_qs {Boolean} whether or not to strip the query string from URLs when aggregating tracked URL data
         - preserve_recipients {Boolean} whether or not to expose all recipients in to "To" header for each email
         - bcc_address {String} an optional address to receive an exact copy of each recipient's email
         - merge {Boolean} whether to evaluate merge tags in the message. Will automatically be set to true if either merge_vars or global_merge_vars are provided.
         - global_merge_vars {Array} global merge variables to use for all recipients. You can override these per recipient.
             - global_merge_vars[] {Object} a single global merge variable
                 - name {String} the global merge variable's name. Merge variable names are case-insensitive and may not start with _
                 - content {String} the global merge variable's content
         - merge_vars {Array} per-recipient merge variables, which override global merge variables with the same name.
             - merge_vars[] {Object} per-recipient merge variables
                 - rcpt {String} the email address of the recipient that the merge variables should apply to
                 - vars {Array} the recipient's merge variables
                     - vars[] {Object} a single merge variable
                         - name {String} the merge variable's name. Merge variable names are case-insensitive and may not start with _
                         - content {String} the merge variable's content
         - tags {Array} an array of string to tag the message with.  Stats are accumulated using tags, though we only store the first 100 we see, so this should not be unique or change frequently.  Tags should be 50 characters or less.  Any tags starting with an underscore are reserved for internal use and will cause errors.
             - tags[] {String} a single tag - must not start with an underscore
         - google_analytics_domains {Array} an array of strings indicating for which any matching URLs will automatically have Google Analytics parameters appended to their query string automatically.
         - google_analytics_campaign {Array|string} optional string indicating the value to set for the utm_campaign tracking parameter. If this isn't provided the email's from address will be used instead.
         - metadata {Array} metadata an associative array of user metadata. Mandrill will store this metadata and make it available for retrieval. In addition, you can select up to 10 metadata fields to index and make searchable using the Mandrill search api.
         - recipient_metadata {Array} Per-recipient metadata that will override the global values specified in the metadata parameter.
             - recipient_metadata[] {Object} metadata for a single recipient
                 - rcpt {String} the email address of the recipient that the metadata is associated with
                 - values {Array} an associated array containing the recipient's unique metadata. If a key exists in both the per-recipient metadata and the global metadata, the per-recipient metadata will be used.
         - attachments {Array} an array of supported attachments to add to the message
             - attachments[] {Object} a single supported attachment
                 - type {String} the MIME type of the attachment - allowed types are text/*, image/*, and application/pdf
                 - name {String} the file name of the attachment
                 - content {String} the content of the attachment as a base64-encoded string
    @option params {Boolean} async enable a background sending mode that is optimized for bulk sending. In async mode, messages/send will immediately return a status of "queued" for every recipient. To handle rejections when sending in async mode, set up a webhook for the 'reject' event. Defaults to false for messages with fewer than 100 recipients; messages with more than 100 recipients are always sent asynchronously, regardless of the value of async.
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    send: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["async"] ?= false

        @master.call('messages/send', params, onsuccess, onerror)

    ###
    Send a new transactional message through Mandrill using a template
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} template_name the name of a template that exists in the user's account
    @option params {Array} template_content an array of template content to send.  Each item in the array should be a struct with two keys - name: the name of the content block to set the content for, and content: the actual content to put into the block
         - template_content[] {Object} the injection of a single piece of content into a single editable region
             - name {String} the name of the mc:edit editable region to inject into
             - content {String} the content to inject
    @option params {Struct} message the other information on the message to send - same as /messages/send, but without the html content
         - text {String} optional full text content to be sent
         - subject {String} the message subject
         - from_email {String} the sender email address.
         - from_name {String} optional from name to be used
         - to {Array} an array of recipient information.
             - to[] {Object} a single recipient's information.
                 - email {String} the email address of the recipient
                 - name {String} the optional display name to use for the recipient
         - headers {Object} optional extra headers to add to the message (currently only Reply-To and X-* headers are allowed)
         - track_opens {Boolean} whether or not to turn on open tracking for the message
         - track_clicks {Boolean} whether or not to turn on click tracking for the message
         - auto_text {Boolean} whether or not to automatically generate a text part for messages that are not given text
         - url_strip_qs {Boolean} whether or not to strip the query string from URLs when aggregating tracked URL data
         - preserve_recipients {Boolean} whether or not to expose all recipients in to "To" header for each email
         - bcc_address {String} an optional address to receive an exact copy of each recipient's email
         - global_merge_vars {Array} global merge variables to use for all recipients. You can override these per recipient.
             - global_merge_vars[] {Object} a single global merge variable
                 - name {String} the global merge variable's name. Merge variable names are case-insensitive and may not start with _
                 - content {String} the global merge variable's content
         - merge_vars {Array} per-recipient merge variables, which override global merge variables with the same name.
             - merge_vars[] {Object} per-recipient merge variables
                 - rcpt {String} the email address of the recipient that the merge variables should apply to
                 - vars {Array} the recipient's merge variables
                     - vars[] {Object} a single merge variable
                         - name {String} the merge variable's name. Merge variable names are case-insensitive and may not start with _
                         - content {String} the merge variable's content
         - tags {Array} an array of string to tag the message with.  Stats are accumulated using tags, though we only store the first 100 we see, so this should not be unique or change frequently.  Tags should be 50 characters or less.  Any tags starting with an underscore are reserved for internal use and will cause errors.
             - tags[] {String} a single tag - must not start with an underscore
         - google_analytics_domains {Array} an array of strings indicating for which any matching URLs will automatically have Google Analytics parameters appended to their query string automatically.
         - google_analytics_campaign {Array|string} optional string indicating the value to set for the utm_campaign tracking parameter. If this isn't provided the email's from address will be used instead.
         - metadata {Array} metadata an associative array of user metadata. Mandrill will store this metadata and make it available for retrieval. In addition, you can select up to 10 metadata fields to index and make searchable using the Mandrill search api.
         - recipient_metadata {Array} Per-recipient metadata that will override the global values specified in the metadata parameter.
             - recipient_metadata[] {Object} metadata for a single recipient
                 - rcpt {String} the email address of the recipient that the metadata is associated with
                 - values {Array} an associated array containing the recipient's unique metadata. If a key exists in both the per-recipient metadata and the global metadata, the per-recipient metadata will be used.
         - attachments {Array} an array of supported attachments to add to the message
             - attachments[] {Object} a single supported attachment
                 - type {String} the MIME type of the attachment - allowed types are text/*, image/*, and application/pdf
                 - name {String} the file name of the attachment
                 - content {String} the content of the attachment as a base64-encoded string
    @option params {Boolean} async enable a background sending mode that is optimized for bulk sending. In async mode, messages/sendTemplate will immediately return a status of "queued" for every recipient. To handle rejections when sending in async mode, set up a webhook for the 'reject' event. Defaults to false for messages with fewer than 100 recipients; messages with more than 100 recipients are always sent asynchronously, regardless of the value of async.
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    sendTemplate: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["async"] ?= false

        @master.call('messages/send-template', params, onsuccess, onerror)

    ###
    Search the content of recently sent messages and optionally narrow by date range, tags and senders
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} query the search terms to find matching messages for
    @option params {String} date_from start date
    @option params {String} date_to end date
    @option params {Array} tags an array of tag names to narrow the search to, will return messages that contain ANY of the tags
    @option params {Array} senders an array of sender addresses to narrow the search to, will return messages sent by ANY of the senders
    @option params {Integer} limit the maximum number of results to return, defaults to 100, 1000 is the maximum
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    search: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["query"] ?= '*'
        params["date_from"] ?= null
        params["date_to"] ?= null
        params["tags"] ?= null
        params["senders"] ?= null
        params["limit"] ?= 100

        @master.call('messages/search', params, onsuccess, onerror)

    ###
    Parse the full MIME document for an email message, returning the content of the message broken into its constituent pieces
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} raw_message the full MIME document of an email message
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    parse: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('messages/parse', params, onsuccess, onerror)

    ###
    Take a raw MIME document for a message, and send it exactly as if it were sent over the SMTP protocol
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} raw_message the full MIME document of an email message
    @option params {String|null} from_email optionally define the sender address - otherwise we'll use the address found in the provided headers
    @option params {String|null} from_name optionally define the sender alias
    @option params {Array|null} to optionally define the recipients to receive the message - otherwise we'll use the To, Cc, and Bcc headers provided in the document
         - to[] {String} the email address of the recipint
    @option params {Boolean} async enable a background sending mode that is optimized for bulk sending. In async mode, messages/sendRaw will immediately return a status of "queued" for every recipient. To handle rejections when sending in async mode, set up a webhook for the 'reject' event. Defaults to false for messages with fewer than 100 recipients; messages with more than 100 recipients are always sent asynchronously, regardless of the value of async.
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    sendRaw: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["from_email"] ?= null
        params["from_name"] ?= null
        params["to"] ?= null
        params["async"] ?= false

        @master.call('messages/send-raw', params, onsuccess, onerror)
class Urls
    constructor: (@master) ->


    ###
    Get the 100 most clicked URLs
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    list: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('urls/list', params, onsuccess, onerror)

    ###
    Return the 100 most clicked URLs that match the search query given
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} q a search query
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    search: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('urls/search', params, onsuccess, onerror)

    ###
    Return the recent history (hourly stats for the last 30 days) for a url
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} url an existing URL
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    timeSeries: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('urls/time-series', params, onsuccess, onerror)
class Webhooks
    constructor: (@master) ->


    ###
    Get the list of all webhooks defined on the account
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    list: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('webhooks/list', params, onsuccess, onerror)

    ###
    Add a new webhook
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} url the URL to POST batches of events
    @option params {Array} events an optional list of events that will be posted to the webhook
         - events[] {String} the individual event to listen for
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    add: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["events"] ?= []

        @master.call('webhooks/add', params, onsuccess, onerror)

    ###
    Given the ID of an existing webhook, return the data about it
    @param {Object} params the hash of the parameters to pass to the request
    @option params {Integer} id the unique identifier of a webhook belonging to this account
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    info: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('webhooks/info', params, onsuccess, onerror)

    ###
    Update an existing webhook
    @param {Object} params the hash of the parameters to pass to the request
    @option params {Integer} id the unique identifier of a webhook belonging to this account
    @option params {String} url the URL to POST batches of events
    @option params {Array} events an optional list of events that will be posted to the webhook
         - events[] {String} the individual event to listen for
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    update: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}

        params["events"] ?= []

        @master.call('webhooks/update', params, onsuccess, onerror)

    ###
    Delete an existing webhook
    @param {Object} params the hash of the parameters to pass to the request
    @option params {Integer} id the unique identifier of a webhook belonging to this account
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    delete: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('webhooks/delete', params, onsuccess, onerror)
class Senders
    constructor: (@master) ->


    ###
    Return the senders that have tried to use this account.
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    list: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('senders/list', params, onsuccess, onerror)

    ###
    Returns the sender domains that have been added to this account.
    @param {Object} params the hash of the parameters to pass to the request
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    domains: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('senders/domains', params, onsuccess, onerror)

    ###
    Return more detailed information about a single sender, including aggregates of recent stats
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} address the email address of the sender
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    info: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('senders/info', params, onsuccess, onerror)

    ###
    Return the recent history (hourly stats for the last 30 days) for a sender
    @param {Object} params the hash of the parameters to pass to the request
    @option params {String} address the email address of the sender
    @param {Function} onsuccess an optional callback to execute when the API call is successfully made
    @param {Function} onerror an optional callback to execute when the API call errors out - defaults to throwing the error as an exception
    ###
    timeSeries: (params={}, onsuccess, onerror) ->
        if typeof params == 'function'
            onerror = onsuccess
            onsuccess = params
            params = {}


        @master.call('senders/time-series', params, onsuccess, onerror)


