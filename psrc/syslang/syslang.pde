class Stack  {
  public final int STATE_IDLE = 0;
  public final int STATE_PUSHING = 1;
  public final int STATE_POPPING = 2;
  
  public int dispWidth = 100;
  public int dispMaxHeight = 300;
  public int dispElementHeight = 20;
  
  String name;
  int size = 1024;
  int[] elements;
  int tos;
  int state;
  
  // The current top of stack can be animated
  int tosY = 0;
  
  Stack(String name)  {
    this.name = name;
    elements = new int[size];
    tos = size - 1;
    state = STATE_IDLE; 
  }
  
  void push(int elem)  {
    if (tos < 0)  {
      println("stack overflow");
      return;
    }
    
    if (tos != size - 1) state = STATE_PUSHING;
    elements[tos--] = elem;
  }
  
  int pop()  {
    if (tos >= size)  {
      tos = size;
      println("stack underflow");
    }
    
    state = STATE_POPPING;
    return elements[++tos];
  }
  
  void update()  {
    if (state == STATE_PUSHING)  {
      tosY += 4;
    } else if (state == STATE_POPPING)  {
      tosY -= 4;
    }
    
    if (abs(tosY) == dispElementHeight)  {
        // Done
        tosY = 0;
        state = STATE_IDLE; 
    }
  }
  
  void display(int x, int y)  {
    fill(0);
    noFill();
    stroke(0);
    textSize(12);
    text(name + "(" + (size - tos - 1) + ")", x, y);
    y += 3;
    
    int w, h;
    w = dispWidth;
    h = min(dispElementHeight * size, dispMaxHeight);
    rect(x, y, w, h);
    
    for (int i = y; i <= y+h; i++)  { 
      if ((i - y) % dispElementHeight == 0)  {
        if (i - y > 0)  {
          // Divider
          stroke(128);
          line(x+1, i, x+w-1, i);
        }
         
        // Content for cell
        float xText = x + 3;
        float yText = i + dispElementHeight / 1.3;
        if (tosY != 0)  {
          yText = yText - dispElementHeight + tosY; 
        }
        
        int idx = ((i - y)/dispElementHeight) % size;
        idx = tos + idx + 1;
         
        if (yText < y+h && idx < size)  {
          if (state == STATE_IDLE || idx != tos + 1)  {
            text(""+elements[idx], xText, yText);
          }
        }
      }
      
      if (dispMaxHeight < dispElementHeight * size)  {
        float inter = map(i, y, y+h, 0, 1);
        color c = lerpColor(color(255,255,255,0), color(255,255,255,255), inter);
      
        stroke(c);
        line(x-1, i, x+w+1, i); 
      }
    }
  }
}

interface TerminalListener  {
  void onLine(Terminal sender, String line); 
}

class Terminal  {
  public String prompt = "> ";
  public StringList lines;
  public String curLine;
  public int dispLineHeight = 15;
  
  public int curX = 0;
  public int curY = 0;
  public color curFillColor;
  
  TerminalListener listener;
  float startTime, currTime, cursorHitTime;
  
  Terminal(TerminalListener listener)  {
    lines = new StringList();
    curLine = "";
    startTime = millis();
    cursorHitTime = 750;
    curFillColor = color(128);
    
    this.listener = listener;
  }
  
  void print(String str)  {
    if (lines.size() == 0)  {
      lines.append(str);
    } else {
      int idx = lines.size() - 1;
      lines.set(idx, lines.get(idx) + str); 
    }
  }
  
  void println(String str)  {
    print(str);
    lines.append(""); 
  }
  
  void onKeyPressed(char key, int keyCode)  {
    if (key == CODED)  {
      return; 
    }
    
    if (key == '\n')  {
      if (listener != null) listener.onLine(this, curLine);
      
      curLine = "";
    } else {
      curLine += key;  
    }
  }
  
  void update()  {
    currTime = millis() - startTime;
    if (currTime >= cursorHitTime)  {
      startTime = millis();
      if (curFillColor == color(128))  {
        curFillColor = color(0); 
      } else {
        curFillColor = color(128); 
      }
    }
  }
  
  void display(int x, int y)  {
    fill(0);
    noFill();
    textSize(12);
   
    // How many lines can we possibly display?
    int dispLines = lines.size()*dispLineHeight / dispLineHeight;
    if (dispLines > lines.size()) dispLines = lines.size();
    
    int lineY = y + dispLineHeight;
    for (int i = lines.size() - dispLines; i < lines.size(); i++)  {
      text(lines.get(i), x + 3, lineY);
      lineY += dispLineHeight;
    }
    
    text(prompt, x + 3, lineY);
    text(curLine, x + 10, lineY);
    
    curX = x + 3 + ((curLine.length() + 1) * 7) ;
    curY = lineY - 10;
    stroke(curFillColor);
    fill(curFillColor);
    rect(curX, curY, 5, 10); 
  }
}

class Interpreter implements TerminalListener  {
  Stack ds, rs;
  
  Interpreter(Stack dataStack, Stack returnStack)  {
    ds = dataStack;
    rs = returnStack; 
  }
  
  void onLine(Terminal sender, String line)  {
    if (line.equals("."))  {
      sender.println("" + ds.pop());
    } else if (line.equals("+")) {
      int a1 = ds.pop();
      int a2 = ds.pop();
      ds.push(a1 + a2);
    } else if (line.equals("*")) {
      int a1 = ds.pop();
      int a2 = ds.pop();
      ds.push(a1 * a2);
    } else {
      try {
        ds.push(Integer.parseInt(line));
      } catch (NumberFormatException e)  {
        sender.println("error");
      }
    }
    
  }
}

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
