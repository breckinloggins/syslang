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
    CPU.memMap.init @memSize

    @mem = new ArrayBuffer(@memSize)
    @codeStart = CPU.memMap.adrOf 'code'

    # TEMP: fake code
    memArr = new Uint8Array(@mem)
    @assemble {}, memArr, new DataView(@mem), @codeStart, "halt"
    # i = -3 
    # memArr[4] = (i >> 8) & 0xff
    # memArr[5] = i & 0xff

    @cpu = new CPU(@mem)

  assemble: (labels, mem, memV, offset, line) ->
    [cmd, argParts] = $.trim(line).split(/\s(.+)/)
    cmd = $.trim(cmd)
    argParts = $.trim(argParts) 
    
    parseArg = (arg) ->
      arg = $.trim(arg)
      numArg = parseInt(arg)
      if isNaN(numArg)
        throw "undefined label #{arg}" unless labels[arg]?
        os = labels[arg]
        {type: 2, val: os - offset}
      else
        {type: 1, val: numArg}

    if argParts != ''
      args = [].concat.apply([], (parseArg part for part in $.trim(argParts).split(',')))
    else 
      args = []
    
    if cmd.indexOf(":", cmd.length - ":".length) != -1
      label = cmd.substring(0, cmd.length - 1)
      throw "duplicate label #{label}" if labels[label]?
      labels[label] = offset
    else
      op = CPU.opTable[cmd]
      throw "invalid opcode #{cmd}" unless op
      mem[offset++] = op.op
      argLength = 0
      for arg in args
        if arg.type == 1 
          mem[offset++] = arg.val 
          ++argLength
        else if arg.type == 2
          memV.setInt16(offset, arg.val)
          offset += 2
          argLength += 2
        else
          throw "Unrecognized arg type"

      throw "assembled args of #{argLength} bytes when #{op.ob} bytes expected" if argLength != op.ob

    offset 
    

  interpret: (text) ->
    labels = {}
    lines = text.split("\n")
    memArr = new Uint8Array(@mem)
    memV = new DataView(@mem)
    offset = @codeStart
    for line, i in lines
      continue if $.trim(line) == ''
      offset = @assemble labels, memArr, memV, offset, line
    
    @cpu.reset()

  update: () ->
    @cpu.update()
  
  draw: (p5) ->
    Machine._drawLabelled p5, "F", "bar", 10, 20, 75, 15  
    @cpu.draw p5, 10, 50, 200, 300

window.Machine = Machine
