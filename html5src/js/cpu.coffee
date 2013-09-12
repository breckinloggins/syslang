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

# Reads and writes an 8 byte structure describing an array after that structure
ArrayRef =
  size: 8
  read: (mv, p) -> {type: ValTypes.typeForTag(mv.getUint8(p)), length: mv.getUint32(p+4)}
  write: (mv, p, type, length) ->
    mv.setUint8(p, type.tag)
    mv.setUint32(p+4, length)
    {type: type, length: length}
  getValueAddress: (mv, type, arrayref, i) ->
    ref = ArrayRef.read(mv, arrayref)
    throw "Type mismatch" if type != ref.type

    size = ref.type.length

    offset = i * size
    throw "Array index outside the bounds of array" if i < 0 or offset > ref.length * size 

    arrayref + ArrayRef.size + offset

# http://docs.oracle.com/javase/specs/jvms/se7/html/index.html
class CPU
  # TODO: Load memmap into memory
  # Mem map start addresses are dynamically computed when the CPU is
  # constructed based on the order given by the "ord" key
  @memMap:
    arr0:           { ord: 0,   start: 0x0,     length: 8,      read: yes, write: no,  execute: no } # arrayref for entire memory
    stack:          { ord: 1,   start: 0x0,     length: 1024,   read: yes, write: yes, execute: no }
    pad1:           { ord: 2,   start: 0x0,     length: 64,     read: no,  write: no,  execute: no }
    code:           { ord: 3,   start: 0x0,     length: 65536,  read: yes, write: yes, execute: yes }
    pad2:           { ord: 4,   start: 0x0,     length: 64,     read: no,  write: no,  execute: no }
    cpu_flags:      { ord: 5,   start: 0x0,     length: 2,      read: yes, write: no,  execute: no }
    kbd_state:      { ord: 6,   start: 0x0,     length: 12,     read: yes, write: yes, execute: no }
    top:            { ord: 7,   start: 0x0,     length: 1,      read: no,  write: no,  execute: no }
    heap:           { ord: 8,   start: 0x0,     length: 32768,  read: yes, write: yes, execute: no }
    
    init:  (memsize) ->
      memOffset = 0x0
      memEntries = (mem for own _, mem of CPU.memMap)
      memEntries = memEntries.sort (a, b) -> a.ord > b.ord
      (mem.start = memOffset; memOffset += mem.length) for mem in memEntries 

      throw "Not enough memory to satisfy mem map (#{memOffset} > #{memsize}" if memOffset > memsize 

    adrOf: (name) -> @[name].start

  # http://en.wikipedia.org/wiki/Java_bytecode_instruction_listings
  # TODO: Load opTable into memory
  @opTable:
    nop:            {op: 0x00, ob: 0, fn: -> }
    iconst_m1:      {op: 0x02, ob: 0, fn: -> @push ValTypes.int, -1 }
    iconst_0:       {op: 0x03, ob: 0, fn: -> @push ValTypes.int, 0 }
    iconst_1:       {op: 0x04, ob: 0, fn: -> @push ValTypes.int, 1 }
    iconst_2:       {op: 0x05, ob: 0, fn: -> @push ValTypes.int, 2 }
    iconst_3:       {op: 0x06, ob: 0, fn: -> @push ValTypes.int, 3 }
    iconst_4:       {op: 0x07, ob: 0, fn: -> @push ValTypes.int, 4 }
    iconst_5:       {op: 0x08, ob: 0, fn: -> @push ValTypes.int, 5 }
    bipush:         {op: 0x10, ob: 1, fn: -> b = @mv.getUint8(@pc - 1); @push ValTypes.byte, b }
    baload:         {op: 0x33, ob: 0, fn: -> idx = @pop()[0]; ref = @pop()[0]; @arrayLoad(ValTypes.byte, ref, idx) }
    bastore:        {op: 0x54, ob: 0, fn: -> val = @pop(); idx = @pop()[0]; ref = @pop()[0]; @arrayStore(ValTypes.byte, ref, idx, val) }
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
    newarray:       {op: 0xbc, ob: 1, fn: -> tag = @mv.getUint8(@pc - 1); len = @pop()[0]; console.log "#{tag}/#{ValTypes.typeForTag(tag).tag} length #{len}"; @fault = CPUFaults.not_implemented }
    arraylength:    {op: 0xbe, ob: 0, fn: -> ref = @pop()[0]; @push(ValTypes.int, ArrayRef.read(@mv, ref).length) }
    invalid:        {op: 0xfe, ob: 0, fn: -> @fault = CPUFaults.invalid_opcode }
    halt:           {op: 0xff, ob: 0, fn: -> @state = CPUStates.halted } # Not a real JVM opcode

  constructor: (@memBuffer) ->
    @mem = new Uint8Array(@memBuffer)
    @mv = new DataView(@memBuffer)
    
    # Write our initial array ref so we can treat the whole memory as arrayref
    # 0
    ArrayRef.write @mv, 0, ValTypes.byte, @mem.length - ArrayRef.size

    # Transform the by-name op table into one index by opcode for speed
    @ops = new Array(256)
    @ops[v.op] = $.extend(v, {opc: opc}) for opc, v of CPU.opTable
    (@ops[i] = @ops[CPU.opTable.invalid.op] if @ops[i] == undefined) for _, i in @ops 

    @cyclesPerOp = 1  # Higher values slow down the processor

    # Set up quick protection ranges based on mem map
    @readRanges = []
    @readRanges.push([m.start...m.start+m.length]) for own _, m of CPU.memMap when m.read
    
    @writeRanges = []
    @writeRanges.push([m.start...m.start+m.length]) for own _, m of CPU.memMap when m.write

    @execRanges = []
    @execRanges.push([m.start...m.start+m.length]) for own _, m of CPU.memMap when m.execute

    @reset()

  reset: () ->
    # TODO: Make ALL cpu state (including registers) part of memory so programs
    # can get to them
    @stackSize = CPU.memMap.stack.length
    @pc = CPU.memMap.code.start 
    @curOp = null
    @sp = CPU.memMap.stack.start + @stackSize
    @cycle = 0
    @fault = CPUFaults.none
    @state = CPUStates.execute_instruction

  # Write a value in memory and return the length written
  # If raw is true, the tag byte is NOT written
  writeVal: (offset, type = ValTypes.byte, value = type.default, raw = false) ->
    # Check for write fault
    prevFault = @fault
    for r in @writeRanges
      if offset in r and (offset + type.length + (raw ? -1 : 0)) in r
        @fault = prevFault
        break
      @fault = CPUFaults.sec_fault_w

    return 0 if @fault == CPUFaults.sec_fault_w

    # We'll start by just storing a full byte as the tag, but we
    # might want to do more efficient byte packing in the future
    @mv.setUint8 offset++, type.tag unless raw
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

    type.length + (raw ? 0 : 1)

  # Read the value in memory at the given offset, interpreted as a tagged value
  #
  # returns: [value, type, length_read_in_bytes]
  readVal: (offset, type = null) ->
    val_offset = offset
    if not type?
      type_tag = @mv.getUint8 offset
      type = ValTypes.typeForTag type_tag
      ++val_offset
    else
      type_tag = type.tag
    
    # Check for protection violation
    prev_fault = @fault
    for r in @readRanges
      if offset in r and (offset + type.length) in r
        @fault = prev_fault
        break
      @fault = CPUFaults.sec_fault_r
    
    return [0, ValTypes.byte, 0] if @fault == CPUFaults.sec_fault_r

    value = switch type
      when ValTypes.byte                then @mv.getUint8 val_offset
      when ValTypes.short               then @mv.getInt16 val_offset
      when ValTypes.int                 then @mv.getInt32 val_offset
      when ValTypes.long                then @mv.getFloat64 val_offset
      when ValTypes.char                then @mv.getUint16 val_offset
      when ValTypes.boolean             then @mv.getUint8 val_offset
      when ValTypes.returnAddress       then @mv.getUint32 val_offset
      when ValTypes.arrayRef
        [@mv.getUint32(val_offset), @mv.getUint32(val_offset+4)]
      else throw "unrecognized cpu value type #{type} tag #{type_tag} in readVal"

    [value, type, type.length + (val_offset - offset)]

  peek: () ->
    if @sp >= CPU.memMap.stack.start + @stackSize
      @fault = CPUFaults.stack_underflow
      [ValTypes.byte, 0, 0]

    @readVal @sp

  pop: () ->
    if @sp >= CPU.memMap.stack.start + @stackSize
      @fault = CPUFaults.stack_underflow
      return [ValTypes.byte, 0, 0]

    val = @readVal @sp
    @sp += val[2]
    val

  push: (type, value) ->
    @sp -= type.length + 1
    if @sp < CPU.memMap.stack.start
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

  arrayLoad: (type, arrayref, index) ->
    adr = ArrayRef.getValueAddress(@mv, type, arrayref, index)
    val = @readVal(adr, type)
    @push(val[1], val[0]) 

  arrayStore: (type, arrayref, index, val) ->
    throw "Type mismatch" if val[1] != type
    adr = ArrayRef.getValueAddress(@mv, type, arrayref, index)
    @writeVal(adr, type, val[0], true)

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
    if @sp < CPU.memMap.stack.start + @stackSize
      p5.text "tos: " + @peek()[0], x + 5, y + 75 
    else
      p5.text "tos: --", x + 5, y + 75 

window.CPU = CPU
