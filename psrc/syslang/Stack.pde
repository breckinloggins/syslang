public class Stack  {
  public static final int STATE_IDLE = 0;
  public static final int STATE_PUSHING = 1;
  public static final int STATE_POPPING = 2;
  
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
    clear();
  }
  
  void push(int elem) throws SyslangException {
    if (tos < 0)  {
      throw new SyslangException(name + " stack overflow");
    }
    
    if (tos != size - 1) state = STATE_PUSHING;
    elements[tos--] = elem;
  }
  
  int pop() throws SyslangException {
    if (tos >= size - 1)  {
      clear();
      throw new SyslangException(name + " stack underflow");
    }
    
    state = STATE_POPPING;
    return elements[++tos];
  }
  
  void clear()  {
    tos = size - 1;
    state = STATE_IDLE; 
  }
  
  void update()  {
    if (state == STATE_PUSHING)  {
      tosY += 4;
    } else if (state == STATE_POPPING)  {
      tosY -= 4;
    }
    
    if (Math.abs(tosY) == dispElementHeight)  {
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
