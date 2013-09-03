class Interpreter implements TerminalListener  {
  Machine machine;
  
  Interpreter(Machine machine)  {
    this.machine = machine;
    InitializeBuiltins(machine.dictionary);
  }
  
  void onLine(Terminal sender, String line)  {
    for (String word : line.split(" "))  {
      parseWord(word.trim(), sender); 
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
