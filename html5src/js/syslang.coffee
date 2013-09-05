
machine = new Machine(0x20000)

syslang_draw = (p5) ->
  p5.setup = () ->
    p5.size($(window).width(), $(window).height() - 50)
    p5.frameRate(60)
    p5.background(64)

  p5.keyPressed = () ->

  p5.draw = () ->
    machine.update()
    machine.draw p5
  

$(document).ready ->
  canvas = document.getElementById "processing"

  processing = new Processing(canvas, syslang_draw)

  $('#input_line').submit -> machine.interpret($('#input_text').val()); false
