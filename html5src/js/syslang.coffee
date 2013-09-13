
machine = new Machine(0x22000)

syslang_draw = (p5) ->
  p5.setup = () ->
    p5.size($(window).width(), $(window).height() - 150) # TODO: this needs to be the dimensions of the div!
    p5.frameRate(60)
    p5.background(64)

  p5.keyPressed = () ->
    machine.keyDown p5.key.code

  p5.draw = () ->
    machine.update()
    machine.draw p5

$(document).ready ->
  canvas = document.getElementById "processing"

  processing = new Processing(canvas, syslang_draw)

  $('#input_line').submit -> machine.interpret($('#input_text').val()); false
