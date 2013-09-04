public class Machine  {
  public static final int STATE_IDLE = 0;
  public static final int STATE_RUNNING = 1;
  
  public Stack ds;
  public Stack rs;
  public ArrayList<Word> dictionary;
  public Word currentWord;
  public int ip;
  public Terminal term;
  public Interpreter interp; 
  public int state;
  
  Machine()  {
    ds = new Stack("DS");
    rs = new Stack("RS");
    ip = -1;
    dictionary = new ArrayList<Word>();
    currentWord = null;
    interp = new Interpreter(this);
    term = new Terminal(interp);
    
    state = STATE_IDLE;
  }
  
  public boolean isIdle()  {
    return this.state == Machine.STATE_IDLE && ds.state == Stack.STATE_IDLE && rs.state == Stack.STATE_IDLE; 
  }
  
  public void update()  {
    ds.update();
    rs.update();
    interp.update();
    term.update(); 
  }
  
  void drawLabelled(String label, String value, int x, int y, int width, int height)  {
    stroke(0);
    fill(0);
    noFill();
    text(label, x, y);
    x += 40;
    rect(x, y - height/1.3, width, height);
    text(value, x + 10, y); 
  }
  
  public void draw()  {
    background(255);
    
    drawLabelled("ip", ip == -1 ? "--" : "" + ip, 10, 20, 75, 15);
    drawLabelled("cw", currentWord != null ? currentWord.name : "--", 10, 50, 150, 15);
    
    int stackX = width - m.rs.dispWidth - 3;
    int stackY = 20; 
    m.rs.display(stackX, stackY);
    
    stackX -= m.ds.dispWidth + 6;
    m.ds.display(stackX, stackY);
    
    int termY = height - 300;
    stroke(0);
    line(0, termY, width, termY);
    m.term.display(0, termY);  
  }
}
