utility = nil

export LOCALIZATION = nil

export STATE = {
	PATHS: {
		RESOURCES: nil
	}
	SCROLLBAR: {
		START: nil
		MAX_HEIGHT: nil
		HEIGHT: nil
		STEP: nil
	}
	NUM_SLOTS: 5
	LOGGING: false
	STACK: false
	SCROLL_INDEX: nil
	PROPERTIES: nil
	FILTER_TYPE: nil
	ARGUMENTS: {}
}

COMPONENTS = {
	STATUS: nil
	SETTINGS: nil
	SLOTS: nil
}

class Property
	new: (args) =>
		@title = args.title
		@value = args.value
		@enum = args.enum
		@arguments = args.arguments
		@properties = args.properties
		@action = args.action
		@update = args.update

class Slot
	new: (index) =>
		@index = index

	populate: (property) =>
		@property = property
		@update()

	update: () =>
		if @property
			@property.value = @property\update() if @property.update ~= nil
			SKIN\Bang(('[!SetOption "Slot%dTitle" "Text" "%s"]')\format(@index, utility.replaceUnsupportedChars(@property.title)))
			SKIN\Bang(('[!SetOption "Slot%dValue" "Text" "%s"]')\format(@index, utility.replaceUnsupportedChars(@property.value)))
			return
		SKIN\Bang(('[!SetOption "Slot%dTitle" "Text" " "]')\format(@index))
		SKIN\Bang(('[!SetOption "Slot%dValue" "Text" " "]')\format(@index))

	hasAction: () => return @property ~= nil

	action: () =>
		if @property.enum ~= nil
			STATE.FILTER_TYPE = @property.enum
		if @property.arguments ~= nil
			for arg in *@property.arguments
				STATE.ARGUMENTS[arg[1]] = arg[2]
		if @property.properties ~= nil
			STATE.PROPERTIES = @property.properties
			return true
		if @property.action ~= nil
			@property\action()
			return true
		argument = ''
		for key, value in pairs(STATE.ARGUMENTS)
			argument ..= ('|%s:%s')\format(key, tostring(value))
		SKIN\Bang(('[!CommandMeasure "Script" "Filter(%d, %s, \'%s\')" "#ROOTCONFIG#"]')\format(STATE.FILTER_TYPE, tostring(STATE.STACK), argument))
		return false

Game = nil

export log = (...) -> print(...) if STATE.LOGGING == true

export Initialize = () ->
	SKIN\Bang('[!Hide]')
	STATE.PATHS.RESOURCES = SKIN\GetVariable('@')
	dofile(('%s%s')\format(STATE.PATHS.RESOURCES, 'lib\\rainmeter_helpers.lua'))
	COMPONENTS.STATUS = require('shared.status')()
	success, err = pcall(
		() ->
			log('Initializing Filter config')
			require('shared.enums')
			utility = require('shared.utility')
			utility.createJSONHelpers()
			COMPONENTS.SETTINGS = require('shared.settings')()
			STATE.LOGGING = COMPONENTS.SETTINGS\getLogging()
			export LOCALIZATION = require('shared.localization')(COMPONENTS.SETTINGS)
			Game = require('main.game')
			STATE.SCROLL_INDEX = 1
			COMPONENTS.SLOTS = [Slot(i) for i = 1, STATE.NUM_SLOTS]
			scrollbar = SKIN\GetMeter('Scrollbar')
			STATE.SCROLLBAR.START = scrollbar\GetY()
			STATE.SCROLLBAR.MAX_HEIGHT = scrollbar\GetH()
			SKIN\Bang(('[!SetOption "PageTitle" "Text" "%s"]')\format(LOCALIZATION\get('filter_window_all_title', 'Filter')))
			SKIN\Bang('[!CommandMeasure "Script" "HandshakeFilter()" "#ROOTCONFIG#"]')
			COMPONENTS.STATUS\hide()
	)
	COMPONENTS.STATUS\show(err, true) unless success

export Update = () ->
	return

sortPropertiesByTitle = (a, b) ->
	return true if a.title\lower() < b.title\lower()
	return false

createProperties = () ->
	properties = {}
	backButtonTitle = LOCALIZATION\get('filter_back_button_title', 'Back')
	numGamesPattern = LOCALIZATION\get('game_number_of_games', '%d games')
	games = io.readJSON('games.json')
	games = [Game(args) for args in *games.games]
	platforms = [Platform(COMPONENTS.SETTINGS) for Platform in *require('main.platforms')]
	platforms = [platform for platform in *platforms when platform\isEnabled()]
	platformProperties = {}
	for platform in *platforms
		numGames = 0
		platformID = platform\getPlatformID()
		for game in *games
			if game\getPlatformID() == platformID
				numGames += 1
		numGames = numGamesPattern\format(numGames)
		table.insert(platformProperties, Property({
			title: platform\getName()
			value: numGames
			arguments: {
				{'platformID', platformID}
			}
		}))
	platformOverrides = {}
	for game in *games
		platformOverride = game\getPlatformOverride()
		if platformOverride ~= nil
			if platformOverrides[platformOverride] == nil
				platformOverrides[platformOverride] = {platformID: game\getPlatformID(), numGames: 1}
			else
				platformOverrides[platformOverride].numGames += 1
	for platformOverride, params in pairs(platformOverrides)
		numGames = numGamesPattern\format(params.numGames)
		table.insert(platformProperties, Property({
			title: platformOverride .. '*'
			value: numGames
			arguments: {
				{'platformID', params.platformID}
				{'platformOverride', platformOverride}
			}
		}))
	table.sort(platformProperties, sortPropertiesByTitle)
	table.insert(platformProperties, 1, Property({
		title: backButtonTitle
		value: ' '
		properties: properties
	}))
	numGames = numGamesPattern\format(#games)
	table.insert(properties,
		Property({
			title: LOCALIZATION\get('filter_from_platform', 'Is on platform')
			value: numGames
			enum: ENUMS.FILTER_TYPES.PLATFORM
			properties: platformProperties
		})
	)
	tags = {}
	gamesWithTags = 0
	hiddenGames = 0
	uninstalledGames = 0
	for game in *games
		hiddenGames += 1 unless game\isVisible()
		uninstalledGames += 1 unless game\isInstalled()
		skinTags = game\getTags()
		platformTags = game\getPlatformTags()
		gamesWithTags += 1 if #skinTags > 0 or #platformTags > 0
		for tag in *skinTags
			if tags[tag] == nil
				tags[tag] = 0
			tags[tag] += 1
		for tag in *platformTags
			if tags[tag] == nil
				tags[tag] = 0
			tags[tag] += 1
	tagProperties = {}
	for tag, numGames in pairs(tags)
		numGames = numGamesPattern\format(numGames)
		table.insert(tagProperties, Property({
			title: tag
			value: numGames
			arguments: {
				{'tag', tag}
			}
		}))
	table.sort(tagProperties, sortPropertiesByTitle)
	table.insert(tagProperties, 1, Property({
		title: backButtonTitle
		value: ' '
		properties: properties
	}))
	numGames = numGamesPattern\format(gamesWithTags)
	table.insert(properties,
		Property({
			title: LOCALIZATION\get('filter_has_tag', 'Has tag')
			value: numGames
			enum: ENUMS.FILTER_TYPES.TAG
			properties: tagProperties
		})
	)
	numGames = numGamesPattern\format(hiddenGames)
	table.insert(properties,
		Property({
			title: LOCALIZATION\get('filter_is_hidden', 'Is hidden')
			value: numGames
			enum: ENUMS.FILTER_TYPES.HIDDEN
		})
	)
	numGames = numGamesPattern\format(uninstalledGames)
	table.insert(properties,
		Property({
			title: LOCALIZATION\get('filter_is_uninstalled', 'Is not installed')
			value: numGames
			enum: ENUMS.FILTER_TYPES.UNINSTALLED
		})
	)
	table.sort(properties, sortPropertiesByTitle)
	table.insert(properties, 1,
		Property({
			title: LOCALIZATION\get('filter_clear_filters', 'Clear filters')
			value: ' '
			enum: ENUMS.FILTER_TYPES.NONE
		})
	)
	table.insert(properties, 1,
		Property({
			title: LOCALIZATION\get('button_label_cancel', 'Cancel')
			value: ' '
			action: () =>
				SKIN\Bang('[!DeactivateConfig]')
		})
	)
	return properties

updateScrollbar = () ->
	STATE.MAX_SCROLL_INDEX = #STATE.PROPERTIES - STATE.NUM_SLOTS + 1
	if #STATE.PROPERTIES > STATE.NUM_SLOTS
		STATE.SCROLLBAR.HEIGHT = math.round(STATE.SCROLLBAR.MAX_HEIGHT / (#STATE.PROPERTIES - STATE.NUM_SLOTS + 1))
		STATE.SCROLLBAR.STEP = (STATE.SCROLLBAR.MAX_HEIGHT - STATE.SCROLLBAR.HEIGHT) / (#STATE.PROPERTIES - STATE.NUM_SLOTS)
	else
		STATE.SCROLLBAR.HEIGHT = STATE.SCROLLBAR.MAX_HEIGHT
		STATE.SCROLLBAR.STEP = 0
	SKIN\Bang(('[!SetOption "Scrollbar" "H" "%d"]')\format(STATE.SCROLLBAR.HEIGHT))
	y = STATE.SCROLLBAR.START + (STATE.SCROLL_INDEX - 1) * STATE.SCROLLBAR.STEP
	SKIN\Bang(('[!SetOption "Scrollbar" "Y" "%d"]')\format(math.round(y)))

updateSlots = () ->
	for i, slot in ipairs(COMPONENTS.SLOTS)
		slot\populate(STATE.PROPERTIES[i + STATE.SCROLL_INDEX - 1])
		if i == STATE.HIGHLIGHTED_SLOT_INDEX
			MouseOver(i)

export Handshake = (stack) ->
	success, err = pcall(
		() ->
			if stack
				SKIN\Bang(('[!SetOption "PageTitle" "Text" "%s"]')\format(LOCALIZATION\get('filter_window_current_title', 'Filter (current games)')))
			log('Accepting Filter handshake', stack)
			STATE.STACK = stack
			STATE.PROPERTIES = createProperties()
			updateScrollbar()
			updateSlots()
			if COMPONENTS.SETTINGS\getCenterOnMonitor()
				meter = SKIN\GetMeter('WindowShadow')
				skinWidth = meter\GetW()
				skinHeight = meter\GetH()
				mainConfig = utility.getConfig(SKIN\GetVariable('ROOTCONFIG'))
				monitorIndex = nil
				if mainConfig ~= nil
					monitorIndex = utility.getConfigMonitor(mainConfig) or 1
				else
					monitorIndex = 1
				x, y = utility.centerOnMonitor(skinWidth, skinHeight, monitorIndex)
				SKIN\Bang(('[!Move "%d" "%d"]')\format(x, y))
			SKIN\Bang('[!Show]')
	)
	COMPONENTS.STATUS\show(err, true) unless success

export Scroll = (direction) ->
	return unless COMPONENTS.SLOTS
	index = STATE.SCROLL_INDEX + direction
	if index < 1
		return
	elseif index > STATE.MAX_SCROLL_INDEX
		return
	STATE.SCROLL_INDEX = index
	updateScrollbar()
	updateSlots()

export MouseOver = (index) ->
	return if index < 1
	return unless COMPONENTS.SLOTS
	return unless COMPONENTS.SLOTS[index]\hasAction()
	STATE.HIGHLIGHTED_SLOT_INDEX = index
	SKIN\Bang(('[!SetOption "Slot%dButton" "SolidColor" "#ButtonHighlightedColor#"]')\format(index))

export MouseLeave = (index) ->
	return if index < 1
	return unless COMPONENTS.SLOTS
	return unless COMPONENTS.SLOTS[index]\hasAction()
	if index == 0
		STATE.HIGHLIGHTED_SLOT_INDEX = 0
		for i = index, STATE.NUM_SLOTS
			SKIN\Bang(('[!SetOption "Slot%dButton" "SolidColor" "#ButtonBaseColor#"]')\format(i))
	else
		SKIN\Bang(('[!SetOption "Slot%dButton" "SolidColor" "#ButtonBaseColor#"]')\format(index))

export MouseLeftPress = (index) ->
	return if index < 1
	return unless COMPONENTS.SLOTS
	return unless COMPONENTS.SLOTS[index]\hasAction()
	SKIN\Bang(('[!SetOption "Slot%dButton" "SolidColor" "#ButtonPressedColor#"]')\format(index))

export ButtonAction = (index) ->
	return if index < 1
	return unless COMPONENTS.SLOTS
	return unless COMPONENTS.SLOTS[index]\hasAction()
	SKIN\Bang(('[!SetOption "Slot%dButton" "SolidColor" "#ButtonHighlightedColor#"]')\format(index))
	if COMPONENTS.SLOTS[index]\action()
		STATE.SCROLL_INDEX = 1
		updateScrollbar()
		updateSlots()
	else
		SKIN\Bang('[!DeactivateConfig]')