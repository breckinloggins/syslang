class Interpreter implements TerminalListener  {
  Stack ds, rs;
  
  Interpreter(Stack dataStack, Stack returnStack)  {
    ds = dataStack;
    rs = returnStack; 
  }
  
  void onLine(Terminal sender, String line)  {
    try  {
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
      } else if (line.equals("quit"))  {
        doQuit(sender);
      } else {
        try {
          ds.push(Integer.parseInt(line));
        } catch (NumberFormatException e)  {
          sender.println("error");
        }
      }
    } catch (SyslangException ex)  {
      sender.println("error: " + ex.getMessage()); 
    }
  }
  
  void doQuit(Terminal sender)  {
     
  }
}
