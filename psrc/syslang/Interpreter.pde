class Interpreter implements TerminalListener  {
  Machine machine;
  ArrayList<Word> dictionary;
  
  Interpreter(Machine machine)  {
    this.machine = machine;
    dictionary = new ArrayList<Word>();
    InitializeBuiltins(dictionary);
  }
  
  void onLine(Terminal sender, String line)  {
    for (String word : line.split(" "))  {
      parseWord(word.trim(), sender); 
    }
  }
  
  void parseWord(String name, Terminal term)  {
    Word word = null;
    for (Word w : dictionary)  {
      if (w.name.equals(name))  {
        word = w;
        break; 
      }
    }
    
    if (word != null)  {
      word.execute(machine);
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
}
