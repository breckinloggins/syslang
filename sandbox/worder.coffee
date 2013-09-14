# Some tests for a fourth-like "fully contextual" language parser
readline = require('readline') # http://nodejs.org/api/readline.html#readline_readline

Modes = 
  interpret: "interpret"
  compile: "compile"

WordTypes = 
  trigger: "trigger"
  normal: "normal"
  deferred: "deferred"
  compiled: "compiled"

class Context
  constructor: (@parent = null) ->
    @name = ''
    @line = ''
    @arg = null
    @mode = Modes.interpret
    @currentWord = null
    @words = {}

  toString: () ->
    prefix = @parent?.toString() || '' 

    if prefix != ''
      "#{prefix}::#{@name}"
    else
      @name
      

context = new Context

fn__colon_ = (a) ->
  context.line = context.line.substring 1 # The colon is still on the stack, eat it
  word = fn_read_word()
  fn_set_cur_word(
    fn_create(fn_word([word, 'compiled', null]))
  )
  context.mode = Modes.compile

  true

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
    if fn_lookup_word(c).type == WordTypes.trigger
      if curWord != ''
        # Go ahead and return the built-up word for eval, we'll catch the
        # actual character on the flip side
        context.line = context.line.substring i
        return curWord

      if fn_lookup_word(c).fn()
        break
      else
        curWord = ''
    else
      curWord += c

  context.line = context.line.substring i+1
  curWord

fn_word = ([word, wordType, fn]) ->
  { word: word, context: context, type: wordType, params: [], fn: fn } 

fn_lookup_word = (word, ctx = context) ->
  w = ctx.words[word]

  if w?
    w
  else if ctx.parent == null
    { word: word, type: WordTypes.deferred, fn: -> fn_lookup_word(word) } 
  else
    fn_lookup_word(word, ctx.parent) 

fn_eval = (a) ->
  return null unless a?

  switch typeof a
    when 'string' 
      return '' if a == ''
      fn_eval fn_lookup_word(a)
    when 'object'
      if a.type == WordTypes.deferred
        throw "Unrecognized word '#{a.word}'" # unless context.parent?
      else if a.type == WordTypes.normal
        a.fn(context.arg)
      else if a.type == WordTypes.compiled
        context = new Context(context)
        context.currentWord = a
        arg = fn_interpret a.params.join(' ')
        context = context.parent
        context.arg = arg
      else if fn_lookup_word(a.type).type != WordTypes.deferred
        fn_lookup_word(a.type).fn([a, context.arg]) 
      else
        throw "No word installed to handle word type '#{a.type}'"
        
    else
      console.log "Don't know how to eval '#{a}' of type #{typeof a}"
      context.arg

fn_native_eval = (a) ->
  return null unless a?

  eval(a) 

fn_defer = (a) ->
  {word: a.word || a.toString() || '', type: WordTypes.normal, fn: -> a} 

fn_compile = (a) ->
  throw "Can't compile '#{a}' into context without a current word" unless context.currentWord?

  if typeof(a) == 'string'
    context.currentWord.params.push a
  else if a instanceof Array
    context.currentWord.params.push.apply a
  else
    throw "Don't know how to compile '#{a}'"

fn_set_cur_word = (a) ->
  if a?
    throw "Object '#{a}' doesn't look like a word" unless a.word?
    context.currentWord = a
  else
    context.currentWord = null

fn_interpret = (a) ->
  context.line = a
  try
    while context.line != ''
      next_word = fn_lookup_word('read-word').fn()
      if next_word == ''
        continue
      else if context.mode == Modes.interpret
        context.arg = fn_lookup_word('eval').fn(next_word)
      else if context.mode == Modes.compile
        throw "Can't compile with no current word" unless context.currentWord?
        context.currentWord.params.push next_word
      else if fn_lookup_word(context.mode).type != WordTypes.deferred
        context.arg = fn_lookup_word(context.mode).fn([context, next_word])
      else
        throw "No word installed to handle mode '#{context.mode}'"
  catch e
    console.log "Error: #{e}"
    context.line = ''
    context.arg = null

  context.arg

fn_new_context = (a) ->
  context = new Context(context)
  context.name = a?.toString() || ''
  context.arg = context.parent.arg
  rl.setPrompt(context.toString() + "> ")
  context

fn_exit_context = (a) ->
  throw "Already at top level context" unless context.parent?
  context.parent.arg = a
  context = context.parent
  rl.setPrompt(context.toString() + "> ") 
  context.arg

builtin = (word, wordType, fn) -> context.words[word] = fn_word [word, wordType, fn]

builtin ' ',            WordTypes.trigger, -> false 
builtin '\n',           WordTypes.trigger, -> true
builtin ':',            WordTypes.trigger, fn__colon_
builtin 'word',         WordTypes.normal, fn_word
builtin 'create',       WordTypes.normal, fn_create
builtin 'read-line',    WordTypes.normal, fn_read_line
builtin 'read-word',    WordTypes.normal, fn_read_word
builtin 'lookup-word',  WordTypes.normal, fn_lookup_word
builtin 'defer',        WordTypes.normal, fn_defer
builtin 'eval',         WordTypes.normal, fn_eval
builtin 'native-eval',  WordTypes.normal, fn_native_eval
builtin 'compile',      WordTypes.normal, fn_compile
builtin 'cur-word',     WordTypes.normal, -> context.currentWord
builtin 'set-cur-word', WordTypes.normal, fn_set_cur_word
builtin 'interpret',    WordTypes.normal, fn_interpret
builtin 'new-context',  WordTypes.normal, fn_new_context
builtin 'exit-context', WordTypes.normal, fn_exit_context

# TODO: these don't "this" to the current context!
bootstrap = [
  "read-line [';', 'trigger', function(a) { this.context.mode = 'interpret'; this.context.current_word = null; return true; }]"
  "native-eval word create"

  "read-line ['forget', 'normal', function(a) { this.context.words[a] = null; }]"
  "native-eval word create"

  "read-line ['mask', 'normal', function(a) { this.context.words[a] = fn_word([a, 'compiled', null]); }]"
  "native-eval word create"

  "read-line ['bye', 'normal', function(a) { process.exit(0); }]"
  "native-eval word create"

  "read-line ['dbg', 'normal', function(a) { console.log('[' + typeof(a) + '] ' + a); return a; }]"
  "native-eval word create"

  "read-line ['drop', 'normal', function(a) { return null; }]"
  "native-eval word create"

  "read-line ['mode', 'normal', function(a) { return this.context.mode; }]"
  "native-eval word create"

  "read-line ['set-mode', 'normal', function(a) { this.context.mode = a; }]"
  "native-eval word create"
  
  "read-line ['list-mode', 'normal', function(a) { ctx = a[0]; word = a[1]; if (ctx.arg == null) ctx.arg = []; ctx.arg.push(word); return ctx.arg; }]" 
  "native-eval word create"

  "read-line ['(', 'trigger', function(a) { this.context.mode = 'list-mode'; return true; }]"
  "native-eval word create"

  "read-line [')', 'trigger', function(a) { this.context.mode = 'interpret'; return true; }]"
  "native-eval word create"

  "read-word user new-context drop"
]
 
completer = (l) ->
  completions = (word for own word, _ of context.words when word.type != WordTypes.trigger)
  hits = completions.filter (c) -> c.indexOf(l) == 0

  [(if hits.length > 0 then hits else completions), l]

rl = readline.createInterface {input: process.stdin, output: process.stdout, completer: completer }

context.words['interpret'].fn(line) for line in bootstrap

rl.setPrompt "#{context.toString()}> "
rl.prompt()
rl.on('line', (l) ->
  fn_lookup_word('interpret').fn(l)
  rl.prompt()
).on 'close', ->
  console.log "Bye"
  process.exit 0

