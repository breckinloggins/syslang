CPUFaults = 
  none : 0
  abort : 1
  not_implemented : 2

CPUStates = 
  reset : 0
  running : 1
  fault : 2

# http://docs.oracle.com/javase/specs/jvms/se7/html/index.html
class CPU
  # http://en.wikipedia.org/wiki/Java_bytecode_instruction_listings
  @_opTable:
    nop:            {op: 0x00, ob: 0, fn: -> }
    iconst_m1:      {op: 0x02, ob: 0, fn: -> @mem[--@sp] = -1 }
    iconst_0:       {op: 0x03, ob: 0, fn: -> @mem[--@sp] = 0 }
    iconst_1:       {op: 0x04, ob: 0, fn: -> @mem[--@sp] = 1 }
    iconst_2:       {op: 0x05, ob: 0, fn: -> @mem[--@sp] = 2 }
    iconst_3:       {op: 0x06, ob: 0, fn: -> @mem[--@sp] = 3 }
    iconst_4:       {op: 0x07, ob: 0, fn: -> @mem[--@sp] = 4 }
    iconst_5:       {op: 0x08, ob: 0, fn: -> @mem[--@sp] = 5 }
    bipush:         {op: 0x10, ob: 1, fn: -> @mem[--@sp] = args[0] }
    pop:            {op: 0x57, ob: 0, fn: -> ++@sp }
    dup:            {op: 0x59, ob: 0, fn: -> @mem[--@sp] = @mem[@sp + 1] }
    swap:           {op: 0x5f, ob: 0, fn: -> tmp = @mem[@sp]; @mem[@sp] = @mem[@sp + 1]; @mem[@sp + 1] = tmp }
    iadd:           {op: 0x60, ob: 0, fn: -> @mem[++@sp] = @mem[@sp] + @mem[@sp-1] }
    isub:           {op: 0x64, ob: 0, fn: -> @mem[++@sp] = @mem[@sp] - @mem[@sp-1] }
    imul:           {op: 0x68, ob: 0, fn: -> @mem[++@sp] = @mem[@sp] * @mem[@sp-1] }
    idiv:           {op: 0x6c, ob: 0, fn: -> @mem[++@sp] = @mem[@sp] / @mem[@sp-1] }
    ineg:           {op: 0x74, ob: 0, fn: -> @mem[@sp] = -@mem[@sp] }
    goto:           {op: 0xa7, ob: 2, fn: -> @pc += -3 + @memView.getInt16(@pc-2); }
    athrow:         {op: 0xb4, ob: 0, fn: -> @fault = CPUFaults.not_implemented }

  @compile: (opName, args...) ->
    op = @_opTable[opName]
    op.op

  constructor: (@memBuffer, @stackSize = 1024) ->
    @mem = new Uint8Array(@memBuffer)
    @memView = new DataView(@memBuffer)
    @state = CPUStates.reset
    @ops = new Array(256)
    @ops[v.op] = $.extend(v, {opc: opc}) for opc, v of CPU._opTable
    (@ops[i] = @ops[CPU._opTable.athrow.op] if @ops[i] == null) for _, i in @ops
    @pc = 0
    @sp = @stackSize
    @fault = CPUFaults.none 

    @state = CPUStates.running
      
  update: () ->
    return unless @state == CPUStates.running

    # Fetch and decode
    opcode = @mem[@pc]
    op = @ops[opcode]

    # Pre-update @pc in case an instruction modifies it
    @pc += 1 + op.ob

    # Execute
    op.fn.call @
    
    # Validate
    @state = CPUStates.fault unless @fault == CPUFaults.none
    
    

  draw: (p5, x, y, width, height) ->
    p5.rect x, y, width, height
    p5.stroke(0)
    p5.fill(0)
    p5.text "" + @pc, x + 5, y + 15
    p5.text "" + @state, x + 5, y + 30 
    if @sp < @stackSize
      p5.text "" + @mem[@sp], x + 5, y + 45

window.CPU = CPU
