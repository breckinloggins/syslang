class Interpreter implements TerminalListener  {
  Stack ds, rs;
  HashMap<String, Word> dictionary;
  
  Interpreter(Stack dataStack, Stack returnStack)  {
    ds = dataStack;
    rs = returnStack; 
    dictionary = new HashMap<String, Word>();
    InitializeBuiltins(dictionary);
  }
  
  void onLine(Terminal sender, String line)  {
    for (String word : line.split(" "))  {
      parseWord(word.trim(), sender); 
    }
  }
  
  void parseWord(String word, Terminal term)  {
    Word w = dictionary.get(word);
    if (w != null)  {
      w.execute(term, ds, rs);
    } else { 
      try {
        try {
          ds.push(Integer.parseInt(word));
        } catch (SyslangException e)  {
          term.println("error: " + e.getMessage()); 
        }
      } catch (NumberFormatException e)  {
        term.println("error: " + word + " is undefined");
      }
    }
  }
  
  void doQuit(Terminal sender)  {
    rs.clear();
    
  }
}
