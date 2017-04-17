left_pad = (number, target_length) ->
    result = number + ''
    until result.length is target_length
        result = '0' + result
    result

tidy = (field, value) ->
    # only need to return the value
    raw = ''
    if field is 'duration'
        minutes = Math.floor(value / 60)
        seconds = left_pad(value - (minutes * 60), 2)
        raw = "#{minutes}:#{seconds}"
    else if field is 'song' or field is 'singer'
        raw = value
        arr = [
            ['&amp;', '&'],
            ['&amp;amp;', '&'],
            ['&#039;', "'"],
            ['&amp;#039;', "'"]
        ]
        for tup in arr
            [a, b] = tup
            raw = raw.replace(a, b)
    else
        raw = value
    raw

longest_str_in_arr = (arr) ->
    longest = 0
    i = 0
    while i < arr.length
        if longest < arr[i].length
            longest = arr[i].length
        i++
    longest

centrify = (string) ->

    lines = string.split 'x'
    number_of_lines = lines.length
    max_line_length = longest_str_in_arr lines
    x = process.stdout.columns
    y = process.stdout.rows
    indent = (x - max_line_length) / 2
    newlines = (y / 2) - (number_of_lines / 2)

    printlines = ''
    for line in lines
        printlines += (' ' for [1..indent]) + line
    console.log printlines
    # lines = string.split('\n')
    # temp = lines
    # numlines = lines.length
    # max = temp.sort((a, b) ->
    #     b.length - (a.length)
    # )[0].length
    # x = process.stdout.columns
    # y = process.stdout.rows
    # indent = (x - max) / 2
    # newlines = (y) / 2 - (numlines / 2)
    # # lines = ["' ' * #{indent}" + L for L in lines]
    # printlines = []
    # for line in lines
    #     printlines.push (' ' for [1..indent]) + line
    #     # printlines.push line
    # # console.log printlines
    # text = printlines.join('\n') + '\n' * newlines
    # return text


exports.left_pad = left_pad
exports.tidy = tidy
exports.centrify = centrify