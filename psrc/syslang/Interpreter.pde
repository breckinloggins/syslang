class Interpreter implements TerminalListener  {
  Machine machine;
  
  Interpreter(Machine machine)  {
    this.machine = machine;
    InitializeBuiltins(machine.dictionary);
    
    // TEMP TEST: try a compiled word
    Word w = new Word("+*", Word.WT_COMPILED);
    w.params.add(3);
    w.params.add(4);
    machine.dictionary.add(w);
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
