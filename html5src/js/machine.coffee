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

    # TEMP: fake code
    memArr = new Uint8Array(@mem)
    memArr[0] = 0x04  # iconst_1
    memArr[1] = 0x05  # iconst_2
    memArr[2] = 0x60  # iadd
    memArr[3] = 0xa7  # goto
    i = -3 
    memArr[4] = (i >> 8) & 0xff
    memArr[5] = i & 0xff
      

    @cpu = new CPU(@mem)


  update: () ->
    @cpu.update()
  
  draw: (p5) ->
    Machine._drawLabelled p5, "F", "bar", 10, 20, 75, 15  
    @cpu.draw p5, 10, 50, 200, 300

window.Machine = Machine
