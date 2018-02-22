Platform = require('main.platforms.platform')
Game = require('main.game')

-- Dump a list of .lnk and .url files along with their target and argument properties.

class Shortcuts extends Platform
	new: (settings) =>
		super(settings)
		@platformID = ENUMS.PLATFORM_IDS.SHORTCUTS
		@name = LOCALIZATION\get('platform_name_windows_shortcut', 'Windows shortcut')
		@cachePath = 'cache\\shortcuts\\'
		@shortcutsPath = io.joinPaths(STATE.PATHS.RESOURCES, 'Shortcuts\\')
		@outputPath = io.joinPaths(@cachePath, 'output.txt')
		@enabled = settings\getShortcutsEnabled()

	parseShortcuts: () =>
		if io.fileExists(@outputPath)
			io.writeFile(@outputPath, '')
		SKIN\Bang(('["#@#windowless.vbs" "#@#main\\platforms\\shortcuts\\parseShortcuts.bat" "%s"]')\format(@shortcutsPath))
		return @getWaitCommand(), '', 'OnParsedShortcuts'

	hasParsedShortcuts: () => return io.fileExists(io.joinPaths(@cachePath, 'completed.txt'))

	generateGames: () =>
		unless io.fileExists(@outputPath)
			@games = {}
			return
		games = {}
		output = io.readFile(@outputPath)
		lines = output\splitIntoLines()
		while #lines > 0
			absoluteFilePath = table.remove(lines, 1)
			_, diverges = absoluteFilePath\find(@shortcutsPath)
			relativeFilePath = absoluteFilePath\sub(diverges + 1)
			parts = relativeFilePath\split('\\')
			title = switch #parts
				when 1 then parts[1]
				when 2 then parts[2]
				else assert(nil, 'Unexpected path structure when processing Windows shortcuts.')
			title = title\match('^([^%.]+)')
			platformOverride = switch #parts
				when 2 then parts[1]
				else nil
			banner = nil
			if platformOverride ~= nil
				banner = @getBannerPath(title, ('Shortcuts\\%s')\format(platformOverride))
			else
				banner = @getBannerPath(title, 'Shortcuts')
			path = ('"%s"')\format(table.remove(lines, 1)\match('^	Target=(.-)$'))
			arguments = table.remove(lines, 1)
			arguments = arguments\match('^	Arguments=(.-)$') if arguments
			if arguments ~= nil and arguments ~= ''
				arguments = arguments\split('"%s"')
				if #arguments > 0
					path = ('%s "%s"')\format(path, table.concat(arguments, '" "'))
			table.insert(games, {
				:title
				:banner
				:path
				:platformOverride
				platformID: @platformID
			})
		@games = [Game(args) for args in *games]

return Shortcuts