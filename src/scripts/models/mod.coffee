###
Crafting Guide - mod.coffee

Copyright (c) 2015 by Redwood Labs
All rights reserved.
###

BaseModel      = require './base_model'
{Event}        = require '../constants'
{RequiredMods} = require '../constants'
{Url}          = require '../constants'

########################################################################################################################

module.exports = class Mod extends BaseModel

    constructor: (attributes={}, options={})->
        if not attributes.name? then throw new Error 'attributes.name is required'
        attributes.author      ?= ''
        attributes.description ?= ''
        attributes.primaryUrl  ?= null
        attributes.slug        ?= _.slugify attributes.name
        super attributes, options

        @_activeModVersion = null
        @_activeVersion    = null
        @_modVersions      = []

        Object.defineProperties this,
            'activeModVersion': { get:-> @_activeModVersion                    }
            'activeVersion':    { get:@getActiveVersion, set:@setActiveVersion }
            'enabled':          { get:-> @_activeModVersion?                   }

    # Class Methods ##################################################################################

    @Version =
        None: 'none'
        Latest: 'latest'

    # Public Methods #################################################################################

    compareTo: (that)->
        thisRequired = this.slug in RequiredMods
        thatRequired = that.slug in RequiredMods

        if thisRequired isnt thatRequired
            return -1 if thisRequired
            return +1 if thatRequired
        else
            if this.name isnt that.name
                return if this.name < that.name then -1 else +1

        return 0

    # ModVersion Proxy Methods #####################################################################

    eachItem: (callback)->
        return unless @_activeModVersion?
        @_activeModVersion.eachItem callback

    eachName: (callback)->
        return unless @_activeModVersion?
        @_activeModVersion.eachName callback

    findItem: (slug)->
        return unless @_activeModVersion?
        @_activeModVersion.findItem slug

    findItemByName: (name)->
        return unless @_activeModVersion?
        @_activeModVersion.findItemByName name

    findName: (slug)->
        return unless @_activeModVersion?
        @_activeModVersion.findName slug

    # Property Methods #############################################################################

    addModVersion: (modVersion)->
        return unless modVersion?
        return if @_modVersions.indexOf(modVersion) isnt -1

        @_modVersions.push modVersion
        @listenTo modVersion, Event.change, => @trigger Event.change, this
        modVersion.mod = this

        @trigger Event.add + ':modVersion', modVersion, this
        @trigger Event.change + ':version', modVersion, this
        @trigger Event.change, this

        if not @activeVersion? then @activeVersion = modVersion.version
        if modVersion.version is @_activeVersion then @_activateModVersion modVersion
        return this

    eachModVersion: (callback)->
        for modVersion in @_modVersions
            callback modVersion

    getActiveVersion: ->
        return @_activeVersion

    setActiveVersion: (version)->
        version ?= Mod.Version.None
        if version is Mod.Version.Latest then version = _.last(@_modVersions).version

        if version is Mod.Version.None
            @_activeVersion = version
            @_activateModVersion null

            @trigger Event.change + ':activeVersion', this, @_activeVersion
            @trigger Event.change, this
        else
            for modVersion in @_modVersions
                if version is modVersion.version
                    @_activateModVersion modVersion
                    break

            @_activeVersion = version
            @trigger Event.change + ':activeVersion', this, @_activeVersion
            @trigger Event.change, this


    # Backbone.View Overrides ######################################################################

    parse: (text)->
        ModParser = require './mod_parser' # to avoid require cycles
        @_parser ?= new ModParser model:this
        @_parser.parse text

        return null # prevent calling `set`

    url: ->
        return Url.mod modSlug:@slug

    # Private Methods ##############################################################################

    _activateModVersion: (modVersion)->
        if @_activeModVersion? then @stopListening @_activeModVersion
        @_activeModVersion = modVersion
        @trigger Event.change + ':activeModVersion', this, @_activeModVersion

        logger.verbose "#{@name} switched to version #{@_activeVersion}"

        if @_activeModVersion?
            @listenTo @_activeModVersion, 'all', -> @trigger.apply this, arguments
