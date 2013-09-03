import java.util.LinkedList;

class Interpreter implements TerminalListener  {
  public static final int IM_INTERPRET = 0;
  public static final int IM_COMPILE = 1;
  
  Machine machine;
  public int mode;
  public LinkedList<String> names;
  
  Interpreter(Machine machine)  {
    this.machine = machine;
    this.mode = IM_INTERPRET;
    this.names = new LinkedList<String>();
    InitializeBuiltins(machine.dictionary);
  }
  
  void onLine(Terminal sender, String line)  {
    for (String word : line.split(" "))  {
      names.add(word.trim());
    }
  }
  
  void parseWord(String name, Terminal term)  {
    Word word = null;
    for (int i = machine.dictionary.size() - 1; i >= 0; i--)  {
      Word w = machine.dictionary.get(i);
      if (w.name.equals(name))  {
        word = w;
        break; 
      }
    }
    
    if (word == null && mode == IM_COMPILE)  {
      // By default we'll forward declare a new word and set it as the
      // current word
      word = new Word(name, Word.WT_COMPILED);
      machine.dictionary.add(word);
      word.index = machine.dictionary.size() - 1;
      m.currentWord = word; 
    } else if (word != null)  {
      if (mode == IM_INTERPRET || word.immediate)  {
        word.execute(machine);
      } else {
        word.compile(machine); 
      }
    } else { 
      try {
        try {
          machine.ds.push(Integer.parseInt(name));
        } catch (SyslangException e)  {
          term.println("error: " + e.getMessage()); 
        }
      } catch (NumberFormatException e)  {
        term.println("error: " + name + " is undefined");
      }
    }
  }
  
  public void update()  {
    while (!names.isEmpty())  {
      // Wait until the machine is idle before doing anything else
      if (!machine.isIdle()) return;
      String name = names.remove();
      parseWord(name, m.term);
    } 
  }
}
