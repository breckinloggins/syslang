# A proper but minimal Forth based on
# http://openbookproject.net/py4fun/forth/forth.html
readline = require('readline') # http://nodejs.org/api/readline.html#readline_readline

ds    = []       # The data stack
words = []       # The input stream of tokens


rAdd    = (cod,p) -> b = ds.pop(); a = ds.pop(); ds.push(a+b); null
rMul    = (cod,p) -> b = ds.pop(); a = ds.pop(); ds.push(a*b); null
rSub    = (cod,p) -> b = ds.pop(); a = ds.pop(); ds.push(a-b); null
rDiv    = (cod,p) -> b = ds.pop(); a = ds.pop(); ds.push(a/b); null
rEq     = (cod,p) -> b = ds.pop(); a = ds.pop(); ds.push(if a==b then 1 else 0); null 
rGt     = (cod,p) -> b = ds.pop(); a = ds.pop(); ds.push(if a>b then 1 else 0); null
rLt     = (cod,p) -> b = ds.pop(); a = ds.pop(); ds.push(if a<b then 1 else 0); null
rSwap   = (cod,p) -> a = ds.pop(); b = ds.pop(); ds.push(a); ds.push(b); null
rDup    = (cod,p) -> ds.push(ds[ds.length-1]); null
rDrop   = (cod,p) -> ds.pop(); null
rOver   = (cod,p) -> ds.push(ds[ds.length-2]); null
rDump   = (cod,p) -> console.log "ds = #{ds}"; null
rDot    = (cod,p) -> console.log ds.pop(); null
rPush   = (cod,p) -> ds.push(cod[p]); p + 1
rRun    = (cod,p) -> throw "Unimplemented"; null

rDict =
  '+': rAdd
  '*': rMul
  '-': rSub
  '/': rDiv
  '=': rEq
  '>': rGt
  '<': rLt
  'swap': rSwap
  'dup':  rDup
  'drop': rDrop
  'over': rOver
  'dump': rDump
  '.':    rDot

cDict =

tokenizeWords = (s) -> s.replace(/\s+#.*/,'').split(' ')

completer = (l) ->
  completions = (word for own word, _ of rDict)
  hits = completions.filter (c) -> c.indexOf(l) == 0

  [(if hits.length > 0 then hits else completions), l]

compile = (words) ->
  pcode = []
  for word in words
    cAct = cDict[word]
    rAct = rDict[word]

    if cAct? then cAct(pcode)
    else if rAct?
      if rAct instanceof Array
        throw "Compiled words not supported"
      else
        pcode.push rAct
    else
      # Assume it's a number to be pushed on stack when run
      pcode.push(rPush)
      n = parseInt(word)
      if isNaN(n)
        f = parseFloat(word)
        if isNaN(f)
          # Assume we'll define the word later
          pcode[pcode.length - 1] = rRun
          pcode.push(word)
        else
          pcode.push(f) # it's a float
      else
        pcode.push(n) # it's an integer

  return pcode

execute = (code) ->
  p = 0
  while p < code.length
    f = code[p++]
    newP = f(code, p)
    if newP? then p = newP

rl = readline.createInterface {input: process.stdin, output: process.stdout, completer: completer }

rl.setPrompt "Forth> "
rl.prompt()
rl.on('line', (l) ->
  # if compile(tokenizeWords(l))
  #    rl.setPrompt "Forth> "
  # else
  #   rl.setPrompt "...    "
  execute(compile(tokenizeWords(l)))

  rl.prompt()
).on 'close', ->
  console.log "Bye"
  process.exit 0
