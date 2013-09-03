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
    } else if (key == BACKSPACE)  {
      if (curLine.length() > 0) curLine = curLine.substring(0, curLine.length()-1); 
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
