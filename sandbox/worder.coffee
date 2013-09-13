# Some tests for a fourth-like "fully contextual" language parser
readline = require('readline') # http://nodejs.org/api/readline.html#readline_readline

words = 
  'bye': -> process.exit 0

completer = (line) ->
  completions = word for own word, _ of words
  hits = completions.filter (c) -> c.indexOf(line) == 0

  [(if hits.length > 0 then hits else completions), line]

rl = readline.createInterface {input: process.stdin, output: process.stdout, completer: completer }
rl.setPrompt "> "
rl.prompt()

rl.on('line', (line) ->
  for word in line.split(' ')
    (console.log "Unknown word: #{word}"; break) unless words[word]?
    words[word]()

  rl.prompt()
).on 'close', ->
  console.log "Bye"
  process.exit 0

