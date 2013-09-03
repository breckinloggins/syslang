Machine m;

float startTime, currTime;
float hitTime;

void setup()  {
  size(640, 768);
  frameRate(60);
  
  textFont(createFont("Andale Mono", 12));
  
  startTime = millis();
  hitTime = 1000;
  
  m = new Machine();
  m.ds = new Stack("DS");
  m.rs = new Stack("RS");
  m.interp = new Interpreter(m);
  m.term = new Terminal(m.interp);
  
  smooth();
}

void keyPressed()  {
  m.term.onKeyPressed(key, keyCode); 
}

void draw()  {
  background(255);
  
  currTime = millis() - startTime;
  if (currTime >= hitTime)  {
    startTime = millis();
    //ds.push((int)random(0, 100));
  }
  
  int stackX = width - m.rs.dispWidth - 3;
  int stackY = 20; 
  m.rs.update();
  m.rs.display(stackX, stackY);
  
  stackX -= m.ds.dispWidth + 6;
  m.ds.update();
  m.ds.display(stackX, stackY);
  
  int termY = height - 300;
  stroke(0);
  line(0, termY, width, termY);
  m.term.update();
  m.term.display(0, termY);
}
