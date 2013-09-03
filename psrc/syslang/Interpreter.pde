class Interpreter implements TerminalListener  {
  Stack ds, rs;
  
  Interpreter(Stack dataStack, Stack returnStack)  {
    ds = dataStack;
    rs = returnStack; 
  }
  
  void onLine(Terminal sender, String line)  {
    for (String word : line.split(" "))  {
      parseWord(word.trim(), sender); 
    }
  }
  
  void parseWord(String word, Terminal term)  {
     try  {
      if (word.equals("."))  {
        term.println("" + ds.pop());
      } else if (word.equals("+")) {
        int a1 = ds.pop();
        int a2 = ds.pop();
        ds.push(a1 + a2);
      } else if (word.equals("*")) {
        int a1 = ds.pop();
        int a2 = ds.pop();
        ds.push(a1 * a2);
      } else {
        try {
          ds.push(Integer.parseInt(word));
        } catch (NumberFormatException e)  {
          term.println("error: " + word + " is undefined");
        }
      }
    } catch (SyslangException ex)  {
      term.println("error: " + ex.getMessage()); 
    }
  }
  
  void doQuit(Terminal sender)  {
    rs.clear();
    
  }
}
