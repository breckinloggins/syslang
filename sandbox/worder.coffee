# Some tests for a fourth-like "fully contextual" language parser
readline = require('readline') # http://nodejs.org/api/readline.html#readline_readline

Modes = 
  interpret: "interpret"
  compile: "compile"

WordTypes = 
  trigger: "trigger"
  normal: "normal"
  deferred: "deferred"

class Context
  constructor: (@parent = null) ->
    @line = ''
    @arg = null
    @mode = Modes.interpret
    @words = {}

context = new Context

fn_create = (a) ->
  throw "don't know how to create #{a} [#{typeof(a)}]" unless a.word?
  context.words[a.word] = a
  a

fn_read_line = ->
  curLine = context.line
  context.line = ''
  curLine

fn_read_word = ->
  curWord = ''
  for c, i in context.line
    break if context.words[c]?.type == WordTypes.trigger and context.words[c].fn()
    curWord += c

  context.line = context.line.substring i+1
  curWord

fn_word = ([word, wordType, fn]) ->
  { word: word, context: context, type: wordType, fn: fn } 

fn_lookup_word = (word) ->
  context.words[word] || { word: word, type: WordTypes.deferred, fn: -> fn_lookup_word(word) }

fn_eval = (a) ->
  return null unless a?

  switch typeof a
    when 'string' 
      fn_eval fn_lookup_word(a)
    when 'object'
      if a.type == WordTypes.deferred
        throw "Unrecognized word #{a.word}" unless context.parent?
      else
        a.fn(context.arg)
    else
      console.log "Don't know how to eval '#{a}' of type #{typeof a}"
      context.arg

fn_native_eval = (a) ->
  return null unless a?

  eval(a) 

fn_defer = (a) ->
  {word: a.word || a.toString() || '', type: WordTypes.normal, fn: -> a} 

fn_interpret = (a) ->
  context.line = a
  try
    while context.line != ''
      next_word = context.words['read-word'].fn()
      context.arg = context.words['eval'].fn(next_word)
  catch e
    console.log "Error: #{e}"
    context.line = ''
    context.arg = null

  context.arg


builtin = (word, wordType, fn) -> context.words[word] = fn_word [word, wordType, fn]

builtin ' ',            WordTypes.trigger, -> true
builtin '\n',           WordTypes.trigger, -> true
builtin 'word',         WordTypes.normal, fn_word
builtin 'create',       WordTypes.normal, fn_create
builtin 'dbg',          WordTypes.normal, (a) -> console.log a; a 
builtin 'read-line',    WordTypes.normal, fn_read_line
builtin 'read-word',    WordTypes.normal, fn_read_word
builtin 'lookup-word',  WordTypes.normal, fn_lookup_word
builtin 'defer',        WordTypes.normal, fn_defer
builtin 'eval',         WordTypes.normal, fn_eval
builtin 'native-eval',  WordTypes.normal, fn_native_eval
builtin 'interpret',    WordTypes.normal, fn_interpret

bootstrap = [
  "read-line ['bye', 'normal', function(a) { process.exit(0); }]"
  "native-eval word create"
]
 
completer = (l) ->
  completions = (word for own word, _ of context.words when word.type != WordTypes.trigger)
  hits = completions.filter (c) -> c.indexOf(l) == 0

  [(if hits.length > 0 then hits else completions), l]

context.words['interpret'].fn(line) for line in bootstrap

rl = readline.createInterface {input: process.stdin, output: process.stdout, completer: completer }
rl.setPrompt "> "
rl.prompt()

rl.on('line', (l) ->
  context.words['interpret'].fn(l)
  rl.prompt()
).on 'close', ->
  console.log "Bye"
  process.exit 0

