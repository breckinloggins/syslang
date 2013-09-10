CPUFaults = 
  none:            0
  abort:           1
  not_implemented: 2
  stack_underflow: 3
  stack_overflow:  4
  type_mismatch:   5
  invalid_opcode:  6
  sec_fault_r:     7  # reading memory that shouldn't be read from
  sec_fault_w:     8  # writing memory that shouldn't be written to
  sec_fault_x:     9  # executing code at memory not marked executable

CPUFaultNames = []
CPUFaultNames.push(k) for own k, _ of CPUFaults

# TODO: allow a run_wait state so we can control the speed of the CPU
CPUStates = 
  reset:                0
  running:              1
  execute_instruction:  2
  fault:                3
  halted:               4

CPUStateNames = []
CPUStateNames.push(k) for own k, _ of CPUStates

# The value of each type is the number of bytes it occupies
ValTypes = 
  byte:             { tag: 0x00, length: 1, default: 0 }
  short:            { tag: 0x02, length: 2, default: 0 }
  int:              { tag: 0x04, length: 4, default: 0 }
  long:             { tag: 0x08, length: 8, default: 0 }
  char:             { tag: 0x10, length: 2, default: 0 } # UTF-16
  # TODO: flaots and doubles?
  boolean:          { tag: 0x20, length: 1, default: 0 }
  returnAddress:    { tag: 0x40, length: 4, default: 0 }
  arrayRef:         { tag: 0x80, length: 4, default: 0 } 
  
  typeForTag: (tag) -> (v for own _, v of @ when v.tag == tag)[0]

class ArrayRef
  # Read an arrayref at location p
  @read: (mv, p) ->
    tag = mv.getUint8(p)
    length = mv.getUint32(p+4)

  constructor: (@valType, @length) ->

   

# http://docs.oracle.com/javase/specs/jvms/se7/html/index.html
class CPU
  @_memMap:
    arr0:           { start: 0x0,     length: 8,      read: yes, write: no,  execute: no } # arrayref for entire memory
    stack:          { start: 0x8,     length: 1016,   read: yes, write: yes, execute: no }
    pad1:           { start: 0x400,   length: 64,     read: no,  write: no,  execute: no }
    code:           { start: 0x440,   length: 65536,  read: yes, write: yes, execute: yes }
    heap:           { start: 0x10440, length: 32768,  read: yes, write: yes, execute: no }
    pad2:           { start: 0x18440, length: 64,     read: no,  write: no,  execute: no }
    cpu_flags:      { start: 0x18480, length: 2,      read: yes, write: no,  execute: no }
    kbd_state:      { start: 0x18482, length: 12,     read: yes, write: yes, execute: no }
    next:           { start: 0x1848E, length: 1,      read: no,  write: no,  execute: no }

  @adrOf: (name) -> @_memMap[name].start

  # http://en.wikipedia.org/wiki/Java_bytecode_instruction_listings
  @_opTable:
    nop:            {op: 0x00, ob: 0, fn: -> }
    iconst_m1:      {op: 0x02, ob: 0, fn: -> @push ValTypes.int, -1 }
    iconst_0:       {op: 0x03, ob: 0, fn: -> @push ValTypes.int, 0 }
    iconst_1:       {op: 0x04, ob: 0, fn: -> @push ValTypes.int, 1 }
    iconst_2:       {op: 0x05, ob: 0, fn: -> @push ValTypes.int, 2 }
    iconst_3:       {op: 0x06, ob: 0, fn: -> @push ValTypes.int, 3 }
    iconst_4:       {op: 0x07, ob: 0, fn: -> @push ValTypes.int, 4 }
    iconst_5:       {op: 0x08, ob: 0, fn: -> @push ValTypes.int, 5 }
    bipush:         {op: 0x10, ob: 1, fn: -> @push ValTypes.byte, args[0] }
    baload:         {op: 0x33, ob: 0, fn: -> @fault = CPUFaults.not_implemented } 
    bastore:        {op: 0x54, ob: 0, fn: -> @fault = CPUFaults.not_implemented }
    pop:            {op: 0x57, ob: 0, fn: -> @pop() }
    dup:            {op: 0x59, ob: 0, fn: -> val = @peek(); @push(val[1], val[0]) }
    swap:           {op: 0x5f, ob: 0, fn: -> v1 = @pop(); v2 = @pop(); @push(v1[1], v1[0]); @push(v2[1], v2[0]) }
    iadd:           {op: 0x60, ob: 0, fn: -> @binop ValTypes.int, (a, b) -> a + b }
    isub:           {op: 0x64, ob: 0, fn: -> @binop ValTypes.int, (a, b) -> b - a }
    imul:           {op: 0x68, ob: 0, fn: -> @binop ValTypes.int, (a, b) -> a * b }
    idiv:           {op: 0x6c, ob: 0, fn: -> @binop ValTypes.int, (a, b) -> a / b }
    ineg:           {op: 0x74, ob: 0, fn: -> @unop ValTypes.int, (a) -> -a }
    goto:           {op: 0xa7, ob: 2, fn: -> @pc += -3 + @mv.getInt16(@pc-2); }
    athrow:         {op: 0xb4, ob: 0, fn: -> @fault = CPUFaults.not_implemented }
    newarray:       {op: 0xbc, ob: 1, fn: -> tag = @mv.getUint8(@pc - 1); len = @pop()[0]; console.log "newarray type #{ValTypes.typeForTag(tag)} length #{len}"}
    arraylength:    {op: 0xbe, ob: 0, fn: -> @fault = CPUFaults.not_implemented }
    invalid:        {op: 0xfe, ob: 0, fn: -> @fault = CPUFaults.invalid_opcode }
    halt:           {op: 0xff, ob: 0, fn: -> @state = CPUStates.halted } # Not a real JVM opcode

  @compile: (opName, args...) ->
    op = @_opTable[opName]
    throw "invalid opcode #{opName}" unless op
    op.op

  constructor: (@memBuffer) ->
    @mem = new Uint8Array(@memBuffer)
    @mv = new DataView(@memBuffer)

    # Transform the by-name op table into one index by opcode for speed
    @ops = new Array(256)
    @ops[v.op] = $.extend(v, {opc: opc}) for opc, v of CPU._opTable
    (@ops[i] = @ops[CPU._opTable.invalid.op] if @ops[i] == undefined) for _, i in @ops 

    @cyclesPerOp = 1  # Higher values slow down the processor

    # Set up quick protection ranges based on mem map
    @readRanges = []
    @readRanges.push([m.start...m.start+m.length]) for own _, m of CPU._memMap when m.read
    
    @writeRanges = []
    @writeRanges.push([m.start...m.start+m.length]) for own _, m of CPU._memMap when m.write

    @execRanges = []
    @execRanges.push([m.start...m.start+m.length]) for own _, m of CPU._memMap when m.execute

    @reset()

  reset: () ->
    @stackSize = CPU._memMap.stack.length
    @pc = CPU._memMap.code.start 
    @curOp = null
    @sp = CPU._memMap.stack.start + @stackSize
    @cycle = 0
    @fault = CPUFaults.none
    @state = CPUStates.execute_instruction

  # Write a value in memory and return the length written
  writeVal: (offset, type = ValTypes.byte, value = type.default) ->
    # Check for write fault
    prevFault = @fault
    for r in @writeRanges
      if offset in r and (offset + type.length) in r
        @fault = prevFault
        break
      @fault = CPUFaults.sec_fault_w

    return 0 if @fault == CPUFaults.sec_fault_w

    # We'll start by just storing a full byte as the tag, but we
    # might want to do more efficient byte packing in the future
    @mv.setUint8 offset++, type.tag
    switch type
      when ValTypes.byte                then @mv.setUint8 offset, value
      when ValTypes.short               then @mv.setInt16 offset, value
      when ValTypes.int                 then @mv.setInt32 offset, value
      when ValTypes.long                then @mv.setFloat64 offset, value
      when ValTypes.char                then @mv.setUint16 offset, value
      when ValTypes.boolean             then @mv.setUint8 offset, value
      when ValTypes.returnAddress       then @mv.setUint32 offset, value
      when ValTypes.arrayRef            
        @mv.setUint32 offset, value[0]   # Tag and length
        @mv.setUint32 offset+4, value[1] # Pointer
      else throw "unrecognized cpu value type in writeVal"

    type.length + 1

  # Read the value in memory at the given offset, interpreted as a tagged value
  #
  # returns: [value, type, length_read_in_bytes]
  readVal: (offset) ->
    type_tag = @mv.getUint8 offset
    type = ValTypes.typeForTag type_tag
    
    # Check for protection violation
    prev_fault = @fault
    for r in @readRanges
      if offset in r and (offset + type.length) in r
        @fault = prev_fault
        break
      @fault = CPUFaults.sec_fault_r
    
    return [0, ValTypes.byte, 0] if @fault == CPUFaults.sec_fault_r

    ++offset
    value = switch type
      when ValTypes.byte                then @mv.getUint8 offset
      when ValTypes.short               then @mv.getInt16 offset
      when ValTypes.int                 then @mv.getInt32 offset
      when ValTypes.long                then @mv.getFloat64 offset
      when ValTypes.char                then @mv.getUint16 offset
      when ValTypes.boolean             then @mv.getUint8 offset
      when ValTypes.returnAddress       then @mv.getUint32 offset
      when ValTypes.arrayRef
        [@mv.getUint32(offset), @mv.getUint32(offset+4)]
      else throw "unrecognized cpu value type #{type} tag #{type_tag} in readVal"

    [value, type, type.length + 1]

  peek: () ->
    if @sp > CPU._memMap.stack.start + @stackSize
      @fault = CPUFaults.stack_underflow
      [ValTypes.byte, 0, 0]

    @readVal @sp

  pop: () ->
    if @sp >= CPU._memMap.stack.start + @stackSize
      @fault = CPUFaults.stack_underflow
      return [ValTypes.byte, 0, 0]

    val = @readVal @sp
    @sp += val[2]
    val

  push: (type, value) ->
    @sp -= type.length + 1
    if @sp < CPU._memMap.stack.start
      @fault = CPUFaults.stack_overflow 
      0
    else
      @writeVal @sp, type, value
  
  unop: (type, fn) ->
    v = @pop()
    if v[1] == type
      @push type, fn v[0]
    else
      @fault = CPUFaults.type_mismatch
      0
      
  binop: (type, fn) ->
    v1 = @pop()
    v2 = @pop()
    if v1[1] == type && v2[1] == type
      @push type, fn(v1[0], v2[0])
    else
      @fault = CPUFaults.type_mismatch
      0

  update: () ->
    if @state == CPUStates.execute_instruction
      ++@cycle
      @state = CPUStates.running if @cycle % @cyclesPerOp == 0

    return unless @state == CPUStates.running

    # Check for sec_fault
    prev_fault = @fault
    for r in @execRanges
      if @pc in r
        @fault = prev_fault
        break
      @fault = CPUFaults.sec_fault_x
   
    return if @fault == CPUFaults.sec_fault_x

    # Fetch and decode
    opcode = @mem[@pc]
    @curOp = @ops[opcode]

    # Pre-update @pc in case an instruction modifies it
    @pc += 1 + @curOp.ob

    # Execute
    @state = CPUStates.execute_instruction
    @curOp.fn.call @
    
    # Validate
    @state = CPUStates.fault unless @fault == CPUFaults.none
    
    

  draw: (p5, x, y, width, height) ->
    p5.rect x, y, width, height
    p5.stroke(0)
    p5.fill(0)
    p5.text "pc: " + @pc, x + 5, y + 15
    if @curOp?
      p5.text "op: #{@curOp.opc}", x + 5, y + 30
    else
      p5.text "op: --", x + 5, y + 30

    p5.text "state: #{CPUStateNames[@state]}", x + 5, y + 45 
    p5.text "fault: #{CPUFaultNames[@fault]}", x + 5, y + 60 
    if @sp < CPU._memMap.stack.start + @stackSize
      p5.text "tos: " + @peek()[0], x + 5, y + 75 
    else
      p5.text "tos: --", x + 5, y + 75 

window.CPU = CPU
