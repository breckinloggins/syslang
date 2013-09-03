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
  
  smooth();
}

void keyPressed()  {
  m.term.onKeyPressed(key, keyCode); 
}

void draw()  {
  m.update();
  
  currTime = millis() - startTime;
  if (currTime >= hitTime)  {
    startTime = millis();
    //ds.push((int)random(0, 100));
  }
   
  m.draw();
}
