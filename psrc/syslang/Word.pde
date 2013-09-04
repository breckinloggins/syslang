public void InitializeBuiltins(ArrayList<Word> dictionary)  {
  for (String name : new String[]{"words", "execute", ".", "+", "-", "*", ":", ";", "drop", "dup", ">r", "r>", "begin", "until", "true", "false"})  {
    Word w = new Word(name, Word.WT_PRIMITIVE);
    dictionary.add(w);
    w.index = dictionary.size() - 1;
    
    if (w.name.equals(";"))  {
      w.immediate = true; 
    }
  }
}
  
public class Word {
  public static final int WT_PRIMITIVE = 0;
  public static final int WT_COMPILED = 1;
  
  public String name;
  public int index;
  public int type;
  public boolean immediate;
  public ArrayList<Integer> params;
  
  Word(String name, int type)  {
    this.name = name;
    this.type = type;
    this.immediate = false;
    this.index = -1;
    if (type == WT_COMPILED)  {
      this.params = new ArrayList<Integer>(); 
    }
  }
  
  public void compile(Machine m)  {
    // TODO: numbers need code to push themselves
    try {
      if (m.currentWord == null)  {
        throw new SyslangException("no current word"); 
      } else if (m.currentWord.type != WT_COMPILED)  {
        throw new SyslangException("current word " + m.currentWord.name + " is not a compiled word"); 
      } else if (index < 0)  {
        throw new SyslangException("invalid index"); 
      }
      
      m.currentWord.params.add(index);      
    } catch (SyslangException e)  {
      m.term.println("error compiling " + name + ": " + e.getMessage());
    }  
  }
  
  public void execute(Machine m)  {
    try  {
      m.currentWord = this;
      if (type == WT_COMPILED)  {
        m.ip = 0;
        while (m.ip < params.size())  {
          int idx = params.get(m.ip);
          if (idx < 0 || idx >= m.dictionary.size())  {
            throw new SyslangException("invalid word address " + idx); 
          }
          
          Word w = m.dictionary.get(idx);
          m.rs.push(m.ip);
          w.execute(m);
          m.ip = m.rs.pop() + 1;  
        }
      } else if (name.equals("words"))  {
        for (int i = 0; i < m.dictionary.size(); i++)  {
          m.term.println("[" + i + "] " + m.dictionary.get(i).name); 
        }
      } else if (name.equals("execute"))  {
        int idx = m.ds.pop();
        if (idx < 0 || idx >= m.dictionary.size())  {
          throw new SyslangException("invalid word address"); 
        }
        
        Word w = m.dictionary.get(idx);
        w.execute(m);
      } else if (name.equals("."))  {
        m.term.println("" + m.ds.pop());
      } else if (name.equals("+")) {
        int a1 = m.ds.pop();
        int a2 = m.ds.pop();
        m.ds.push(a1 + a2);
      } else if (name.equals("-"))  {
        int a1 = m.ds.pop();
        int a2 = m.ds.pop();
        m.ds.push(a2 - a1);
      } else if (name.equals("*")) {
        int a1 = m.ds.pop();
        int a2 = m.ds.pop();
        m.ds.push(a1 * a2);
      } else if (name.equals(":"))  {
        m.interp.mode = Interpreter.IM_COMPILE;
      } else if (name.equals(";"))  {
        m.interp.mode = Interpreter.IM_INTERPRET;
      } else if (name.equals("drop"))  {
        m.ds.pop();
      } else if (name.equals("dup"))  {
        int a = m.ds.pop();
        m.ds.push(a);
        m.ds.push(a);
      } else if (name.equals(">r"))  {
        m.rs.push(m.ds.pop());
      } else if (name.equals("r>"))  {
        m.ds.push(m.rs.pop());
      } else if (name.equals("begin"))  {
        int our_ip = m.rs.pop();
        m.rs.push(our_ip - 1);  // interpreter will +1 this
        m.rs.push(our_ip);
      } else if (name.equals("until"))  {      
        int our_ip = m.rs.pop();
        int flag = m.ds.pop();
        if (flag == 0)  {
          m.rs.pop();  // get rid of begin's ip
          m.rs.push(our_ip);     
        } else {
          // Nothing needs to be done, we've exposed begin's ip and it will be 
          // pop'd and executed when the interpreter continues
        }
      } else if (name.equals("true"))  {
        m.ds.push(1);
      } else if (name.equals("false"))  {
        m.ds.push(0);
      } else {
        m.term.println("error: " + name + " does not have defined execution semantics");
      }
    } catch (SyslangException ex)  {
      m.term.println("error executing " + name + ": " + ex.getMessage()); 
    } 
  }
}
