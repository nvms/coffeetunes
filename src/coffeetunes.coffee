req = require 'request'
util = require './utilities'
chalk = require 'chalk'
readline = require 'readline'
cp = require 'child_process'

g =
    content: null
    message: null
    songs: null
    player_process: null
    last_played_song: null
    last_played_index: null

config =
    player: 'mplayer'
    playerargs: [
        '-nolirc',
        '-prefer-ipv4'
    ]

request_options =
    encoding: 'utf8'
    method: 'GET'
    uri: null
    headers: 'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)'

get_tracks_from_html = (html) ->
    fields = 'duration file_id singer song link rate size source'.split(' ')
    html_re = /<li.(duration[^>]+)>/g
    [songs_html, songs] = [html.match(html_re), []]
    return false if !songs_html?
    for song, index in songs_html
        current_song = {}
        for f in fields
            field_value_regx = '="([^"]+)"'
            field_string = f + field_value_regx
            field_value = song.match(field_string)
            current_song[f] = util.tidy(f, field_value[1])
        songs.push current_song
    g.songs = songs
    songs       

get_trackinfo = (song, cb) ->
    url = "http://pleer.com/site_api/files/get_url?action=download&id=#{song.link}"
    request_options.uri = url
    await req.get request_options, defer err, http, res
    console.error err if err?
    song.trackinfo = if http?.statusCode is 200 then JSON.parse(res) else false
    cb song if cb

generate_songlist = (songs) ->
    str = chalk.reset ''
    for song, index in songs
        line_text = "#{index+1} - #{song.duration} - #{song.singer} - #{song.song}"

        line = if index%2 is 0 then chalk.dim line_text else chalk.dim line_text

        # is this the last song requested?
        if g.last_played_index isnt null and index is g.last_played_index
            line = chalk.reset line_text
            line += chalk.reset ''
            g.last_played_index = null

        str += line + '\n'
    str

# ----------------------------------------------------------------------

search = (term, cb) ->
    if !term or term.length < 2
        console.error 'bad search term'
        if cb then return cb else false
    qs = "http://pleer.com/search?target=tracks&page=1&q=#{term}"
    qs = encodeURI(qs)
    request_options.uri = qs
    await req.get request_options, defer err, http, res
    console.error err if err?
    songs = if http?.statusCode is 200 then get_tracks_from_html res else false
    cb songs if cb

search_callback = (data) ->
    g.songs = data
    g.content = generate_songlist(data)
    g.message = null

# ----------------------------------------------------------------------
play = (song_number, cb) ->
    song = g.songs[song_number - 1]
    await get_trackinfo song, defer res
    song = res
    g.last_played_index = song_number - 1

    config.playerargs.push song.trackinfo.track_link

    if g.player_process
        g.player_process.kill()
        g.player_process = null
    g.player_process = cp.spawn(config.player, config.playerargs)

    g.player_process.stdout.on 'data', (data) ->
        return
    g.player_process.stderr.on 'data', (data) ->
        return
    g.player_process.on 'close', (code) ->
        return

    g.last_played_song = song

    # the last element in config.playerargs is the URL to the
    # last played song. let's get rid of it
    config.playerargs.pop()

    cb song if cb

play_callback = (song) ->
    g.content = generate_songlist(g.songs)
    g.message = "Playing " + chalk.dim "#{song.singer} - #{song.song}"

	# catch stdin and redirect to myplayer
	if g.player_process
		console.log 'have child process'
		g.player_process.stdin.setEncoding = 'utf8'

		player_input = (cb) ->
			rl = readline.createInterface(
				input: g.player_process.stdin
				output: g.player_process.stdout)
			rl.question '', (answer) ->
				rl.close()
				cb answer
		player_handle_input = (input) ->
			console.log "input was #{input}"

# ----------------------------------------------------------------------

generate_status_line = () ->
	'maybe I\'ll get to this some day'

# ----------------------------------------------------------------------

download = (song_number, cb) ->
    if not g.songs
        console.error 'invalid range or index given'
    song_to_download = g.songs[song_number - 1]
    msg = "Attempting to download "
    msg += chalk.dim "#{song_to_download.singer} - #{song_to_download.song}" + chalk.reset " .."
    g.message = msg
    draw()
    await setTimeout defer(), 2000
    results = 'Download complete.'
    cb results if cb

download_callback = (data) ->
    g.message = 'Download complete'

# ----------------------------------------------------------------------

draw = () ->
    console.log '\n' for [1..100]
    if g.content then console.log g.content
    if g.message then console.log g.message

get_input = (cb) ->
    rl = readline.createInterface(
        input: process.stdin
        output: process.stdout)
    rl.question '> ', (answer) ->
        rl.close()
        cb answer

handle_input = (input) ->
    regx = [
        [search_callback, search, /(?:search|\.)\s*(.{0,500})/],
        [download_callback, download, /^(?:d|dl|download)\s*(\d{1,4})$/],
        [play_callback, play, /^(\d{1,4})$/]
    ]
    found_match = false
    for reg in regx
        [handler, func, r] = reg
        if input.match r
            found_match = true
            matched_input = r.exec input
            if func is play
                await func matched_input[0], defer results
            else
                await func matched_input[1], defer results
            handler results

    if !found_match then g.message = 'bad input'
    main()

main = () ->
    draw()
    while 1 is 1
        await get_input handle_input, defer input
        break

# ----------------------------------------------------------------------

exitHandler = (options, err) ->
    console.log 'exit handler called'
    if options.cleanup
        g.content = null
        g.message = 'goodbye'
        if g.player_process
            g.player_process.kill()
            g.message += chalk.dim " [#{config.player} process was alive but has been killed]"
        draw()
    if err
        console.log err.stack
    if options.exit
        process.exit()
    return

# ----------------------------------------------------------------------

readline.emitKeypressEvents process.stdin
process.stdin.setRawMode(true);
process.stdin.resume()

process.on 'exit', exitHandler.bind(null, cleanup: true)
process.on 'SIGINT', exitHandler.bind(null, exit: true)
process.on 'uncaughtException', exitHandler.bind(null, exit: true)

process.stdin.on 'keypress', (str, key) ->
    # not sure why, but exitHandler gets called when a key that isn't a-zA-Z is pressed
    if str.match(/a-zA-Z0-9/)
        if key.ctrl and key.name == 'c'
            process.exit()
    return

# entry point
main()
