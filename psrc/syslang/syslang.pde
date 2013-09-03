Stack ds, rs;
Terminal term;
Interpreter interp;

float startTime, currTime;
float hitTime;

void setup()  {
  size(640, 768);
  frameRate(60);
  
  textFont(createFont("Andale Mono", 12));
  
  startTime = millis();
  hitTime = 1000;
  
  ds = new Stack("DS");
  rs = new Stack("RS");
  interp = new Interpreter(ds, rs);
  term = new Terminal(interp);
  
  smooth();
}

void keyPressed()  {
  term.onKeyPressed(key, keyCode); 
}

void draw()  {
  background(255);
  
  currTime = millis() - startTime;
  if (currTime >= hitTime)  {
    startTime = millis();
    //ds.push((int)random(0, 100));
  }
  
  int stackX = width - rs.dispWidth - 3;
  int stackY = 20; 
  rs.update();
  rs.display(stackX, stackY);
  
  stackX -= ds.dispWidth + 6;
  ds.update();
  ds.display(stackX, stackY);
  
  int termY = height - 300;
  stroke(0);
  line(0, termY, width, termY);
  term.update();
  term.display(0, termY);
}
