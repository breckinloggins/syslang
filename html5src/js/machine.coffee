class Machine
  @_drawLabelled: (p5, label, value, x, y, width, height) ->
    p5.stroke 255 
    p5.fill 255 
    p5.noFill
    p5.text label, x, y
    x += 40
    p5.rect x, y - height/1.3, width, height
    p5.stroke(128)
    p5.text value, x + 10, y
    
  constructor: (@memSize) ->
    @mem = new ArrayBuffer(@memSize)
    @codeStart = CPU.memMap.adrOf 'code'

    # TEMP: fake code
    memArr = new Uint8Array(@mem)
    @assemble memArr, @codeStart, "halt"
    # i = -3 
    # memArr[4] = (i >> 8) & 0xff
    # memArr[5] = i & 0xff

    @cpu = new CPU(@mem)

  assemble: (mem, offset, line) ->
    [mnemonic, argParts] = $.trim(line).split(/\s(.+)/)
    mnemonic = $.trim(mnemonic)
    argParts = $.trim(argParts) 

    if (argParts != '')
      args = (parseInt($.trim(part)) for part in $.trim(argParts).split(','))
    else 
      args = []
    
    op = CPU.opTable[mnemonic]
    throw "invalid opcode #{mnemonic}" unless op
    throw "incorrect number of arguments (#{args.length} for #{op.ob} expected) for opcode #{mnemonic}" unless args.length == op.ob
    mem[offset++] = op.op
    (mem[offset++] = arg) for arg in args 

    offset 
    

  interpret: (text) ->
    lines = text.split("\n")
    memArr = new Uint8Array(@mem)
    offset = @codeStart
    for line, i in lines
      continue if $.trim(line) == ''
      offset = @assemble memArr, offset, line
    
    @cpu.reset()

  update: () ->
    @cpu.update()
  
  draw: (p5) ->
    Machine._drawLabelled p5, "F", "bar", 10, 20, 75, 15  
    @cpu.draw p5, 10, 50, 200, 300

window.Machine = Machine
