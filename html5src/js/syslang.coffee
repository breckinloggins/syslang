
syslang_draw = (p5) ->

  machine = new Machine(32768)

  p5.setup = () ->
    p5.size($(window).width(), $(window).height())
    p5.frameRate(60)
    p5.background(64)

  p5.keyPressed = () ->

  p5.draw = () ->
    machine.update()
    machine.draw p5
  
$(document).ready ->
  canvas = document.getElementById "processing"

  processing = new Processing(canvas, syslang_draw)
